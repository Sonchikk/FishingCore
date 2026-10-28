import Foundation
import SwiftUI
import CoreGraphics
import ImageIO
import Metal
import MetalKit
import simd
import FishingCore

// MARK: - 0. Original APK Drawable & Texture Loader (`OriginalGameAssetsLoader`)

/// Loads the 339 original PNG sprites (`background.png`, `second_background.png`, `pond_1_big..15_big.png`,
/// `pond_1..15.png`, `fishing_rod_0..15.png`, `bobber.png`, `bobber_hide.png`, `push_me.png`, `push_me_on.png`,
/// `fish_1..141.png`, `bait_1..40.png`, `md_achiv_1..14.png`, etc.) extracted from `fishing181.apk` (`resources.arsc`)
/// inside `App/Resources/GameData/Drawables/`.
public enum OriginalGameAssetsLoader: Sendable {
    private final class ImageCache: @unchecked Sendable {
        static let shared = ImageCache()
        private let lock = NSLock()
        private var storage: [String: CGImage] = [:]

        func get(_ key: String) -> CGImage? {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }

        func set(_ image: CGImage, for key: String) {
            lock.lock()
            defer { lock.unlock() }
            storage[key] = image
        }
    }

    /// Resolves the file URL of `<name>.png` inside `GameData/Drawables/` across app bundles and test layouts.
    public static func resolveDrawableURL(
        named name: String,
        gameDataDirectoryURL: URL? = nil,
        bundle: Bundle = .main
    ) -> URL? {
        let cleanName = name.hasSuffix(".png") ? String(name.dropLast(4)) : name
        var candidates: [URL] = []

        if let explicitDir = gameDataDirectoryURL {
            candidates.append(explicitDir.appendingPathComponent("Drawables/\(cleanName).png"))
            candidates.append(explicitDir.appendingPathComponent("\(cleanName).png"))
        }
        if let bundleGameData = bundle.url(forResource: "GameData", withExtension: nil) {
            candidates.append(bundleGameData.appendingPathComponent("Drawables/\(cleanName).png"))
        }
        if let resourceRoot = bundle.resourceURL {
            candidates.append(resourceRoot.appendingPathComponent("GameData/Drawables/\(cleanName).png"))
            candidates.append(resourceRoot.appendingPathComponent("Drawables/\(cleanName).png"))
        }
        if let directBundleURL = bundle.url(forResource: cleanName, withExtension: "png") {
            candidates.append(directBundleURL)
        }
        if let envDir = ProcessInfo.processInfo.environment["FISHING_GAMEDATA_DIR"], !envDir.isEmpty {
            let envURL = URL(fileURLWithPath: envDir, isDirectory: true)
            candidates.append(envURL.appendingPathComponent("Drawables/\(cleanName).png"))
        }

        // Package root fallback during local development / tests
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(sourceRoot.appendingPathComponent("App/Resources/GameData/Drawables/\(cleanName).png"))

        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// Loads and caches a `CGImage` for an original APK drawable name (e.g. `"pond_1_big"`, `"fishing_rod_0"`, `"fish_1"`).
    public static func loadCGImage(
        named name: String,
        gameDataDirectoryURL: URL? = nil,
        bundle: Bundle = .main
    ) -> CGImage? {
        let cleanName = name.hasSuffix(".png") ? String(name.dropLast(4)) : name
        if gameDataDirectoryURL == nil, let cached = ImageCache.shared.get(cleanName) {
            return cached
        }
        guard let url = resolveDrawableURL(named: cleanName, gameDataDirectoryURL: gameDataDirectoryURL, bundle: bundle),
              let dataProvider = CGDataProvider(url: url as CFURL),
              let cgImage = CGImage(
                  pngDataProviderSource: dataProvider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }
        if gameDataDirectoryURL == nil {
            ImageCache.shared.set(cgImage, for: cleanName)
        }
        return cgImage
    }

    /// Returns a SwiftUI `Image` for an original APK drawable name, or `nil` if not bundled.
    public static func image(
        named name: String,
        gameDataDirectoryURL: URL? = nil,
        bundle: Bundle = .main
    ) -> Image? {
        guard let cgImage = loadCGImage(named: name, gameDataDirectoryURL: gameDataDirectoryURL, bundle: bundle) else {
            return nil
        }
        return Image(decorative: cgImage, scale: 1.0, orientation: .up)
    }

    /// Rasterizes a `CGImage` into a tightly packed 4-byte `RGBA8` buffer (`width * height * 4` bytes, top-to-bottom rows).
    public static func decodeRGBA8(from cgImage: CGImage) -> (width: Int, height: Int, rgba: [UInt8])? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        let success = rgba.withUnsafeMutableBytes { rawPtr -> Bool in
            guard let baseAddress = rawPtr.baseAddress,
                  let ctx = CGContext(
                      data: baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width * 4,
                      space: colorSpace,
                      bitmapInfo: bitmapInfo
                  ) else {
                return false
            }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard success else { return nil }
        return (width, height, rgba)
    }

    /// Reconstructs `F0.n.s(d0, e0)` (full pond texture `B`) and `F0.n.r(d0, e0)` (top 25% sky/shore slice `f0`)
    /// from the original `pond_<id>_big.png` resource (`RENDERER.md` Section 2.2).
    public static func decodePondAndTopQuarterSkyRGBA(
        pondIndex0Based: Int,
        gameDataDirectoryURL: URL? = nil,
        bundle: Bundle = .main
    ) -> (width: Int, height: Int, fullRGBA: [UInt8], skyHeight: Int, skyRGBA: [UInt8])? {
        let clampedNumber = max(1, min(15, pondIndex0Based + 1))
        let bigName = "pond_\(clampedNumber)_big"
        let fallbackSmallName = "pond_\(clampedNumber)"
        guard let cgImage = loadCGImage(named: bigName, gameDataDirectoryURL: gameDataDirectoryURL, bundle: bundle)
                ?? loadCGImage(named: fallbackSmallName, gameDataDirectoryURL: gameDataDirectoryURL, bundle: bundle),
              let decoded = decodeRGBA8(from: cgImage) else {
            return nil
        }
        let skyHeight = max(1, decoded.height / 4)
        let skyByteCount = skyHeight * decoded.width * 4
        let skyRGBA = Array(decoded.rgba.prefix(skyByteCount))
        return (decoded.width, decoded.height, decoded.rgba, skyHeight, skyRGBA)
    }
}

// MARK: - 1. Water Shader Activation Policy (`GameActivity.b0()` & `GameView.u()`)

/// Reconstructs the exact activation rule from `GameActivity.b0()` (`RENDERER.md` Section 1.1):
/// The animated water shader is active if and only if BOTH:
/// 1. `pond_fons_pref["pond_fon_set_" + pondIndex] > 0` (`pondBackgroundSetIndex > 0`);
/// 2. `FFF-ANDROID["WATER_SHADER"] == true` (`waterShaderSettingEnabled == true`).
public enum WaterShaderActivationPolicy: Sendable {
    public static func shouldActivate(
        pondBackgroundSetIndex: Int,
        waterShaderSettingEnabled: Bool
    ) -> Bool {
        pondBackgroundSetIndex > 0 && waterShaderSettingEnabled
    }
}

// MARK: - 2. TGA Texture Parser (`F0.s` — `TgaTextureLoader`, `RENDERER.md` Section 3)

public enum TgaLoaderError: Error, Sendable, Equatable {
    case dataTooShort(actualBytes: Int)
    case invalidDimensions(width: Int, height: Int, bitsPerPixel: Int)
    case truncatedPixelPayload(expectedBytes: Int, actualBytes: Int)
}

public struct TgaDecodedImage: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let bitsPerPixel: Int
    /// Decoded 3-byte `RGB` pixel buffer matching `F0.s.c` in `classes.dex`.
    public let rgbBytes: [UInt8]
    /// Decoded 4-byte `RGBA8` pixel buffer for `MTLPixelFormat.rgba8Unorm`.
    public let rgbaBytes: [UInt8]
}

/// Byte-accurate reconstruction of `F0.s.<init>(InputStream)` (`RENDERER.md` Section 3.1).
/// Parses 24-bit uncompressed BGR True-Color `.tga` textures (`wNoise3.tga`, `wNoise4.tga`, `256 x 128`)
/// and swaps each `(B, G, R)` triplet into `(R, G, B)`.
public enum TgaTextureLoader: Sendable {
    public static let headerSizeBytes: Int = 18

    public static func decode(data: Data) throws -> TgaDecodedImage {
        let bytes = [UInt8](data)
        guard bytes.count >= headerSizeBytes else {
            throw TgaLoaderError.dataTooShort(actualBytes: bytes.count)
        }

        // Skip first 12 bytes (`0..11`), read Little-Endian width (`12..13`), height (`14..15`), bpp (`16`), skip descriptor (`17`)
        let width = Int(bytes[12]) | (Int(bytes[13]) << 8)
        let height = Int(bytes[14]) | (Int(bytes[15]) << 8)
        let bpp = Int(bytes[16])

        guard width > 0, height > 0, bpp == 24 else {
            throw TgaLoaderError.invalidDimensions(width: width, height: height, bitsPerPixel: bpp)
        }

        let pixelCount = width * height
        let expectedPayloadBytes = pixelCount * 3
        guard bytes.count >= headerSizeBytes + expectedPayloadBytes else {
            throw TgaLoaderError.truncatedPixelPayload(
                expectedBytes: headerSizeBytes + expectedPayloadBytes,
                actualBytes: bytes.count
            )
        }

        var rgb = [UInt8]()
        rgb.reserveCapacity(expectedPayloadBytes)
        var rgba = [UInt8]()
        rgba.reserveCapacity(pixelCount * 4)

        var offset = headerSizeBytes
        for _ in 0..<pixelCount {
            let b = bytes[offset]
            let g = bytes[offset + 1]
            let r = bytes[offset + 2]
            offset += 3

            rgb.append(r)
            rgb.append(g)
            rgb.append(b)

            rgba.append(r)
            rgba.append(g)
            rgba.append(b)
            rgba.append(255)
        }

        return TgaDecodedImage(
            width: width,
            height: height,
            bitsPerPixel: bpp,
            rgbBytes: rgb,
            rgbaBytes: rgba
        )
    }

    /// Loads `Textures/<filename>` (e.g. `wNoise3.tga`, `wNoise4.tga`) from the bundled `GameData` directory if present.
    public static func loadBundledNoiseTGA(
        named filename: String,
        gameDataDirectoryURL: URL? = nil,
        bundle: Bundle = .main
    ) -> Data? {
        var candidates: [URL] = []
        if let dir = gameDataDirectoryURL {
            candidates.append(dir.appendingPathComponent("Textures/\(filename)"))
            candidates.append(dir.appendingPathComponent(filename))
        }
        if let bundleGameData = bundle.url(forResource: "GameData", withExtension: nil) {
            candidates.append(bundleGameData.appendingPathComponent("Textures/\(filename)"))
        }
        if let resourceRoot = bundle.resourceURL {
            candidates.append(resourceRoot.appendingPathComponent("GameData/Textures/\(filename)"))
            candidates.append(resourceRoot.appendingPathComponent("Textures/\(filename)"))
        }
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(sourceRoot.appendingPathComponent("App/Resources/GameData/Textures/\(filename)"))

        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               data.count >= headerSizeBytes {
                return data
            }
        }
        return nil
    }

    /// Synthesizes a valid 24-bit uncompressed BGR `.tga` file (`256 x 128`) for normal-map testing
    /// or fallback when the APK's `assets/Textures/wNoise3.tga` / `wNoise4.tga` are not yet bundled.
    public static func makeProceduralWaveNoiseTGA(
        width: Int = 256,
        height: Int = 128,
        seedPhase: Int = 0
    ) -> Data {
        var bytes = [UInt8](repeating: 0, count: headerSizeBytes + width * height * 3)
        bytes[2] = 2 // Uncompressed True-Color TGA
        bytes[12] = UInt8(width & 0xFF)
        bytes[13] = UInt8((width >> 8) & 0xFF)
        bytes[14] = UInt8(height & 0xFF)
        bytes[15] = UInt8((height >> 8) & 0xFF)
        bytes[16] = 24 // 24 bits per pixel (BGR888)
        bytes[17] = 0  // Origin: bottom-left

        var idx = headerSizeBytes
        for y in 0..<height {
            for x in 0..<width {
                let nx = Double(x + seedPhase) / Double(width) * (2.0 * Double.pi * 4.0)
                let ny = Double(y - seedPhase) / Double(height) * (2.0 * Double.pi * 4.0)
                let rVal = UInt8(clamping: Int((sin(nx) * 0.5 + 0.5) * 255.0))
                let gVal = UInt8(clamping: Int((cos(ny) * 0.5 + 0.5) * 255.0))
                let bVal: UInt8 = 200
                // Stored in BGR order inside TGA
                bytes[idx] = bVal
                bytes[idx + 1] = gVal
                bytes[idx + 2] = rVal
                idx += 3
            }
        }
        return Data(bytes)
    }
}

// MARK: - 3. Exact Water Shader Mathematics (`PSBackGround.glsl`, `PSBlit0.glsl`, `PSBlit0_night.glsl`)

/// Pure-Swift mathematical mirror of `F0.n` and the 5 GLSL shaders (`RENDERER.md` Sections 2 & 4).
public enum WaterShaderMath: Sendable {
    public static let offscreenWidth: Int = 256
    public static let offscreenHeight: Int = 512
    public static let phaseStepPerFrame: Float = 0.0005

    /// `F0.n.o()` (`pc=0000..001c`): increments wave phase `V` by `+0.0005f` and wraps when `> 1.0f`.
    public static func stepPhaseOffset(_ currentOffset: Float) -> Float {
        var next = currentOffset + phaseStepPerFrame
        if next > 1.0 {
            next -= 1.0
        }
        return next
    }

    /// `PSBackGround.glsl`: computes refracted `(u, v)` texture coordinates clamped to `[0.01, 0.99]`.
    public static func computeRefractedUV(
        texCoords: SIMD2<Float>,
        ndcPosition: SIMD3<Float>,
        noise1Sample: SIMD4<Float>,
        noise2Sample: SIMD4<Float>
    ) -> SIMD2<Float> {
        let n1 = (noise1Sample - SIMD4<Float>(repeating: 0.5)) * 2.0
        let n2 = (noise2Sample - SIMD4<Float>(repeating: 0.5)) * 2.0
        let sum = n1 + n2
        let len4 = sqrt(simd_dot(sum, sum))
        let vNoise = len4 > 1e-6 ? (sum / len4) : SIMD4<Float>(0, 0, 1, 0)

        let camDistVec = ndcPosition - SIMD3<Float>(0.0, -1.5, 0.5)
        let fLength = max(1e-4, simd_length(camDistVec))
        var vUV = texCoords - SIMD2<Float>(vNoise.x, vNoise.y) / (50.0 * fLength)

        vUV.x = min(0.99, max(0.01, vUV.x))
        vUV.y = min(0.99, max(0.01, vUV.y))
        return vUV
    }

    /// `PSBackGround.glsl`: computes golden sun specular reflection (`pow(fCos, 192.0)`, `vLightPos = (0, 0, 0)`).
    public static func applyWaterSpecularAndAlpha(
        diffuseColor: SIMD4<Float>,
        ndcPosition: SIMD3<Float>,
        normalizedNoise4D: SIMD4<Float>,
        lightPos: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 0.0)
    ) -> SIMD4<Float> {
        let lightVec = ndcPosition - lightPos
        let vLight = simd_length(lightVec) > 1e-6 ? simd_normalize(lightVec) : SIMD3<Float>(0, 1, 0)
        let camVec = SIMD3<Float>(0.0, -0.8, -0.35) - ndcPosition
        let vCamera = simd_length(camVec) > 1e-6 ? simd_normalize(camVec) : SIMD3<Float>(0, -1, 0)

        let noiseXYZ = SIMD3<Float>(normalizedNoise4D.x, normalizedNoise4D.y, normalizedNoise4D.z)
        let reflRaw = vLight - (2.0 * simd_dot(vLight, noiseXYZ) * noiseXYZ)
        let vReflected = simd_length(reflRaw) > 1e-6 ? simd_normalize(reflRaw) : noiseXYZ

        let fCos = max(0.0, simd_dot(vReflected, vCamera))
        let specFactor = pow(fCos, 192.0)
        let gold = SIMD4<Float>(1.0, 0.8, 0.0, 1.0)
        var mixed = diffuseColor * (1.0 - specFactor) + gold * specFactor
        mixed.w = 0.8
        return mixed
    }

    /// `PSBlit0.glsl` (day) and `PSBlit0_night.glsl` (night: `R *= 0.25, G *= 0.25, B *= 0.40, A = 0.9`).
    public static func applyScreenBlitTint(color: SIMD4<Float>, isDaylight: Bool) -> SIMD4<Float> {
        if isDaylight {
            return SIMD4<Float>(color.x, color.y, color.z, 0.9)
        } else {
            return SIMD4<Float>(color.x * 0.25, color.y * 0.25, color.z * 0.40, 0.9)
        }
    }
}

// MARK: - 4. Embedded Metal Shading Language (MSL) Translation of All 5 GLSL Shaders

public enum WaterMetalShaderSource: Sendable {
    /// Direct MSL port of `VSBackGround.glsl`, `PSBackGround.glsl`, `VSBlit0.glsl`, `PSBlit0.glsl`, and `PSBlit0_night.glsl`.
    public static let mslSource: String = """
    #include <metal_stdlib>
    using namespace metal;

    struct WaterVertexIn {
        float2 position [[attribute(0)]];
        float2 texCoords [[attribute(1)]];
    };

    struct WaterBackgroundVaryings {
        float4 position [[position]];
        float2 vTexCoords;
        float3 vPosition;
    };

    struct BlitVaryings {
        float4 position [[position]];
        float2 vTexCoords;
    };

    struct WaterUniforms {
        float vOffset;
        float3 vLightPos; // Uninitialized in F0.n -> always float3(0.0, 0.0, 0.0)
    };

    // 1. VSBackGround.glsl (Pass 1 Vertex Shader)
    vertex WaterBackgroundVaryings vertexBackGround(
        uint vertexID [[vertex_id]],
        constant float4 *vertices [[buffer(0)]]
    ) {
        WaterBackgroundVaryings out;
        float4 packed = vertices[vertexID];
        out.position = float4(packed.xy, 0.0, 1.0);
        out.vTexCoords = packed.zw;
        out.vPosition = float3(packed.xy, 0.0);
        return out;
    }

    // 2. PSBackGround.glsl (Pass 1 Fragment Shader -> 256x512 offscreen FBO)
    fragment float4 fragmentBackGround(
        WaterBackgroundVaryings in [[stage_in]],
        texture2d<float> vDiffuseTexture [[texture(0)]],
        texture2d<float> vNoise1Texture [[texture(1)]],
        texture2d<float> vNoise2Texture [[texture(2)]],
        sampler diffuseSampler [[sampler(0)]],
        sampler noiseSampler [[sampler(1)]],
        constant WaterUniforms &uniforms [[buffer(0)]]
    ) {
        float2 vTexCoords1 = in.vTexCoords;
        vTexCoords1.x = vTexCoords1.x - uniforms.vOffset;
        float4 vNoise1 = vNoise1Texture.sample(noiseSampler, vTexCoords1 * 3.0);

        vTexCoords1 = in.vTexCoords;
        vTexCoords1.x = vTexCoords1.x + uniforms.vOffset;
        float4 vNoise2 = vNoise2Texture.sample(noiseSampler, vTexCoords1 * 3.0);

        // Fine capillary secondary octave for realistic water micro-ripples
        float2 fineUV1 = float2(in.vTexCoords.x + uniforms.vOffset * 1.6, in.vTexCoords.y - uniforms.vOffset * 0.8) * 7.2;
        float4 vNoiseFine = vNoise1Texture.sample(noiseSampler, fineUV1);

        float4 vNoise = ((vNoise1 - 0.5) * 2.0) + ((vNoise2 - 0.5) * 2.0) + ((vNoiseFine - 0.5) * 0.75);
        vNoise = normalize(vNoise);

        float fLength = length(in.vPosition - float3(0.0, -1.5, 0.5));
        // Perspective-scaled refraction: gentler near the far shore (y ~ 0.25), richer in the foreground (y -> 1.0)
        float depthFactor = clamp((in.vTexCoords.y - 0.22) / 0.78, 0.0, 1.0);
        float refractScale = mix(75.0, 42.0, depthFactor);
        float2 vUV = in.vTexCoords - (vNoise.xy / (refractScale * fLength));
        vUV = clamp(vUV, float2(0.01, 0.01), float2(0.99, 0.99));

        float4 vColor = vDiffuseTexture.sample(diffuseSampler, vUV);

        // Subtle optical Fresnel water depth toning in the foreground while keeping original photo colors
        float3 deepTint = vColor.rgb * float3(0.84, 0.93, 0.98);
        vColor.rgb = mix(vColor.rgb, deepTint, depthFactor * 0.28);

        float3 vLight = normalize(in.vPosition - uniforms.vLightPos);
        float3 vCamera = normalize(float3(0.0, -0.8, -0.35) - in.vPosition);
        float3 vReflected = normalize(vLight - (2.0 * dot(vLight, vNoise.xyz) * vNoise.xyz));
        float fCos = max(0.0, dot(vReflected, vCamera));

        float spec = pow(fCos, 140.0) * 0.85 + pow(fCos, 32.0) * 0.08 * depthFactor;
        vColor = mix(vColor, float4(1.0, 0.90, 0.68, 1.0), clamp(spec, 0.0, 1.0));
        vColor.a = 0.84;
        return vColor;
    }

    // 3. VSBlit0.glsl (Pass 2 & Pass 3 Vertex Shader)
    vertex BlitVaryings vertexBlit0(
        uint vertexID [[vertex_id]],
        constant float4 *vertices [[buffer(0)]]
    ) {
        BlitVaryings out;
        float4 packed = vertices[vertexID];
        out.position = float4(packed.xy, 0.0, 1.0);
        out.vTexCoords = packed.zw;
        return out;
    }

    // 4. PSBlit0.glsl (Daylight Blit Fragment Shader, 05:00..21:59) with smooth shoreline feathering
    fragment float4 fragmentBlit0Day(
        BlitVaryings in [[stage_in]],
        texture2d<float> vTexture0 [[texture(0)]],
        sampler linearSampler [[sampler(0)]]
    ) {
        float4 c = vTexture0.sample(linearSampler, in.vTexCoords);
        float edgeFeather = smoothstep(1.0, 0.88, in.vTexCoords.y);
        c.a = 0.92 * (0.25 + 0.75 * edgeFeather);
        return c;
    }

    // 5. PSBlit0_night.glsl (Night Blit Fragment Shader, 22:00..04:59) with smooth shoreline feathering
    fragment float4 fragmentBlit0Night(
        BlitVaryings in [[stage_in]],
        texture2d<float> vTexture0 [[texture(0)]],
        sampler linearSampler [[sampler(0)]]
    ) {
        float4 c = vTexture0.sample(linearSampler, in.vTexCoords);
        c.r *= 0.25;
        c.g *= 0.25;
        c.b *= 0.42;
        float edgeFeather = smoothstep(1.0, 0.88, in.vTexCoords.y);
        c.a = 0.92 * (0.25 + 0.75 * edgeFeather);
        return c;
    }
    """
}

// MARK: - 5. 3-Pass Metal Water Renderer (`F0.n` — `WaterMetalRenderer`)

/// Native Metal reconstruction of `F0.n` (`WaterGLRenderer`, `RENDERER.md` Section 2):
/// - **Pass 1 (`k()`)**: Renders the full pond texture `B` with counter-scrolling normal maps `wNoise3` (`-vOffset`)
///   and `wNoise4` (`+vOffset`) into an offscreen **`256 x 512`** texture `Y` (`WaterShaderMath.offscreenWidth x offscreenHeight`).
/// - **Pass 2 (`j(isDay)`)**: Blits `Y` onto the full screen with `alpha = 0.9` using either day (`PSBlit0`)
///   or night (`PSBlit0_night`: `R *= 0.25, G *= 0.25, B *= 0.40`) fragment shader.
/// - **Pass 3 (`l(isDay)`)**: Overlays the top quarter of the screen (`Y in [0.5, 1.0]` NDC = top 25%)
///   with the unrefracted sky/shoreline texture `f0`.
@MainActor
public final class WaterMetalRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue

    public let waterPassPipeline: MTLRenderPipelineState
    public let dayBlitPipeline: MTLRenderPipelineState
    public let nightBlitPipeline: MTLRenderPipelineState

    public let offscreenWaterTexture: MTLTexture
    public let noise1Texture: MTLTexture
    public let noise2Texture: MTLTexture
    public private(set) var diffusePondTexture: MTLTexture
    public private(set) var topQuarterSkyTexture: MTLTexture
    public private(set) var currentPondIndex: Int

    private let fullScreenQuadBuffer: MTLBuffer
    private let topQuarterSkyQuadBuffer: MTLBuffer
    private let linearClampSampler: MTLSamplerState
    private let linearRepeatSampler: MTLSamplerState

    /// Corresponds to `F0.n.V` (`vOffset` in `[0.0 .. 1.0]`, incremented by `+0.0005` per frame).
    public private(set) var phaseOffset: Float = 0.0
    /// Corresponds to `F0.n.c0` (`true` = day `05:00..21:59`, `false` = night `22:00..04:59`).
    public var isDayLight: Bool = true

    private struct UniformPayload {
        var vOffset: Float
        var pad0: Float = 0
        var pad1: Float = 0
        var pad2: Float = 0
        var vLightPos: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 0.0)
        var pad3: Float = 0
    }

    public init?(
        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
        noise1TGAData: Data? = nil,
        noise2TGAData: Data? = nil,
        pondIndex: Int = 0,
        gameDataDirectoryURL: URL? = nil
    ) {
        guard let dev = device,
              let queue = dev.makeCommandQueue(),
              let library = try? dev.makeLibrary(source: WaterMetalShaderSource.mslSource, options: nil),
              let vsBack = library.makeFunction(name: "vertexBackGround"),
              let fsBack = library.makeFunction(name: "fragmentBackGround"),
              let vsBlit = library.makeFunction(name: "vertexBlit0"),
              let fsDay = library.makeFunction(name: "fragmentBlit0Day"),
              let fsNight = library.makeFunction(name: "fragmentBlit0Night") else {
            return nil
        }

        self.device = dev
        self.commandQueue = queue
        self.currentPondIndex = pondIndex

        // Pass 1 pipeline (`256 x 512` offscreen target)
        let backDesc = MTLRenderPipelineDescriptor()
        backDesc.vertexFunction = vsBack
        backDesc.fragmentFunction = fsBack
        backDesc.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Pass 2 & Pass 3 pipelines (Day / Night Blit with `GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA`)
        func makeBlitPipeline(fragment: MTLFunction) throws -> MTLRenderPipelineState {
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vsBlit
            desc.fragmentFunction = fragment
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try dev.makeRenderPipelineState(descriptor: desc)
        }

        guard let waterPipe = try? dev.makeRenderPipelineState(descriptor: backDesc),
              let dayPipe = try? makeBlitPipeline(fragment: fsDay),
              let nightPipe = try? makeBlitPipeline(fragment: fsNight) else {
            return nil
        }

        self.waterPassPipeline = waterPipe
        self.dayBlitPipeline = dayPipe
        self.nightBlitPipeline = nightPipe

        // Full-screen quad (`F0.n.l` + `F0.n.g`: `[-1, 1] x [-1, 1]`, UV `[0, 1] x [0, 1]`)
        let fullScreenVertices: [SIMD4<Float>] = [
            SIMD4<Float>(-1.0, -1.0, 0.0, 1.0),
            SIMD4<Float>( 1.0, -1.0, 1.0, 1.0),
            SIMD4<Float>(-1.0,  1.0, 0.0, 0.0),
            SIMD4<Float>( 1.0, -1.0, 1.0, 1.0),
            SIMD4<Float>( 1.0,  1.0, 1.0, 0.0),
            SIMD4<Float>(-1.0,  1.0, 0.0, 0.0)
        ]
        // Top-quarter sky quad (`F0.n.c` + `F0.n.g`: `X in [-1, 1], Y in [0.5, 1.0]`, UV `[0, 1] x [0, 1]`)
        let topSkyVertices: [SIMD4<Float>] = [
            SIMD4<Float>(-1.0,  0.5, 0.0, 1.0),
            SIMD4<Float>( 1.0,  0.5, 1.0, 1.0),
            SIMD4<Float>(-1.0,  1.0, 0.0, 0.0),
            SIMD4<Float>( 1.0,  0.5, 1.0, 1.0),
            SIMD4<Float>( 1.0,  1.0, 1.0, 0.0),
            SIMD4<Float>(-1.0,  1.0, 0.0, 0.0)
        ]

        guard let fsBuf = dev.makeBuffer(
                bytes: fullScreenVertices,
                length: MemoryLayout<SIMD4<Float>>.stride * fullScreenVertices.count,
                options: .storageModeShared
              ),
              let skyBuf = dev.makeBuffer(
                bytes: topSkyVertices,
                length: MemoryLayout<SIMD4<Float>>.stride * topSkyVertices.count,
                options: .storageModeShared
              ) else {
            return nil
        }
        self.fullScreenQuadBuffer = fsBuf
        self.topQuarterSkyQuadBuffer = skyBuf

        let clampDesc = MTLSamplerDescriptor()
        clampDesc.minFilter = .linear
        clampDesc.magFilter = .linear
        clampDesc.sAddressMode = .clampToEdge
        clampDesc.tAddressMode = .clampToEdge

        let repeatDesc = MTLSamplerDescriptor()
        repeatDesc.minFilter = .linear
        repeatDesc.magFilter = .linear
        repeatDesc.sAddressMode = .repeat
        repeatDesc.tAddressMode = .repeat

        guard let clampSamp = dev.makeSamplerState(descriptor: clampDesc),
              let repeatSamp = dev.makeSamplerState(descriptor: repeatDesc) else {
            return nil
        }
        self.linearClampSampler = clampSamp
        self.linearRepeatSampler = repeatSamp

        // Create `256 x 512` offscreen render target (`F0.n.b0 = 256, a0 = 512`)
        let offscreenDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: WaterShaderMath.offscreenWidth,
            height: WaterShaderMath.offscreenHeight,
            mipmapped: false
        )
        offscreenDesc.usage = [.renderTarget, .shaderRead]

        let rawNoise1 = noise1TGAData
            ?? TgaTextureLoader.loadBundledNoiseTGA(named: "wNoise3.tga", gameDataDirectoryURL: gameDataDirectoryURL)
            ?? TgaTextureLoader.makeProceduralWaveNoiseTGA(seedPhase: 0)
        let rawNoise2 = noise2TGAData
            ?? TgaTextureLoader.loadBundledNoiseTGA(named: "wNoise4.tga", gameDataDirectoryURL: gameDataDirectoryURL)
            ?? TgaTextureLoader.makeProceduralWaveNoiseTGA(seedPhase: 37)

        guard let offscreenTex = dev.makeTexture(descriptor: offscreenDesc),
              let decoded1 = try? TgaTextureLoader.decode(data: rawNoise1),
              let decoded2 = try? TgaTextureLoader.decode(data: rawNoise2),
              let n1Tex = Self.makeRGBATexture(device: dev, width: decoded1.width, height: decoded1.height, rgba: decoded1.rgbaBytes),
              let n2Tex = Self.makeRGBATexture(device: dev, width: decoded2.width, height: decoded2.height, rgba: decoded2.rgbaBytes),
              let (pondTex, skyTex) = Self.makeBundledOrProceduralPondAndSkyTextures(
                  device: dev,
                  pondIndex0Based: pondIndex,
                  gameDataDirectoryURL: gameDataDirectoryURL
              ) else {
            return nil
        }

        self.offscreenWaterTexture = offscreenTex
        self.noise1Texture = n1Tex
        self.noise2Texture = n2Tex
        self.diffusePondTexture = pondTex
        self.topQuarterSkyTexture = skyTex

        super.init()
    }

    /// Updates `diffusePondTexture` (`B`) and `topQuarterSkyTexture` (`f0`) when the active pond changes (`0..14`).
    public func setPondIndex(_ pondIndex: Int, gameDataDirectoryURL: URL? = nil) {
        guard pondIndex != currentPondIndex else { return }
        if let (pondTex, skyTex) = Self.makeBundledOrProceduralPondAndSkyTextures(
            device: device,
            pondIndex0Based: pondIndex,
            gameDataDirectoryURL: gameDataDirectoryURL
        ) {
            self.diffusePondTexture = pondTex
            self.topQuarterSkyTexture = skyTex
            self.currentPondIndex = pondIndex
        }
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        // Step 0 (`F0.n.o()`): advance wave phase offset `V += 0.0005f`
        phaseOffset = WaterShaderMath.stepPhaseOffset(phaseOffset)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let screenPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }

        // Pass 1 (`F0.n.k()`): Offscreen water refraction & sun specular into `256 x 512` FBO
        let offscreenPass = MTLRenderPassDescriptor()
        offscreenPass.colorAttachments[0].texture = offscreenWaterTexture
        offscreenPass.colorAttachments[0].loadAction = .clear
        offscreenPass.colorAttachments[0].storeAction = .store
        offscreenPass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenPass) {
            encoder.setRenderPipelineState(waterPassPipeline)
            encoder.setVertexBuffer(fullScreenQuadBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(diffusePondTexture, index: 0)
            encoder.setFragmentTexture(noise1Texture, index: 1)
            encoder.setFragmentTexture(noise2Texture, index: 2)
            encoder.setFragmentSamplerState(linearClampSampler, index: 0)
            encoder.setFragmentSamplerState(linearRepeatSampler, index: 1)

            var uniforms = UniformPayload(vOffset: phaseOffset)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<UniformPayload>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        // Pass 2 (`F0.n.j(isDay)`) & Pass 3 (`F0.n.l(isDay)`): Fullscreen water blit + Top 25% static sky overlay
        screenPassDescriptor.colorAttachments[0].loadAction = .clear
        screenPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: screenPassDescriptor) {
            let activeBlitPipeline = isDayLight ? dayBlitPipeline : nightBlitPipeline
            encoder.setRenderPipelineState(activeBlitPipeline)
            encoder.setFragmentSamplerState(linearClampSampler, index: 0)

            // Pass 2: Fullscreen refracted water (`offscreenWaterTexture`)
            encoder.setVertexBuffer(fullScreenQuadBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(offscreenWaterTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

            // Pass 3: Static top-quarter sky/shore (`topQuarterSkyTexture`, `Y in [0.5, 1.0]` NDC)
            encoder.setVertexBuffer(topQuarterSkyQuadBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(topQuarterSkyTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static func makeRGBATexture(
        device: MTLDevice,
        width: Int,
        height: Int,
        rgba: [UInt8]
    ) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: desc) else { return nil }
        rgba.withUnsafeBytes { rawPtr in
            if let base = rawPtr.baseAddress {
                tex.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: base,
                    bytesPerRow: width * 4
                )
            }
        }
        return tex
    }

    private static func makeBundledOrProceduralPondAndSkyTextures(
        device: MTLDevice,
        pondIndex0Based: Int,
        gameDataDirectoryURL: URL? = nil
    ) -> (MTLTexture, MTLTexture)? {
        if let decoded = OriginalGameAssetsLoader.decodePondAndTopQuarterSkyRGBA(
            pondIndex0Based: pondIndex0Based,
            gameDataDirectoryURL: gameDataDirectoryURL
        ),
           let pondTex = makeRGBATexture(device: device, width: decoded.width, height: decoded.height, rgba: decoded.fullRGBA),
           let skyTex = makeRGBATexture(device: device, width: decoded.width, height: decoded.skyHeight, rgba: decoded.skyRGBA) {
            return (pondTex, skyTex)
        }
        return makeProceduralPondAndSkyTextures(device: device, width: 256, height: 256)
    }

    private static func makeProceduralPondAndSkyTextures(
        device: MTLDevice,
        width: Int,
        height: Int
    ) -> (MTLTexture, MTLTexture)? {
        var fullRGBA = [UInt8](repeating: 255, count: width * height * 4)
        let skyHeight = max(1, height / 4)
        var skyRGBA = [UInt8](repeating: 255, count: width * skyHeight * 4)

        for y in 0..<height {
            let t = Double(y) / Double(max(1, height - 1))
            for x in 0..<width {
                let offset = (y * width + x) * 4
                if y < skyHeight {
                    // Sky and shoreline trees in top 25%
                    let skyT = Double(y) / Double(max(1, skyHeight - 1))
                    let r = UInt8(clamping: Int((1.0 - skyT) * 110.0 + skyT * 45.0))
                    let g = UInt8(clamping: Int((1.0 - skyT) * 175.0 + skyT * 115.0))
                    let b = UInt8(clamping: Int((1.0 - skyT) * 235.0 + skyT * 65.0))
                    fullRGBA[offset] = r
                    fullRGBA[offset + 1] = g
                    fullRGBA[offset + 2] = b
                    fullRGBA[offset + 3] = 255

                    skyRGBA[offset] = r
                    skyRGBA[offset + 1] = g
                    skyRGBA[offset + 2] = b
                    skyRGBA[offset + 3] = 255
                } else {
                    // Water depth gradient in lower 75%
                    let waterT = (t - 0.25) / 0.75
                    let r = UInt8(clamping: Int((1.0 - waterT) * 28.0 + waterT * 10.0))
                    let g = UInt8(clamping: Int((1.0 - waterT) * 98.0 + waterT * 44.0))
                    let b = UInt8(clamping: Int((1.0 - waterT) * 152.0 + waterT * 88.0))
                    fullRGBA[offset] = r
                    fullRGBA[offset + 1] = g
                    fullRGBA[offset + 2] = b
                    fullRGBA[offset + 3] = 255
                }
            }
        }

        guard let pondTex = makeRGBATexture(device: device, width: width, height: height, rgba: fullRGBA),
              let skyTex = makeRGBATexture(device: device, width: width, height: skyHeight, rgba: skyRGBA) else {
            return nil
        }
        return (pondTex, skyTex)
    }
}

// MARK: - 6. SwiftUI Wrapper for `MTKView` (`GLSurfaceView` Equivalent)

#if canImport(UIKit)
import UIKit

public struct MetalWaterSurfaceView: UIViewRepresentable {
    public var isDayLight: Bool
    public var pondIndex: Int

    public init(isDayLight: Bool, pondIndex: Int = 0) {
        self.isDayLight = isDayLight
        self.pondIndex = pondIndex
    }

    public func makeCoordinator() -> WaterMetalRenderer? {
        WaterMetalRenderer(pondIndex: pondIndex)
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        if let renderer = context.coordinator {
            renderer.isDayLight = isDayLight
            renderer.setPondIndex(pondIndex)
            mtkView.device = renderer.device
            mtkView.delegate = renderer
            mtkView.colorPixelFormat = .bgra8Unorm
        }
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator?.isDayLight = isDayLight
        context.coordinator?.setPondIndex(pondIndex)
    }
}
#elseif canImport(AppKit)
import AppKit

public struct MetalWaterSurfaceView: NSViewRepresentable {
    public var isDayLight: Bool
    public var pondIndex: Int

    public init(isDayLight: Bool, pondIndex: Int = 0) {
        self.isDayLight = isDayLight
        self.pondIndex = pondIndex
    }

    public func makeCoordinator() -> WaterMetalRenderer? {
        WaterMetalRenderer(pondIndex: pondIndex)
    }

    public func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        if let renderer = context.coordinator {
            renderer.isDayLight = isDayLight
            renderer.setPondIndex(pondIndex)
            mtkView.device = renderer.device
            mtkView.delegate = renderer
            mtkView.colorPixelFormat = .bgra8Unorm
        }
        return mtkView
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator?.isDayLight = isDayLight
        context.coordinator?.setPondIndex(pondIndex)
    }
}
#endif
