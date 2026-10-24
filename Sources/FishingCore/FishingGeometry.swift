import Foundation

public struct Point2D: Sendable, Equatable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public struct Rect2D: Sendable, Equatable {
    public var left: Float
    public var top: Float
    public var right: Float
    public var bottom: Float

    public init(left: Float, top: Float, right: Float, bottom: Float) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    public var width: Float { right - left }
    public var height: Float { bottom - top }
}

public struct QuadraticBezierCurve: Sendable, Equatable {
    public let start: Point2D
    public let control: Point2D
    public let end: Point2D
    public let alpha: Int
    public let strokeWidth: Float

    public init(
        start: Point2D,
        control: Point2D,
        end: Point2D,
        alpha: Int,
        strokeWidth: Float
    ) {
        self.start = start
        self.control = control
        self.end = end
        self.alpha = alpha
        self.strokeWidth = strokeWidth
    }
}

public struct BobberState: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var ripplesEnabled: Bool
    public var isBiteTexture: Bool = false
    public var bitmapWidth: Int
    public var bitmapHeight: Int
    public private(set) var ripples: [Rect2D] = []

    public init(
        x: Float,
        y: Float,
        ripplesEnabled: Bool,
        bitmapWidth: Int = 24,
        bitmapHeight: Int = 40
    ) {
        self.x = x
        self.y = y
        self.ripplesEnabled = ripplesEnabled
        self.bitmapWidth = bitmapWidth
        self.bitmapHeight = bitmapHeight
    }

    public mutating func switchToBiteSprite() {
        isBiteTexture = true
    }

    public mutating func addCastRipple(enabled: Bool) {
        guard ripples.count < 10, enabled else { return }
        let centerY = y + Float(bitmapHeight / 2)
        let rect = Rect2D(
            left: x - 10.0,
            top: centerY - 5.0,
            right: x + 10.0,
            bottom: centerY + 5.0
        )
        ripples.append(rect)
    }

    public mutating func addBiteRipple(enabled: Bool) {
        guard ripples.count < 10, enabled else { return }
        let rect = Rect2D(
            left: x - 5.0,
            top: y - 2.5,
            right: x + 5.0,
            bottom: y + 2.5
        )
        ripples.append(rect)
    }

    public mutating func stepRipples(
        canvasWidth: Int,
        rng: inout some FishingRandomGenerator
    ) {
        let maxWidth = Float(canvasWidth) * 0.15
        var updated: [Rect2D] = []
        updated.reserveCapacity(ripples.count)
        for var rect in ripples {
            rect.left -= Float(rng.nextInt(bound: 5))
            rect.top -= Float(rng.nextInt(bound: 2))
            rect.right += Float(rng.nextInt(bound: 5))
            rect.bottom += Float(rng.nextInt(bound: 2))
            if rect.width <= maxWidth {
                updated.append(rect)
            }
        }
        ripples = updated
    }

    public static func rippleAlpha(ovalWidth: Float, canvasWidth: Int) -> Int {
        let maxWidth = Float(canvasWidth) * 0.15
        guard maxWidth > 0 else { return 0 }
        let raw = Int(((maxWidth - ovalWidth) * 150.0) / maxWidth)
        return max(0, min(150, raw))
    }

    public mutating func clampAndStep(
        canvasWidth: Int,
        canvasHeight: Int,
        rng: inout some FishingRandomGenerator
    ) {
        if ripplesEnabled {
            stepRipples(canvasWidth: canvasWidth, rng: &rng)
        }
        let halfW = Float(bitmapWidth / 2)
        let halfH = Float(bitmapHeight / 2)

        if x - halfW < 0 { x = halfW }
        if x + halfW > Float(canvasWidth) { x = Float(canvasWidth) - halfW }

        let minTopY = Float(canvasHeight / 4)
        if y - halfH < minTopY {
            let base = Float((canvasHeight / 4) + (bitmapHeight / 2))
            y = base + rng.nextFloat() * 5.0
        }

        if y + halfH > Float(canvasHeight) {
            y = Float(canvasHeight - (bitmapHeight / 2))
        }
    }
}

public struct RodSpriteState: Sendable, Equatable {
    /// Original PNG dimensions of `fishing_rod_0.png .. fishing_rod_15.png` (`res/sb.png .. res/Us.png`) in `fishing181.apk`.
    public static let nativeBitmapWidth: Int = 164
    public static let nativeBitmapHeight: Int = 419

    public static let drawableResourceIds: [Int] = [
        2131231188, 2131231189, 2131231196, 2131231197,
        2131231198, 2131231199, 2131231200, 2131231201,
        2131231202, 2131231203, 2131231190, 2131231191,
        2131231192, 2131231193, 2131231194, 2131231195
    ]

    public private(set) var frameIndex: Int = 0
    public private(set) var originX: Float = 0
    public private(set) var originY: Float = 0
    public private(set) var width: Int = 0
    public private(set) var height: Int = 0

    /// Reconstructs `D0.c.i()` (`pc=001b..006f`): uniform `Matrix.postScale(v3, v3)` where `v3 = (viewHeight / 2) / 419.0`.
    public static func scaledRodDimensions(forViewWidth viewWidth: Int, viewHeight: Int) -> (width: Int, height: Int) {
        let targetHeight = max(1, viewHeight / 2)
        let aspectScale = Float(targetHeight) / Float(nativeBitmapHeight)
        let rawWidth = max(1, Int((Float(nativeBitmapWidth) * aspectScale).rounded()))
        let maxRightAnchor = max(1, (viewWidth / 5) * 4)
        let clampedWidth = min(rawWidth, maxRightAnchor)
        return (width: clampedWidth, height: targetHeight)
    }

    public init(
        viewWidth: Int = 1280,
        viewHeight: Int = 800,
        rodWidth: Int = 200,
        rodHeight: Int = 400
    ) {
        updateLayout(
            viewWidth: viewWidth,
            viewHeight: viewHeight,
            scaledRodWidth: rodWidth,
            scaledRodHeight: rodHeight
        )
    }

    public mutating func updateLayout(
        viewWidth: Int,
        viewHeight: Int,
        scaledRodWidth: Int,
        scaledRodHeight: Int
    ) {
        self.width = scaledRodWidth
        self.height = scaledRodHeight
        self.originX = Float(((viewWidth / 5) * 4) - scaledRodWidth)
        self.originY = Float(viewHeight - scaledRodHeight)
    }

    public mutating func updateFrame(forTension tension: Int) {
        self.frameIndex = Self.frameIndex(forTension: tension)
    }

    public static func frameIndex(forTension tension: Int) -> Int {
        if tension == 0 { return 0 }
        else if tension > 0 && tension < 20 { return 1 }
        else if tension >= 20 && tension < 40 { return 2 }
        else if tension >= 40 && tension < 60 { return 3 }
        else if tension >= 60 && tension < 80 { return 4 }
        else if tension >= 80 && tension < 100 { return 5 }
        else if tension >= 100 && tension < 120 { return 6 }
        else if tension >= 120 && tension < 140 { return 7 }
        else if tension >= 140 && tension < 160 { return 8 }
        else if tension >= 160 && tension < 180 { return 9 }
        else if tension >= 180 && tension < 190 { return 10 }
        else if tension >= 190 && tension < 200 { return 11 }
        else if tension >= 200 && tension < 205 { return 12 }
        else if tension >= 205 && tension < 210 { return 13 }
        else if tension >= 210 && tension < 215 { return 14 }
        else if tension >= 215 { return 15 }
        else { return 0 }
    }
}

public struct FishingLineGeometry: Sendable, Equatable {
    public static let normalizedRodTipOffsets: [Point2D] = [
        Point2D(x: 0.93, y: 0.00),
        Point2D(x: 0.63, y: 0.00),
        Point2D(x: 0.53, y: 0.00),
        Point2D(x: 0.47, y: 0.01),
        Point2D(x: 0.44, y: 0.03),
        Point2D(x: 0.37, y: 0.10),
        Point2D(x: 0.34, y: 0.11),
        Point2D(x: 0.18, y: 0.11),
        Point2D(x: 0.10, y: 0.12),
        Point2D(x: 0.07, y: 0.14),
        Point2D(x: 0.09, y: 0.12),
        Point2D(x: 0.09, y: 0.14),
        Point2D(x: 0.09, y: 0.17),
        Point2D(x: 0.03, y: 0.27),
        Point2D(x: 0.03, y: 0.31),
        Point2D(x: 0.04, y: 0.42)
    ]

    public private(set) var isCastAnimating: Bool = false
    public private(set) var isPulled: Bool = false
    public private(set) var castProgress: Float = 0.0
    public var tensionFactor: Float = 0.0

    public init() {}

    public mutating func startCastAnimation() {
        isCastAnimating = true
        castProgress = 0.0
        isPulled = false
        tensionFactor = 0.0
    }

    public mutating func setPulled(_ pulled: Bool) {
        isPulled = pulled
        if pulled {
            tensionFactor = min(tensionFactor + 0.1, 1.0)
        } else {
            tensionFactor = max(tensionFactor - 0.05, 0.0)
        }
    }

    public static func rodTipPoint(for rod: RodSpriteState) -> Point2D {
        let idx = max(0, min(rod.frameIndex, normalizedRodTipOffsets.count - 1))
        let norm = normalizedRodTipOffsets[idx]
        return Point2D(
            x: rod.originX + Float(rod.width) * norm.x,
            y: rod.originY + Float(rod.height) * norm.y
        )
    }

    /// Pure non-mutating curve builder for intermediate visual interpolation frames (`stepRipplesAndCast == false`).
    public func buildCurrentCurve(
        rod: RodSpriteState,
        bobber: BobberState,
        jitterRandom: Float = 0.5
    ) -> QuadraticBezierCurve {
        let start = Self.rodTipPoint(for: rod)
        let targetX = bobber.x
        let targetY: Float
        if bobber.isBiteTexture || bobber.bitmapHeight <= 10 {
            targetY = bobber.y
        } else {
            targetY = bobber.y + Float(bobber.bitmapHeight / 2)
        }

        if isCastAnimating {
            let endX = start.x + (targetX - start.x) * castProgress
            let endY = start.y + (targetY - start.y) * castProgress
            let ctrlX = (start.x + endX) / 2.0
            let ctrlY = start.y - 150.0 * castProgress
            let alpha = Int(castProgress * 180.0)
            return QuadraticBezierCurve(
                start: start,
                control: Point2D(x: ctrlX, y: ctrlY),
                end: Point2D(x: endX, y: endY),
                alpha: alpha,
                strokeWidth: 1.5
            )
        } else if isPulled && tensionFactor > 0.1 {
            let ctrlX = (start.x + targetX) / 2.0
            let lift = (tensionFactor * 0.3) * 20.0
            let ctrlY = ((start.y + targetY) / 2.0) - lift
            let strokeWidth: Float
            if tensionFactor > 0.7 {
                strokeWidth = 1.5 + jitterRandom * 0.8
            } else {
                strokeWidth = 1.5 + tensionFactor * 0.5
            }
            return QuadraticBezierCurve(
                start: start,
                control: Point2D(x: ctrlX, y: ctrlY),
                end: Point2D(x: targetX, y: targetY),
                alpha: 180,
                strokeWidth: strokeWidth
            )
        } else {
            let ctrlX = (start.x + targetX) / 2.0
            let ctrlY = max(start.y, targetY) + 50.0
            return QuadraticBezierCurve(
                start: start,
                control: Point2D(x: ctrlX, y: ctrlY),
                end: Point2D(x: targetX, y: targetY),
                alpha: 180,
                strokeWidth: 1.5
            )
        }
    }

    public mutating func stepAndBuildCurve(
        rod: RodSpriteState,
        bobber: BobberState,
        jitterRandom: Float = 0.5
    ) -> QuadraticBezierCurve {
        if isCastAnimating {
            let curve = buildCurrentCurve(rod: rod, bobber: bobber, jitterRandom: jitterRandom)
            castProgress += 0.08
            if castProgress >= 1.0 {
                isCastAnimating = false
                castProgress = 1.0
            }
            return curve
        }

        // Per-frame line tautness ramp (`D0.b.d(Canvas)` in original bytecode)
        if isPulled {
            tensionFactor = min(1.0, tensionFactor + 0.1)
        } else {
            tensionFactor = max(0.0, tensionFactor - 0.05)
        }

        return buildCurrentCurve(rod: rod, bobber: bobber, jitterRandom: jitterRandom)
    }
}