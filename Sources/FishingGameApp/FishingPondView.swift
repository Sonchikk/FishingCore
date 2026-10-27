import SwiftUI
import FishingCore
import FishingDatabase

/// Authentic fishing pond screen (`GameActivity` + `GameView` + `F0.n` `WaterMetalRenderer`),
/// supporting two distinct visual modes controlled from Settings (`coordinator.isRemasterModeEnabled`):
/// 1. **Classic v1.81 Mode (`false`)**: 1:1 reconstruction of the 2013 Android layout (`res/Ak.xml`) with classic PNG sprites;
/// 2. **Remaster Mode (`true`)**:
///    - Living procedural vector Carbon-Fiber Spinning Rod & Reel (with idle breathing sway, whipping cast motion,
///      continuous physics bend `0..225`, tip tremor, ceramic line guides, and rotating reel handle);
///    - High-detail vector Waggler Float (with underwater stem reflection, wave buoyancy bobbing, fluorescent multi-band antenna, and dive wake);
///    - Kinematic parabolic cast flight trajectory with airborne float + uncoiling spiral line + water impact splash crown;
///    - Multi-layer water surface caustics, sun/moon reflection path, floating lily pads, and swaying shoreline reeds;
///    - Dedicated 4-tile Matte-Slate & Warm-Brass bottom control deck (with a separate «Вымотать» tile when cast, never overlapping «Садок»).
public struct FishingPondView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var isBaitChooserPresented: Bool = false
    @State private var isQuickTackleSheetPresented: Bool = false

    public static let goldTextColor = Color(red: 221.0 / 255.0, green: 180.0 / 255.0, blue: 109.0 / 255.0) // #DDB46D warm brass
    public static let sageAccentColor = Color(red: 86.0 / 255.0, green: 158.0 / 255.0, blue: 114.0 / 255.0) // #569E72 muted sage
    public static let matteSlateSurface = Color(red: 21.0 / 255.0, green: 30.0 / 255.0, blue: 35.0 / 255.0) // #151E23 matte slate
    public static let matteCardSurface = Color(red: 28.0 / 255.0, green: 37.0 / 255.0, blue: 44.0 / 255.0) // #1C252C card fill

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            pondFrameBackground
            VStack(spacing: 0) {
                PondExperienceTopBarView(coordinator: coordinator)
                pondInteractiveArea
                if coordinator.isDebugOverlayEnabled {
                    PondDeveloperDebugToolbarView(coordinator: coordinator)
                }
                if coordinator.isRemasterModeEnabled {
                    RemasterPondBottomDeckView(
                        coordinator: coordinator,
                        onPresentBaitChooser: {
                            guard coordinator.stateMachine.state == .idle else { return }
                            if coordinator.ownedBaits.isEmpty {
                                coordinator.activeAlert = .operationError(message: "В рюкзаке нет наживок.")
                            } else {
                                isBaitChooserPresented = true
                            }
                        },
                        onPresentQuickTackle: {
                            guard coordinator.stateMachine.state == .idle else { return }
                            isQuickTackleSheetPresented = true
                        }
                    )
                } else {
                    ClassicPondBottomControlsPanelView(
                        coordinator: coordinator,
                        onPresentBaitChooser: {
                            guard coordinator.stateMachine.state == .idle else { return }
                            if coordinator.ownedBaits.isEmpty {
                                coordinator.activeAlert = .operationError(message: "В рюкзаке нет наживок.")
                            } else {
                                isBaitChooserPresented = true
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $isBaitChooserPresented) {
            BaitQuickChooserSheet(coordinator: coordinator)
        }
        .sheet(isPresented: $isQuickTackleSheetPresented) {
            RemasterQuickTackleAndPondSheet(coordinator: coordinator)
        }
    }

    @ViewBuilder
    private var pondFrameBackground: some View {
        if coordinator.isRemasterModeEnabled {
            Self.matteSlateSurface.ignoresSafeArea()
        } else if let secondBg = OriginalGameAssetsLoader.image(named: "second_background") {
            secondBg
                .resizable()
                .ignoresSafeArea()
        } else {
            Color(red: 0.08, green: 0.12, blue: 0.16)
                .ignoresSafeArea()
        }
    }

    // MARK: - Main Pond Area (`GameView` + Top Overlay Buttons + Remaster Atmosphere & Sonar)

    private var pondInteractiveArea: some View {
        GeometryReader { geo in
            let w = max(320, Int(geo.size.width.rounded()))
            let h = max(240, Int(geo.size.height.rounded()))

            ZStack(alignment: .top) {
                pondWaterLayer
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                if coordinator.isRemasterModeEnabled {
                    RemasterAtmosphericGradientOverlay(
                        hour: coordinator.gameClock.hour,
                        minute: coordinator.gameClock.minute,
                        weather: coordinator.currentResolvedWeather
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
                }

                pondCanvasLayer(viewportWidth: w, viewportHeight: h)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    PondTopOverlayBarView(
                        coordinator: coordinator,
                        onOpenQuickTackle: {
                            guard coordinator.stateMachine.state == .idle else { return }
                            isQuickTackleSheetPresented = true
                        }
                    )

                    if coordinator.isRemasterModeEnabled {
                        RemasterPondFloatingHUDView(
                            coordinator: coordinator,
                            onOpenBaitChooser: {
                                guard coordinator.stateMachine.state == .idle else { return }
                                isBaitChooserPresented = true
                            }
                        )
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                coordinator.updateViewportSize(width: w, height: h)
                coordinator.audioHaptics.syncAmbientTrack(
                    pondIndex: coordinator.selectedPondIndex,
                    hour: coordinator.gameClock.hour,
                    isPondScreenVisible: true
                )
            }
            .onDisappear {
                coordinator.audioHaptics.isOnPondScreen = false
            }
            .onChange(of: geo.size) { _, newSize in
                coordinator.updateViewportSize(
                    width: max(320, Int(newSize.width.rounded())),
                    height: max(240, Int(newSize.height.rounded()))
                )
            }
        }
    }

    @ViewBuilder
    private var pondWaterLayer: some View {
        if coordinator.isWaterShaderActive {
            MetalWaterSurfaceView(
                isDayLight: coordinator.dayNightLighting.isDayLight,
                pondIndex: coordinator.selectedPondIndex
            )
            .allowsHitTesting(false)
        } else {
            Static2DPondBackgroundView(
                pondIndex: coordinator.selectedPondIndex,
                isDayLight: coordinator.dayNightLighting.isDayLight,
                isRemasterMode: coordinator.isRemasterModeEnabled
            )
        }
    }

    private func pondCanvasLayer(viewportWidth: Int, viewportHeight: Int) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !coordinator.isRemasterModeEnabled)) { timeline in
            let phaseSec = timeline.date.timeIntervalSinceReferenceDate
            let nowMs = Int64(timeline.date.timeIntervalSince1970 * 1000.0)
            Canvas { context, size in
                let activeRod = resolvedRodSprite(for: size)
                if coordinator.isRemasterModeEnabled {
                    drawRemasterWaterDepthAndHorizonSoftener(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterSkyStarsAndFireflies(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterUnderwaterFishSilhouette(in: &context, size: size, phaseSec: phaseSec)

                    let rodGeometry = computeRemasterProceduralRodGeometry(
                        size: size,
                        phaseSec: phaseSec,
                        nowMs: nowMs
                    )
                    drawRemasterFishingLineAndCastFlight(
                        in: &context,
                        rodTip: rodGeometry.tip,
                        phaseSec: phaseSec,
                        nowMs: nowMs
                    )
                    drawRemasterRipplesAndProceduralFloat(
                        in: &context,
                        canvasWidth: max(1, Int(size.width)),
                        phaseSec: phaseSec,
                        nowMs: nowMs
                    )
                    drawRemasterWaterSplashes(in: &context, phaseSec: phaseSec)
                    drawRemasterWeatherParticles(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterForegroundShorelineReedsAndLilies(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterProceduralRodAndReel(
                        in: &context,
                        geometry: rodGeometry,
                        phaseSec: phaseSec
                    )
                } else {
                    drawClassicFishingLine(in: &context, rod: activeRod)
                    drawClassicRipplesAndBobber(in: &context, canvasWidth: max(1, Int(size.width)))
                    drawClassicRodSprite(in: &context, rod: activeRod)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        coordinator.updateViewportSize(width: viewportWidth, height: viewportHeight)
                        if coordinator.stateMachine.state == .idle {
                            coordinator.castAt(
                                x: Float(value.location.x),
                                y: Float(value.location.y)
                            )
                        }
                    }
            )
        }
    }

    // MARK: - Modular Canvas Drawing Helpers (`GameView.draw(Canvas)` + Remaster Scenic Water, Procedural Rod, Float & Cast)

    private func resolvedRodSprite(for canvasSize: CGSize) -> RodSpriteState {
        let w = max(1, Int(canvasSize.width.rounded()))
        let h = max(1, Int(canvasSize.height.rounded()))
        var rod = coordinator.stateMachine.rodSprite
        let expectedDims = RodSpriteState.scaledRodDimensions(forViewWidth: w, viewHeight: h)
        if coordinator.stateMachine.viewWidth != w
            || coordinator.stateMachine.viewHeight != h
            || rod.width != expectedDims.width
            || rod.height != expectedDims.height {
            rod.updateLayout(
                viewWidth: w,
                viewHeight: h,
                scaledRodWidth: expectedDims.width,
                scaledRodHeight: expectedDims.height
            )
        }
        return rod
    }

    /// Enhances the water surface with shoreline mist, sun/moon shimmer column, multi-octave wave ribbons, and deep-water vignetting.
    private func drawRemasterWaterDepthAndHorizonSoftener(
        in context: inout GraphicsContext,
        size: CGSize,
        phaseSec: Double
    ) {
        let horizonY = size.height * 0.245
        let isDay = coordinator.dayNightLighting.isDayLight

        // 1. Fresnel deep-water vertical gradient over the lower 75% water region
        let waterRect = CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)
        context.fill(
            Path(waterRect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.14, green: 0.30, blue: 0.38).opacity(isDay ? 0.14 : 0.24),
                    Color(red: 0.06, green: 0.16, blue: 0.22).opacity(isDay ? 0.22 : 0.32),
                    Color(red: 0.03, green: 0.08, blue: 0.12).opacity(0.46)
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: horizonY),
                endPoint: CGPoint(x: size.width * 0.5, y: size.height)
            )
        )

        // 2. Soft atmospheric mist band along the distant shoreline (`y ≈ 0.20..0.30`)
        let mistBand = CGRect(x: 0, y: horizonY - 28, width: size.width, height: 60)
        context.fill(
            Path(mistBand),
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color(red: 0.86, green: 0.90, blue: 0.92).opacity(isDay ? 0.20 : 0.09),
                    Color.white.opacity(0.0)
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: mistBand.minY),
                endPoint: CGPoint(x: size.width * 0.5, y: mistBand.maxY)
            )
        )

        // 3. Shimmering Sun / Moon reflection path (`дорожка света на воде`)
        let lightColumnCenterX = size.width * 0.46
        for step in 0..<22 {
            let norm = Double(step) / 21.0
            let y = horizonY + 8.0 + CGFloat(pow(norm, 1.45)) * (size.height * 0.66)
            let sway = CGFloat(sin(phaseSec * 2.4 + Double(step) * 0.85)) * (6.0 + CGFloat(norm) * 14.0)
            let w = CGFloat(18.0 + norm * 68.0) * CGFloat(0.75 + 0.25 * cos(phaseSec * 3.1 + Double(step)))
            let h: CGFloat = CGFloat(1.6 + norm * 2.2)
            let glintRect = CGRect(x: lightColumnCenterX + sway - w * 0.5, y: y, width: w, height: h)
            let glintColor = isDay
                ? Color(red: 0.98, green: 0.88, blue: 0.64).opacity((1.0 - norm * 0.65) * 0.18)
                : Color(red: 0.72, green: 0.86, blue: 0.98).opacity((1.0 - norm * 0.65) * 0.14)
            context.fill(Path(ellipseIn: glintRect), with: .color(glintColor))
        }

        // 4. Multi-octave animated wave crest ribbons across the lake
        for row in 0..<16 {
            let normY = Double(row) / 15.0
            let y = horizonY + 12.0 + CGFloat(pow(normY, 1.32)) * (size.height * 0.72)
            let waveShift = CGFloat(sin(phaseSec * (0.85 + Double(row % 4) * 0.22) + Double(row) * 1.3)) * 28.0
            let segWidth = size.width * CGFloat(0.24 + 0.20 * (Double(row % 5) / 4.0))
            let centerX = size.width * CGFloat(0.18 + 0.64 * (0.5 + 0.5 * sin(Double(row * 37 + 11)))) + waveShift

            var wavePath = Path()
            let crestAmp = CGFloat(1.2 + normY * 2.4) * CGFloat(sin(phaseSec * 1.9 + Double(row)))
            wavePath.move(to: CGPoint(x: centerX - segWidth * 0.5, y: y))
            wavePath.addQuadCurve(
                to: CGPoint(x: centerX + segWidth * 0.5, y: y),
                control: CGPoint(x: centerX, y: y + crestAmp)
            )
            let alpha = (1.0 - normY * 0.45) * (isDay ? 0.14 : 0.08)
            context.stroke(
                wavePath,
                with: .color(Color(red: 0.88, green: 0.94, blue: 0.98).opacity(alpha)),
                lineWidth: 1.3
            )
        }
    }

    /// Swaying foreground shoreline reeds (`камыши`) and floating water-lily pads (`кувшинки`) for rich foreground depth.
    private func drawRemasterForegroundShorelineReedsAndLilies(
        in context: inout GraphicsContext,
        size: CGSize,
        phaseSec: Double
    ) {
        // 1. Floating water-lily pads near the lower-left shore
        let lilies: [(CGFloat, CGFloat, CGFloat)] = [
            (78, size.height - 46, 22),
            (108, size.height - 34, 18),
            (54, size.height - 28, 16)
        ]
        for (i, lily) in lilies.enumerated() {
            let bobX = lily.0 + CGFloat(sin(phaseSec * 1.1 + Double(i))) * 2.5
            let bobY = lily.1 + CGFloat(cos(phaseSec * 1.4 + Double(i))) * 1.2
            let padRect = CGRect(x: bobX - lily.2 * 0.5, y: bobY - lily.2 * 0.24, width: lily.2, height: lily.2 * 0.48)
            context.fill(
                Path(ellipseIn: padRect),
                with: .color(Color(red: 0.16, green: 0.34, blue: 0.22).opacity(0.76))
            )
            context.stroke(
                Path(ellipseIn: padRect),
                with: .color(Color(red: 0.28, green: 0.50, blue: 0.34).opacity(0.55)),
                lineWidth: 1.0
            )
            if i == 0 {
                // Small white-pink water-lily blossom on the first pad
                let flowerRect = CGRect(x: bobX - 3.5, y: bobY - 4.5, width: 7.0, height: 5.0)
                context.fill(
                    Path(ellipseIn: flowerRect),
                    with: .color(Color(red: 0.96, green: 0.92, blue: 0.88).opacity(0.88))
                )
            }
        }

        // 2. Swaying cattail reeds on the bottom-left and bottom-right shore edges
        let leftReeds: [(CGFloat, CGFloat, CGFloat)] = [
            (12, size.height, 96),
            (24, size.height, 118),
            (36, size.height, 86),
            (48, size.height, 106),
            (62, size.height, 76)
        ]
        for (idx, blade) in leftReeds.enumerated() {
            let sway = CGFloat(sin(phaseSec * 1.35 + Double(idx) * 0.7)) * 7.5
            let start = CGPoint(x: blade.0, y: blade.1 + 4)
            let tip = CGPoint(x: blade.0 + sway + CGFloat(idx - 2) * 4.0, y: blade.1 - blade.2)
            let ctrl = CGPoint(x: blade.0 + sway * 0.4, y: blade.1 - blade.2 * 0.55)

            var stem = Path()
            stem.move(to: start)
            stem.addQuadCurve(to: tip, control: ctrl)
            context.stroke(
                stem,
                with: .color(Color(red: 0.09, green: 0.17, blue: 0.13).opacity(0.74)),
                lineWidth: 2.5
            )

            if idx == 1 || idx == 3 {
                let headStart = CGPoint(x: (ctrl.x + tip.x) * 0.5, y: (ctrl.y + tip.y) * 0.5)
                var head = Path()
                head.move(to: headStart)
                head.addLine(to: CGPoint(x: tip.x - sway * 0.15, y: tip.y + 12))
                context.stroke(
                    head,
                    with: .color(Color(red: 0.24, green: 0.16, blue: 0.10).opacity(0.84)),
                    lineWidth: 5.2
                )
            }
        }
    }

    // MARK: - Living Procedural Carbon-Fiber Spinning Rod & Animated Reel (`Remaster Mode`)

    private struct RemasterRodGeometry {
        let butt: CGPoint
        let handleTop: CGPoint
        let reelCenter: CGPoint
        let control1: CGPoint
        let control2: CGPoint
        let tip: CGPoint
        let tensionNorm: CGFloat
    }

    /// Computes the live, breathing, whipping, and physics-bent geometry of the procedural carbon-fiber rod.
    private func computeRemasterProceduralRodGeometry(
        size: CGSize,
        phaseSec: Double,
        nowMs: Int64
    ) -> RemasterRodGeometry {
        let state = coordinator.stateMachine.state
        let tension = coordinator.stateMachine.tension
        let tensionNorm = CGFloat(min(225, max(0, tension))) / 225.0
        let isPulled = coordinator.stateMachine.isPulled

        // 1. Idle & waiting breathing sway (so the rod feels held in living hands, never frozen)
        let breathX = CGFloat(sin(phaseSec * 1.45)) * 4.5 + CGFloat(cos(phaseSec * 0.8)) * 2.0
        let breathY = CGFloat(cos(phaseSec * 1.45)) * 3.2

        // 2. Whipping forward-cast impulse during cast animation (`castProgress` 0..1)
        var castWhipX: CGFloat = 0.0
        var castWhipY: CGFloat = 0.0
        if let lineGeo = coordinator.stateMachine.lineGeometry, lineGeo.isCastAnimating {
            let p = CGFloat(lineGeo.castProgress)
            // Back-swing on p < 0.25, sharp forward whip at p ≈ 0.45, elastic damping oscillation on p > 0.5
            let whipWave = sin(p * .pi * 2.2) * exp(-p * 2.4)
            castWhipX = -whipWave * 42.0
            castWhipY = abs(whipWave) * 28.0
        }

        // 3. High-frequency fight vibration at the rod tip when fish pulls or surges
        var fightJitterX: CGFloat = 0.0
        var fightJitterY: CGFloat = 0.0
        if state == .fishFight {
            let vibAmp: CGFloat = isPulled ? (2.2 + tensionNorm * 5.5) : (1.0 + tensionNorm * 2.5)
            fightJitterX = CGFloat(sin(phaseSec * 29.0)) * vibAmp
            fightJitterY = CGFloat(cos(phaseSec * 34.0)) * (vibAmp * 0.75)
        } else if state == .waitingForBite && coordinator.stateMachine.isPreHookBobbing {
            fightJitterY = CGFloat(sin(phaseSec * 18.0)) * 2.5
        }

        // Base anchor at bottom-right (`x ≈ 78%` of width, `y = size.height + 10`)
        let buttX = size.width * 0.79 + breathX * 0.35
        let buttY = size.height + 8.0
        let rodSpanH = min(size.height * 0.54, 340.0)

        let handleTop = CGPoint(
            x: buttX - 14.0 + breathX * 0.5 + castWhipX * 0.20,
            y: buttY - rodSpanH * 0.26 + breathY * 0.4
        )
        let reelCenter = CGPoint(
            x: handleTop.x - 10.0,
            y: handleTop.y + 18.0
        )

        // Dynamic bend deflection toward the water/bobber under load (`tensionNorm` 0..1)
        var targetPullSign: CGFloat = -1.0
        if let bobber = coordinator.stateMachine.bobber {
            let disp = coordinator.renderedBobberPosition ?? Point2D(x: bobber.x, y: bobber.y)
            targetPullSign = (CGFloat(disp.x) < buttX) ? -1.0 : 0.35
        }
        let bendHorizontal = targetPullSign * (24.0 + tensionNorm * 112.0) + breathX + castWhipX + fightJitterX
        let bendVerticalDrop = (tensionNorm * tensionNorm) * (rodSpanH * 0.38) + breathY + castWhipY + fightJitterY

        let tip = CGPoint(
            x: max(28.0, min(size.width - 24.0, buttX + bendHorizontal)),
            y: max(size.height * 0.26, (buttY - rodSpanH) + bendVerticalDrop)
        )

        // Cubic Bezier control points giving a realistic progressive parabolic action (`строй удилища`)
        let control1 = CGPoint(
            x: handleTop.x - 10.0 + bendHorizontal * 0.15,
            y: handleTop.y - rodSpanH * 0.28
        )
        let control2 = CGPoint(
            x: handleTop.x + bendHorizontal * 0.58,
            y: tip.y - rodSpanH * (0.14 * (1.0 - tensionNorm * 0.7))
        )

        return RemasterRodGeometry(
            butt: CGPoint(x: buttX, y: buttY),
            handleTop: handleTop,
            reelCenter: reelCenter,
            control1: control1,
            control2: control2,
            tip: tip,
            tensionNorm: tensionNorm
        )
    }

    /// Evaluates a point along the cubic Bezier rod blank (`t in 0..1`).
    private func cubicBezierPoint(
        t: CGFloat,
        p0: CGPoint,
        p1: CGPoint,
        p2: CGPoint,
        p3: CGPoint
    ) -> CGPoint {
        let u = 1.0 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        let x = uuu * p0.x + 3.0 * uu * t * p1.x + 3.0 * u * tt * p2.x + ttt * p3.x
        let y = uuu * p0.y + 3.0 * uu * t * p1.y + 3.0 * u * tt * p2.y + ttt * p3.y
        return CGPoint(x: x, y: y)
    }

    /// Draws the procedural Carbon-Fiber Spinning Rod, ceramic line guides, cork/EVA handle, and animated spinning reel.
    private func drawRemasterProceduralRodAndReel(
        in context: inout GraphicsContext,
        geometry: RemasterRodGeometry,
        phaseSec: Double
    ) {
        // 1. Under-slung Spinning Reel mounted at `geometry.reelCenter`
        let rc = geometry.reelCenter
        var stemPath = Path()
        stemPath.move(to: geometry.handleTop)
        stemPath.addLine(to: rc)
        context.stroke(stemPath, with: .color(Color(red: 0.55, green: 0.60, blue: 0.65)), lineWidth: 3.5)

        let spoolRect = CGRect(x: rc.x - 11.0, y: rc.y - 9.0, width: 22.0, height: 18.0)
        context.fill(
            Path(roundedRect: spoolRect, cornerRadius: 5),
            with: .color(Color(red: 0.16, green: 0.20, blue: 0.24))
        )
        context.stroke(
            Path(roundedRect: spoolRect, cornerRadius: 5),
            with: .color(Self.goldTextColor.opacity(0.85)),
            lineWidth: 1.5
        )

        // Rotating reel handle crank when pulling (`isPulled`)
        let crankAngle = coordinator.stateMachine.isPulled ? (phaseSec * 14.0) : 0.6
        let knobPt = CGPoint(
            x: rc.x + CGFloat(cos(crankAngle)) * 11.0,
            y: rc.y + CGFloat(sin(crankAngle)) * 11.0
        )
        var crankPath = Path()
        crankPath.move(to: rc)
        crankPath.addLine(to: knobPt)
        context.stroke(crankPath, with: .color(Color.white.opacity(0.85)), lineWidth: 2.0)
        context.fill(
            Path(ellipseIn: CGRect(x: knobPt.x - 3.0, y: knobPt.y - 3.0, width: 6.0, height: 6.0)),
            with: .color(Self.goldTextColor)
        )

        // 2. Cork & Matte-EVA Butt Handle (`butt -> handleTop`)
        var handlePath = Path()
        handlePath.move(to: geometry.butt)
        handlePath.addLine(to: geometry.handleTop)
        context.stroke(
            handlePath,
            with: .color(Color(red: 0.12, green: 0.15, blue: 0.18)),
            style: StrokeStyle(lineWidth: 11.0, lineCap: .round)
        )
        // Warm cork grip accent
        var corkPath = Path()
        corkPath.move(to: CGPoint(
            x: geometry.butt.x * 0.45 + geometry.handleTop.x * 0.55,
            y: geometry.butt.y * 0.45 + geometry.handleTop.y * 0.55
        ))
        corkPath.addLine(to: geometry.handleTop)
        context.stroke(
            corkPath,
            with: .color(Color(red: 0.68, green: 0.50, blue: 0.32)),
            style: StrokeStyle(lineWidth: 9.0, lineCap: .round)
        )

        // 3. Tapered Carbon-Fiber Rod Blank (segmented along cubic Bezier so width tapers smoothly from 6.5pt to 1.6pt)
        let segments = 18
        for i in 0..<segments {
            let t0 = CGFloat(i) / CGFloat(segments)
            let t1 = CGFloat(i + 1) / CGFloat(segments)
            let p0 = cubicBezierPoint(t: t0, p0: geometry.handleTop, p1: geometry.control1, p2: geometry.control2, p3: geometry.tip)
            let p1 = cubicBezierPoint(t: t1, p0: geometry.handleTop, p1: geometry.control1, p2: geometry.control2, p3: geometry.tip)

            var seg = Path()
            seg.move(to: p0)
            seg.addLine(to: p1)

            let width = 6.2 * (1.0 - t0 * 0.74)
            // High-visibility signal orange-gold tip on the top 15% of the blank (`quiver tip`)
            let segColor: Color
            if i >= segments - 3 {
                segColor = Color(red: 0.96, green: 0.48, blue: 0.18)
            } else if i == 2 || i == 7 || i == 12 {
                // Metallic gold thread wrap accent at guide stations
                segColor = Self.goldTextColor
            } else {
                segColor = Color(red: 0.18, green: 0.22, blue: 0.26)
            }

            context.stroke(
                seg,
                with: .color(segColor),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        }

        // 4. Ceramic Line Guides (`пропускные кольца`) along the underside of the blank
        let guidePositions: [CGFloat] = [0.16, 0.36, 0.56, 0.74, 0.88, 0.99]
        for (gIdx, gt) in guidePositions.enumerated() {
            let pt = cubicBezierPoint(t: gt, p0: geometry.handleTop, p1: geometry.control1, p2: geometry.control2, p3: geometry.tip)
            let ringRadius = max(2.0, 5.2 - CGFloat(gIdx) * 0.65)
            let ringCenter = CGPoint(x: pt.x - ringRadius * 0.85, y: pt.y + ringRadius * 0.35)
            let ringRect = CGRect(
                x: ringCenter.x - ringRadius,
                y: ringCenter.y - ringRadius,
                width: ringRadius * 2.0,
                height: ringRadius * 2.0
            )
            context.stroke(
                Path(ellipseIn: ringRect),
                with: .color(Color(red: 0.68, green: 0.74, blue: 0.78).opacity(0.85)),
                lineWidth: 1.2
            )
        }
    }

    // MARK: - Kinematic Cast Flight Trajectory + Fishing Line (`Remaster Mode`)

    private func drawRemasterFishingLineAndCastFlight(
        in context: inout GraphicsContext,
        rodTip: CGPoint,
        phaseSec: Double,
        nowMs: Int64
    ) {
        guard let bobber = coordinator.stateMachine.bobber else { return }
        let targetPos = coordinator.renderedBobberPosition ?? Point2D(x: bobber.x, y: bobber.y)
        let targetPt = CGPoint(x: CGFloat(targetPos.x), y: CGFloat(targetPos.y))

        // 1. Active Kinematic Cast Flight (`isCastAnimating && castProgress < 1.0`)
        if let lineGeo = coordinator.stateMachine.lineGeometry,
           lineGeo.isCastAnimating && lineGeo.castProgress < 1.0 {
            let p = CGFloat(max(0.02, min(1.0, lineGeo.castProgress)))
            let arcHeight: CGFloat = 145.0 * sin(p * .pi)

            let flyingFloatPt = CGPoint(
                x: rodTip.x + (targetPt.x - rodTip.x) * p,
                y: rodTip.y + (targetPt.y - rodTip.y) * p - arcHeight
            )

            // Uncoiling helical whip line from rodTip to flyingFloatPt
            var whipLine = Path()
            whipLine.move(to: rodTip)
            let steps = 16
            for s in 1...steps {
                let st = CGFloat(s) / CGFloat(steps)
                let baseX = rodTip.x + (flyingFloatPt.x - rodTip.x) * st
                let baseY = rodTip.y + (flyingFloatPt.y - rodTip.y) * st - sin(st * .pi) * 28.0
                let coilWave = sin(st * .pi * 5.0 - CGFloat(phaseSec) * 24.0) * (1.0 - p) * 9.0 * sin(st * .pi)
                whipLine.addLine(to: CGPoint(x: baseX + coilWave, y: baseY + coilWave * 0.5))
            }
            context.stroke(
                whipLine,
                with: .color(Color.white.opacity(0.82)),
                lineWidth: 1.4
            )

            // Motion-blur air streak behind flying float
            let prevP = max(0.0, p - 0.10)
            let prevArc = 145.0 * sin(prevP * .pi)
            let trailStart = CGPoint(
                x: rodTip.x + (targetPt.x - rodTip.x) * prevP,
                y: rodTip.y + (targetPt.y - rodTip.y) * prevP - prevArc
            )
            var blurTrail = Path()
            blurTrail.move(to: trailStart)
            blurTrail.addLine(to: flyingFloatPt)
            context.stroke(
                blurTrail,
                with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.0), Self.goldTextColor.opacity(0.75)]),
                    startPoint: trailStart,
                    endPoint: flyingFloatPt
                ),
                style: StrokeStyle(lineWidth: 3.0, lineCap: .round)
            )

            // Airborne lead sinker + waggler float silhouette in mid-flight
            let flightAngle = atan2(flyingFloatPt.y - trailStart.y, flyingFloatPt.x - trailStart.x)
            context.drawLayer { layer in
                layer.translateBy(x: flyingFloatPt.x, y: flyingFloatPt.y)
                layer.rotate(by: .radians(Double(flightAngle)))
                let bodyRect = CGRect(x: -10, y: -2.5, width: 16, height: 5)
                let tipRect = CGRect(x: 4, y: -1.8, width: 8, height: 3.6)
                layer.fill(Path(ellipseIn: bodyRect), with: .color(Color(red: 0.22, green: 0.28, blue: 0.24)))
                layer.fill(Path(ellipseIn: tipRect), with: .color(Color(red: 0.98, green: 0.32, blue: 0.20)))
            }

            // Target landing marker ring on water surface
            let targetRingW: CGFloat = 28.0 * (1.15 - p * 0.65)
            let targetRingH = targetRingW * 0.44
            let targetRingRect = CGRect(
                x: targetPt.x - targetRingW * 0.5,
                y: targetPt.y - targetRingH * 0.5,
                width: targetRingW,
                height: targetRingH
            )
            context.stroke(
                Path(ellipseIn: targetRingRect),
                with: .color(Self.goldTextColor.opacity(Double(1.0 - p) * 0.55)),
                style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
            )
            return
        }

        // 2. Settled / Active Fishing Line from live `rodTip` to float attachment point
        guard let curve = coordinator.currentLineCurve else { return }
        let state = coordinator.stateMachine.state
        let tension = coordinator.stateMachine.tension
        let tensionNorm = CGFloat(min(225, max(0, tension))) / 225.0

        // When waiting for bite, line Gently sags onto the water surface; during fight, it pulls taut!
        let ctrlPoint: CGPoint
        if state == .fishFight && coordinator.stateMachine.isPulled {
            let jitter = CGFloat(sin(phaseSec * 32.0)) * (1.5 + tensionNorm * 3.0)
            ctrlPoint = CGPoint(
                x: (rodTip.x + targetPt.x) * 0.5 + jitter,
                y: (rodTip.y + targetPt.y) * 0.5 + (1.0 - tensionNorm) * 16.0
            )
        } else {
            let breeze = CGFloat(sin(phaseSec * 1.8)) * 5.0
            ctrlPoint = CGPoint(
                x: (rodTip.x + targetPt.x) * 0.5 + breeze,
                y: max(rodTip.y, targetPt.y) + 28.0
            )
        }

        var linePath = Path()
        linePath.move(to: rodTip)
        linePath.addQuadCurve(to: targetPt, control: ctrlPoint)

        let alpha = Double(curve.alpha) / 255.0
        let lineColor: Color
        if state == .fishFight && tension >= 195 {
            lineColor = Color(red: 0.96, green: 0.42, blue: 0.36).opacity(min(1.0, alpha + 0.15))
        } else {
            lineColor = Color(red: 0.90, green: 0.95, blue: 0.98).opacity(min(0.92, alpha + 0.08))
        }
        context.stroke(
            linePath,
            with: .color(lineColor),
            lineWidth: state == .fishFight ? (1.4 + tensionNorm * 0.8) : 1.25
        )
    }

    // MARK: - High-Detail Procedural Waggler Float + Water Plunge Splash (`Remaster Mode`)

    private func drawRemasterRipplesAndProceduralFloat(
        in context: inout GraphicsContext,
        canvasWidth: Int,
        phaseSec: Double,
        nowMs: Int64
    ) {
        guard let bobber = coordinator.stateMachine.bobber else { return }
        if let lineGeo = coordinator.stateMachine.lineGeometry,
           lineGeo.isCastAnimating && lineGeo.castProgress <= 0.92 {
            return
        }

        // 1. Expanding water ripples (`bobber.ripples`)
        for oval in bobber.ripples {
            let rect = CGRect(
                x: CGFloat(oval.left),
                y: CGFloat(oval.top),
                width: CGFloat(max(2.0, oval.width)),
                height: CGFloat(max(2.0, oval.height))
            )
            let alphaInt = BobberState.rippleAlpha(ovalWidth: oval.width, canvasWidth: canvasWidth)
            let alpha = Double(alphaInt) / 255.0
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.88, green: 0.95, blue: 0.99).opacity(min(1.0, alpha * 1.1))),
                lineWidth: 1.8
            )
        }

        let displayPos = coordinator.renderedBobberPosition ?? Point2D(x: bobber.x, y: bobber.y)
        let baseCenter = CGPoint(x: CGFloat(displayPos.x), y: CGFloat(displayPos.y))

        // 2. Post-Cast Water Plunge Splash Crown (first 550ms after float lands on water)
        let elapsedSinceCastMs = nowMs - coordinator.stateMachine.castBeginTimeMs
        // Cast flight takes ~15 frames (~450ms), so touchdown splash occurs around 350..950ms after castBeginTimeMs
        let splashElapsedMs = elapsedSinceCastMs - 380
        var landingDipY: CGFloat = 0.0
        if splashElapsedMs >= 0 && splashElapsedMs < 620 {
            let st = Double(splashElapsedMs) / 620.0
            landingDipY = CGFloat(sin(st * .pi * 2.0) * exp(-st * 3.2)) * 9.0

            // Expanding foam shockwave ring
            let ringW = CGFloat(14.0 + st * 58.0)
            let ringH = ringW * 0.42
            let ringRect = CGRect(
                x: baseCenter.x - ringW * 0.5,
                y: baseCenter.y - ringH * 0.5,
                width: ringW,
                height: ringH
            )
            context.stroke(
                Path(ellipseIn: ringRect),
                with: .color(Color.white.opacity((1.0 - st) * 0.65)),
                lineWidth: CGFloat(2.8 * (1.0 - st * 0.6))
            )

            // Crown of 10 airborne water droplets on cast plop
            for d in 0..<10 {
                let angle = -Double.pi * (0.10 + 0.80 * (Double(d) / 9.0))
                let speed = 18.0 + Double((d * 7) % 14)
                let dist = st * speed
                let lift = -sin(st * .pi) * (14.0 + Double(d % 3) * 6.0)
                let dx = baseCenter.x + CGFloat(cos(angle) * dist)
                let dy = baseCenter.y + CGFloat(sin(angle) * dist * 0.4 + lift)
                let r = CGFloat(max(1.5, (1.0 - st) * 3.6))
                context.fill(
                    Path(ellipseIn: CGRect(x: dx - r * 0.5, y: dy - r * 0.5, width: r, height: r * 1.3)),
                    with: .color(Color.white.opacity((1.0 - st) * 0.85))
                )
            }
        }

        // 3. Procedural Waggler Float with Wave Buoyancy & Tilt
        let isFighting = (coordinator.stateMachine.state == .fishFight)
        let isPreHook = coordinator.stateMachine.isPreHookBobbing
        let isPulled = coordinator.stateMachine.isPulled

        let waveBobY: CGFloat
        let tiltRadians: Double
        if isFighting && !isPreHook {
            waveBobY = isPulled ? 4.0 : 6.0
            tiltRadians = (isPulled ? -0.34 : 0.30) + sin(phaseSec * 7.5) * 0.08
        } else if isPreHook {
            waveBobY = CGFloat(sin(phaseSec * 11.0)) * 3.5 + 2.0
            tiltRadians = sin(phaseSec * 9.0) * 0.16
        } else {
            waveBobY = CGFloat(sin(phaseSec * 2.6)) * 2.2 + landingDipY
            tiltRadians = sin(phaseSec * 1.9) * 0.065
        }

        let waterlineCenter = CGPoint(x: baseCenter.x, y: baseCenter.y + waveBobY)

        // Subtle waterline meniscus ring around the float stem
        let meniscusRect = CGRect(x: waterlineCenter.x - 7.0, y: waterlineCenter.y - 2.2, width: 14.0, height: 4.4)
        context.stroke(
            Path(ellipseIn: meniscusRect),
            with: .color(Color.white.opacity(0.38)),
            lineWidth: 1.1
        )

        context.drawLayer { layer in
            layer.translateBy(x: waterlineCenter.x, y: waterlineCenter.y)
            layer.rotate(by: .radians(tiltRadians))

            if bobber.isBiteTexture && !isPreHook {
                // Submerged fight state: underwater balsa body shadow + glowing red/amber antenna tip piercing the surface
                let submergedBody = CGRect(x: -3.5, y: 2.0, width: 7.0, height: 18.0)
                layer.fill(
                    Path(ellipseIn: submergedBody),
                    with: .color(Color(red: 0.08, green: 0.16, blue: 0.18).opacity(0.55))
                )

                // Luminous halo around the submerged antenna tip
                let pulse = 0.70 + 0.30 * sin(phaseSec * 6.5)
                let glowRect = CGRect(x: -10.0, y: -12.0, width: 20.0, height: 20.0)
                layer.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(Color(red: 0.98, green: 0.32, blue: 0.20).opacity(0.36 * pulse))
                )

                // Yellow lower band + glowing crimson tip
                let bandYellow = CGRect(x: -1.6, y: -4.0, width: 3.2, height: 6.0)
                let bandRed = CGRect(x: -2.0, y: -11.0, width: 4.0, height: 8.0)
                layer.fill(Path(roundedRect: bandYellow, cornerRadius: 1.5), with: .color(Color(red: 0.98, green: 0.86, blue: 0.24)))
                layer.fill(Path(roundedRect: bandRed, cornerRadius: 2.0), with: .color(Color(red: 1.0, green: 0.26, blue: 0.16)))
            } else {
                // Full Waggler Float standing on the water:
                // (a) Underwater refracted stem + lead weight reflection below y = 0
                var underStem = Path()
                underStem.move(to: CGPoint(x: 0, y: 0))
                underStem.addLine(to: CGPoint(x: 0, y: 22))
                layer.stroke(
                    underStem,
                    with: .color(Color(red: 0.12, green: 0.22, blue: 0.26).opacity(0.45)),
                    lineWidth: 1.5
                )
                let underwaterBulb = CGRect(x: -4.2, y: -2.0, width: 8.4, height: 16.0)
                layer.fill(
                    Path(ellipseIn: underwaterBulb),
                    with: .color(Color(red: 0.12, green: 0.24, blue: 0.22).opacity(0.62))
                )

                // (b) Above-water tapered balsa body (`y: -14 .. +2`)
                let balsaRect = CGRect(x: -4.5, y: -14.0, width: 9.0, height: 16.0)
                layer.fill(
                    Path(ellipseIn: balsaRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.20, green: 0.30, blue: 0.24),
                            Color(red: 0.10, green: 0.16, blue: 0.14)
                        ]),
                        startPoint: CGPoint(x: -4.5, y: -6.0),
                        endPoint: CGPoint(x: 4.5, y: -6.0)
                    )
                )
                layer.stroke(
                    Path(ellipseIn: balsaRect),
                    with: .color(Self.goldTextColor.opacity(0.75)),
                    lineWidth: 1.0
                )

                // (c) Thin carbon stem (`y: -26 .. -13`)
                var upperStem = Path()
                upperStem.move(to: CGPoint(x: 0, y: -13.0))
                upperStem.addLine(to: CGPoint(x: 0, y: -26.0))
                layer.stroke(upperStem, with: .color(Color.white.opacity(0.85)), lineWidth: 1.6)

                // (d) 3-band high-visibility fluorescent antenna (`y: -38 .. -20`)
                let limeBand = CGRect(x: -1.4, y: -25.0, width: 2.8, height: 6.0)
                let whiteBand = CGRect(x: -1.5, y: -30.0, width: 3.0, height: 5.0)
                let redTip = CGRect(x: -2.1, y: -38.0, width: 4.2, height: 8.5)

                // Soft luminous halo around the antenna tip
                let pulse = 0.65 + 0.35 * sin(phaseSec * 5.0)
                let haloRect = CGRect(x: -9.0, y: -41.0, width: 18.0, height: 18.0)
                layer.fill(
                    Path(ellipseIn: haloRect),
                    with: .color(Color(red: 1.0, green: 0.34, blue: 0.20).opacity(0.32 * pulse))
                )

                layer.fill(Path(roundedRect: limeBand, cornerRadius: 1.2), with: .color(Color(red: 0.72, green: 0.98, blue: 0.28)))
                layer.fill(Path(roundedRect: whiteBand, cornerRadius: 1.2), with: .color(Color.white))
                layer.fill(Path(roundedRect: redTip, cornerRadius: 2.1), with: .color(Color(red: 1.0, green: 0.25, blue: 0.16)))
            }
        }
    }

    /// Twinkling night stars above horizon and glowing shoreline fireflies in Remaster mode.
    private func drawRemasterSkyStarsAndFireflies(
        in context: inout GraphicsContext,
        size: CGSize,
        phaseSec: Double
    ) {
        let hour = coordinator.gameClock.hour
        let isNight = (hour >= 21 || hour < 5)
        let weather = coordinator.currentResolvedWeather

        if isNight && weather != .rain && weather != .thunderstorm {
            let horizonY = size.height * 0.22
            for i in 0..<20 {
                let seed = Double(i * 97 + 13)
                let x = (sin(seed * 1.37) * 0.5 + 0.5) * size.width
                let y = (cos(seed * 2.11) * 0.5 + 0.5) * horizonY
                let twinkle = 0.30 + 0.55 * (0.5 + 0.5 * sin(phaseSec * (1.5 + Double(i % 5) * 0.35) + seed))
                let starRadius = (i % 4 == 0) ? 1.5 : 1.0
                let rect = CGRect(x: x - starRadius, y: y - starRadius, width: starRadius * 2, height: starRadius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(twinkle * 0.75)))
            }
        }

        if weather == .starryCalm || (isNight && weather != .rain) {
            for i in 0..<8 {
                let seed = Double(i * 53 + 7)
                let baseX = (sin(seed * 0.91 + phaseSec * 0.15) * 0.42 + 0.5) * size.width
                let baseY = (0.34 + 0.48 * (cos(seed * 1.43 + phaseSec * 0.12) * 0.5 + 0.5)) * size.height
                let pulse = 0.20 + 0.65 * max(0.0, sin(phaseSec * 2.2 + seed))
                let glowRect = CGRect(x: baseX - 4.0, y: baseY - 4.0, width: 8.0, height: 8.0)
                let coreRect = CGRect(x: baseX - 1.5, y: baseY - 1.5, width: 3.0, height: 3.0)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(Color(red: 0.85, green: 0.95, blue: 0.55).opacity(pulse * 0.22))
                )
                context.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(Color(red: 0.95, green: 0.98, blue: 0.70).opacity(pulse * 0.75))
                )
            }
        }
    }

    /// Animated underwater fish shadow beneath the bobber during `fishFight` (and approaching shadow right before bite).
    private func drawRemasterUnderwaterFishSilhouette(
        in context: inout GraphicsContext,
        size: CGSize,
        phaseSec: Double
    ) {
        guard let bobber = coordinator.stateMachine.bobber else { return }
        if let lineGeo = coordinator.stateMachine.lineGeometry,
           lineGeo.isCastAnimating && lineGeo.castProgress <= 0.95 {
            return
        }

        let state = coordinator.stateMachine.state
        let isFighting = (state == .fishFight)
        let isCirclingBeforeBite = (state == .waitingForBite)

        guard isFighting || isCirclingBeforeBite else { return }

        let displayPos = coordinator.renderedBobberPosition ?? Point2D(x: bobber.x, y: bobber.y)
        let weightGrams = max(120, coordinator.stateMachine.activeFishWeightGrams)
        let weightScale: CGFloat = isFighting
            ? min(2.05, max(0.78, CGFloat(log10(Double(weightGrams) + 10.0) * 0.45)))
            : 0.80

        let bodyLen: CGFloat = 34.0 * weightScale
        let bodyHalfWidth: CGFloat = 8.5 * weightScale

        let isPulled = coordinator.stateMachine.isPulled
        let isExhausted = coordinator.stateMachine.fishController?.isExhausted ?? false
        let tensionNorm = CGFloat(min(225, max(0, coordinator.stateMachine.tension))) / 225.0

        let wagFreq = isFighting ? (isExhausted ? 4.2 : (8.5 + Double(tensionNorm) * 10.0)) : 3.0
        let tailSway = CGFloat(sin(phaseSec * wagFreq)) * (isFighting ? (5.0 + tensionNorm * 4.0) : 2.8) * weightScale

        let centerOffsetX: CGFloat
        let centerOffsetY: CGFloat
        let headingAngle: Double

        if isFighting {
            let driftAngle = sin(phaseSec * 2.0) * 0.32
            headingAngle = (isPulled ? (Double.pi * 0.5) : (-Double.pi * 0.5)) + driftAngle
            centerOffsetX = CGFloat(sin(phaseSec * 2.8)) * 6.5
            centerOffsetY = isPulled ? -10.0 : 12.0
        } else {
            let orbitAngle = phaseSec * 0.75
            centerOffsetX = CGFloat(cos(orbitAngle)) * 20.0
            centerOffsetY = CGFloat(sin(orbitAngle)) * 10.0 + 10.0
            headingAngle = orbitAngle + .pi * 0.5
        }

        let fishCenter = CGPoint(
            x: CGFloat(displayPos.x) + centerOffsetX,
            y: CGFloat(displayPos.y) + centerOffsetY
        )

        context.drawLayer { layer in
            layer.translateBy(x: fishCenter.x, y: fishCenter.y)
            layer.rotate(by: .radians(headingAngle))

            let headTip = CGPoint(x: bodyLen * 0.55, y: 0)
            let tailBase = CGPoint(x: -bodyLen * 0.38, y: tailSway * 0.35)
            let tailTop = CGPoint(x: -bodyLen * 0.72, y: -bodyHalfWidth * 1.15 + tailSway)
            let tailNotch = CGPoint(x: -bodyLen * 0.58, y: tailSway * 0.85)
            let tailBottom = CGPoint(x: -bodyLen * 0.72, y: bodyHalfWidth * 1.15 + tailSway)

            var fishPath = Path()
            fishPath.move(to: headTip)
            fishPath.addQuadCurve(
                to: tailBase,
                control: CGPoint(x: bodyLen * 0.08, y: -bodyHalfWidth * 1.35)
            )
            fishPath.addLine(to: tailTop)
            fishPath.addLine(to: tailNotch)
            fishPath.addLine(to: tailBottom)
            fishPath.addLine(to: tailBase)
            fishPath.addQuadCurve(
                to: headTip,
                control: CGPoint(x: bodyLen * 0.08, y: bodyHalfWidth * 1.35)
            )
            fishPath.closeSubpath()

            var finsPath = Path()
            finsPath.move(to: CGPoint(x: bodyLen * 0.12, y: -bodyHalfWidth * 0.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.08, y: -bodyHalfWidth * 1.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.05, y: -bodyHalfWidth * 0.45))
            finsPath.closeSubpath()

            finsPath.move(to: CGPoint(x: bodyLen * 0.12, y: bodyHalfWidth * 0.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.08, y: bodyHalfWidth * 1.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.05, y: bodyHalfWidth * 0.45))
            finsPath.closeSubpath()

            let shadowOpacity = isFighting ? 0.42 : 0.20
            layer.fill(fishPath, with: .color(Color(red: 0.03, green: 0.07, blue: 0.10).opacity(shadowOpacity)))
            layer.fill(finsPath, with: .color(Color(red: 0.03, green: 0.07, blue: 0.10).opacity(shadowOpacity * 0.85)))
        }
    }

    /// Dynamic water splash droplets and white foam bursts around the bobber during active fish fight.
    private func drawRemasterWaterSplashes(
        in context: inout GraphicsContext,
        phaseSec: Double
    ) {
        guard coordinator.stateMachine.state == .fishFight,
              let bobber = coordinator.stateMachine.bobber else { return }

        let displayPos = coordinator.renderedBobberPosition ?? Point2D(x: bobber.x, y: bobber.y)
        let tension = coordinator.stateMachine.tension
        let isPulled = coordinator.stateMachine.isPulled
        let isPreHook = coordinator.stateMachine.isPreHookBobbing

        let intensity: Double
        if isPreHook {
            intensity = 0.30
        } else if isPulled || tension >= 100 {
            intensity = min(0.95, 0.40 + Double(tension) / 260.0)
        } else {
            intensity = 0.22
        }

        let center = CGPoint(x: CGFloat(displayPos.x), y: CGFloat(displayPos.y) + 2.0)

        let foamPulse = CGFloat(0.68 + 0.32 * sin(phaseSec * 8.5))
        let foamW = CGFloat(16.0 + intensity * 20.0) * foamPulse
        let foamH = foamW * 0.45
        let foamRect = CGRect(
            x: center.x - foamW * 0.5,
            y: center.y - foamH * 0.5,
            width: foamW,
            height: foamH
        )
        context.stroke(
            Path(ellipseIn: foamRect),
            with: .color(Color.white.opacity(0.34 * intensity)),
            lineWidth: 1.8
        )

        let dropletCount = isPreHook ? 4 : 8
        for i in 0..<dropletCount {
            let seed = Double(i * 41 + 11)
            let cycle = (phaseSec * (2.4 + Double(i % 3) * 0.5) + seed).truncatingRemainder(dividingBy: 1.0)
            let angle = -Double.pi * (0.14 + 0.72 * (Double(i) / Double(max(1, dropletCount - 1))))
            let maxRadius = (12.0 + intensity * 24.0) * (0.7 + 0.3 * sin(seed))
            let dist = cycle * maxRadius
            let arcLift = -sin(cycle * .pi) * (9.0 + intensity * 15.0)

            let dropX = center.x + CGFloat(cos(angle) * dist)
            let dropY = center.y + CGFloat(sin(angle) * dist * 0.45 + arcLift)
            let dropAlpha = (1.0 - cycle) * 0.76 * intensity
            let dropSize = CGFloat(max(1.8, (1.0 - cycle * 0.5) * 3.8))

            let dropRect = CGRect(
                x: dropX - dropSize * 0.5,
                y: dropY - dropSize * 0.5,
                width: dropSize,
                height: dropSize * 1.2
            )
            context.fill(
                Path(ellipseIn: dropRect),
                with: .color(Color(red: 0.92, green: 0.96, blue: 0.99).opacity(dropAlpha))
            )
        }
    }

    /// Procedural weather particles (falling rain + water micro-ripples, or drifting morning mist layers).
    private func drawRemasterWeatherParticles(
        in context: inout GraphicsContext,
        size: CGSize,
        phaseSec: Double
    ) {
        let weather = coordinator.currentResolvedWeather
        switch weather {
        case .rain, .thunderstorm:
            let dropCount = (weather == .thunderstorm) ? 42 : 24
            let streakLen: CGFloat = (weather == .thunderstorm) ? 16.0 : 12.0
            for i in 0..<dropCount {
                let seed = Double(i * 61 + 29)
                let speed = (weather == .thunderstorm) ? 1.75 : 1.30
                let progress = (phaseSec * speed + seed * 0.17).truncatingRemainder(dividingBy: 1.0)
                let startX = ((sin(seed * 2.13) * 0.5 + 0.5) * (size.width + 80.0)) - 40.0
                let x = startX + CGFloat(progress) * 32.0
                let y = CGFloat(progress) * size.height

                var streak = Path()
                streak.move(to: CGPoint(x: x, y: y))
                streak.addLine(to: CGPoint(x: x + 4.0, y: y + streakLen))
                context.stroke(
                    streak,
                    with: .color(Color(red: 0.82, green: 0.89, blue: 0.95).opacity(0.28)),
                    lineWidth: 1.0
                )

                if y > size.height * 0.25 && progress > 0.72 {
                    let ringT = (progress - 0.72) / 0.28
                    let rw = CGFloat(4.0 + ringT * 12.0)
                    let rh = rw * 0.42
                    let rRect = CGRect(x: x - rw * 0.5, y: y - rh * 0.5, width: rw, height: rh)
                    context.stroke(
                        Path(ellipseIn: rRect),
                        with: .color(Color.white.opacity((1.0 - ringT) * 0.22)),
                        lineWidth: 0.9
                    )
                }
            }

        case .morningMist:
            for band in 0..<3 {
                let seed = Double(band * 37 + 5)
                let yCenter = size.height * CGFloat(0.21 + Double(band) * 0.10)
                let xShift = CGFloat(sin(phaseSec * 0.18 + seed)) * (size.width * 0.16)
                let mistRect = CGRect(
                    x: -size.width * 0.15 + xShift,
                    y: yCenter - 20.0,
                    width: size.width * 1.30,
                    height: 40.0
                )
                context.fill(
                    Path(ellipseIn: mistRect),
                    with: .color(Color(red: 0.88, green: 0.92, blue: 0.94).opacity(0.09))
                )
            }

        default:
            break
        }
    }

    // MARK: - Classic v1.81 Canvas Renderers (Preserved 100% when Remaster is OFF)

    private func drawClassicRipplesAndBobber(in context: inout GraphicsContext, canvasWidth: Int) {
        guard let bobber = coordinator.stateMachine.bobber else { return }
        if let lineGeo = coordinator.stateMachine.lineGeometry,
           lineGeo.isCastAnimating && lineGeo.castProgress <= 0.95 {
            return
        }

        for oval in bobber.ripples {
            let rect = CGRect(
                x: CGFloat(oval.left),
                y: CGFloat(oval.top),
                width: CGFloat(max(2.0, oval.width)),
                height: CGFloat(max(2.0, oval.height))
            )
            let path = Path(ellipseIn: rect)
            let alphaInt = BobberState.rippleAlpha(ovalWidth: oval.width, canvasWidth: canvasWidth)
            let alpha = Double(alphaInt) / 255.0
            context.stroke(path, with: .color(Color.white.opacity(alpha)), lineWidth: 2.0)
        }

        let displayPos = coordinator.renderedBobberPosition ?? Point2D(x: bobber.x, y: bobber.y)
        let bobberDrawableName = bobber.isBiteTexture ? "bobber_hide" : "bobber"

        let bobberRect: CGRect
        if bobber.isBiteTexture {
            bobberRect = CGRect(
                x: CGFloat(displayPos.x) - 6.0,
                y: CGFloat(displayPos.y) - 6.0,
                width: 12.0,
                height: 12.0
            )
        } else {
            bobberRect = CGRect(
                x: CGFloat(displayPos.x) - 8.0,
                y: CGFloat(displayPos.y) - 26.0,
                width: 16.0,
                height: 52.0
            )
        }

        if let bobberImg = OriginalGameAssetsLoader.image(named: bobberDrawableName) {
            let resolved = context.resolve(bobberImg)
            context.draw(resolved, in: bobberRect)
        } else if bobber.isBiteTexture {
            context.fill(Path(ellipseIn: bobberRect), with: .color(.red))
        } else {
            let topHalf = CGRect(x: bobberRect.minX + 2.0, y: bobberRect.minY, width: 12.0, height: 22.0)
            let bottomHalf = CGRect(x: bobberRect.minX + 2.0, y: bobberRect.minY + 22.0, width: 12.0, height: 22.0)
            context.fill(Path(ellipseIn: topHalf), with: .color(.red))
            context.fill(Path(ellipseIn: bottomHalf), with: .color(.white))
        }
    }

    private func drawClassicRodSprite(in context: inout GraphicsContext, rod: RodSpriteState) {
        let clampedFrame = min(15, max(0, rod.frameIndex))
        let rodFrameName = "fishing_rod_\(clampedFrame)"
        let rodWidthCG = CGFloat(rod.width)
        let rodHeightCG = CGFloat(rod.height)
        let rodRect = CGRect(
            x: CGFloat(rod.originX),
            y: CGFloat(rod.originY),
            width: rodWidthCG,
            height: rodHeightCG
        )
        if let rodImg = OriginalGameAssetsLoader.image(named: rodFrameName) {
            let resolvedRod = context.resolve(rodImg)
            context.draw(resolvedRod, in: rodRect)
        } else {
            let buttPoint = CGPoint(
                x: CGFloat(rod.originX) + rodWidthCG * 0.85,
                y: CGFloat(rod.originY) + rodHeightCG
            )
            let tipPt2D = FishingLineGeometry.rodTipPoint(for: rod)
            let tipPoint = CGPoint(x: CGFloat(tipPt2D.x), y: CGFloat(tipPt2D.y))
            let rodCtrl = CGPoint(
                x: (buttPoint.x + tipPoint.x) * 0.55,
                y: (buttPoint.y + tipPoint.y) * 0.45
            )
            var rodPath = Path()
            rodPath.move(to: buttPoint)
            rodPath.addQuadCurve(to: tipPoint, control: rodCtrl)
            context.stroke(rodPath, with: .color(Color(red: 0.48, green: 0.30, blue: 0.14)), lineWidth: 5.0)
        }
    }

    private func drawClassicFishingLine(in context: inout GraphicsContext, rod: RodSpriteState) {
        guard let curve = coordinator.currentLineCurve else { return }
        let startTip = FishingLineGeometry.rodTipPoint(for: rod)
        var linePath = Path()
        linePath.move(to: CGPoint(x: CGFloat(startTip.x), y: CGFloat(startTip.y)))
        linePath.addQuadCurve(
            to: CGPoint(x: CGFloat(curve.end.x), y: CGFloat(curve.end.y)),
            control: CGPoint(x: CGFloat(curve.control.x), y: CGFloat(curve.control.y))
        )
        let alpha = Double(curve.alpha) / 255.0
        context.stroke(
            linePath,
            with: .color(.white.opacity(alpha)),
            lineWidth: CGFloat(curve.strokeWidth)
        )
    }
}

// MARK: - 0. Remaster Smooth 24-Hour Atmospheric Sky & Water Lighting Overlay (Subtle & Natural)

private struct RemasterAtmosphericGradientOverlay: View {
    let hour: Int
    let minute: Int
    let weather: RemasterWeatherKind

    private var fractionalHour: Double {
        Double(hour) + Double(minute) / 60.0
    }

    private var atmosphereColors: [Color] {
        let h = fractionalHour
        if h >= 5.0 && h < 8.0 {
            return [
                Color(red: 0.20, green: 0.16, blue: 0.30).opacity(0.24),
                Color(red: 0.88, green: 0.56, blue: 0.36).opacity(0.20),
                Color(red: 0.92, green: 0.74, blue: 0.46).opacity(0.10),
                Color(red: 0.06, green: 0.14, blue: 0.20).opacity(0.14)
            ]
        } else if h >= 8.0 && h < 17.5 {
            if weather == .rain || weather == .thunderstorm {
                return [
                    Color(red: 0.12, green: 0.18, blue: 0.24).opacity(0.34),
                    Color(red: 0.16, green: 0.22, blue: 0.28).opacity(0.22),
                    Color(red: 0.05, green: 0.10, blue: 0.15).opacity(0.26)
                ]
            }
            return [
                Color(red: 0.18, green: 0.45, blue: 0.68).opacity(0.08),
                Color(red: 0.96, green: 0.92, blue: 0.80).opacity(0.06),
                Color(red: 0.04, green: 0.16, blue: 0.24).opacity(0.12)
            ]
        } else if h >= 17.5 && h < 21.5 {
            return [
                Color(red: 0.24, green: 0.12, blue: 0.28).opacity(0.28),
                Color(red: 0.88, green: 0.42, blue: 0.24).opacity(0.24),
                Color(red: 0.90, green: 0.64, blue: 0.32).opacity(0.14),
                Color(red: 0.06, green: 0.10, blue: 0.18).opacity(0.22)
            ]
        } else {
            return [
                Color(red: 0.02, green: 0.05, blue: 0.12).opacity(0.46),
                Color(red: 0.04, green: 0.10, blue: 0.20).opacity(0.34),
                Color(red: 0.02, green: 0.06, blue: 0.14).opacity(0.40)
            ]
        }
    }

    var body: some View {
        LinearGradient(
            colors: atmosphereColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - 1. Top Experience Progress Bar (`pbExp` + `pbExpText`, `res/Ak.xml` + Calm Remaster Styling)

private struct PondExperienceTopBarView: View {
    @ObservedObject var coordinator: FishingAppCoordinator

    private var prevThreshold: Int {
        let rank = coordinator.profile.category
        let thresholds = BalanceTables.playerRankExpThresholds
        if rank > 0 && (rank - 1) < thresholds.count {
            return thresholds[rank - 1]
        }
        return 0
    }

    private var nextThreshold: Int {
        let exp = coordinator.profile.experience
        let rank = coordinator.profile.category
        let thresholds = BalanceTables.playerRankExpThresholds
        if rank >= 0 && rank < thresholds.count {
            return thresholds[rank]
        }
        return max(exp, 70_000_000)
    }

    private var progressFraction: Double {
        let exp = coordinator.profile.experience
        let span = max(1, nextThreshold - prevThreshold)
        return min(1.0, max(0.0, Double(exp - prevThreshold) / Double(span)))
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(FishingPondView.matteSlateSurface)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: coordinator.isRemasterModeEnabled
                                    ? [
                                        FishingPondView.sageAccentColor.opacity(0.75),
                                        FishingPondView.sageAccentColor
                                    ]
                                    : [
                                        Color(red: 0.18, green: 0.55, blue: 0.22),
                                        Color(red: 0.32, green: 0.78, blue: 0.30)
                                    ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            HStack(spacing: 6) {
                Text("Разряд \(coordinator.profile.category)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FishingPondView.goldTextColor)
                Text("•")
                    .foregroundStyle(.white.opacity(0.45))
                Text("\(coordinator.profile.experience) / \(nextThreshold) XP")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.92))
                Text("•")
                    .foregroundStyle(.white.opacity(0.45))
                Text("\(coordinator.profile.balance) руб")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(FishingPondView.goldTextColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
        }
        .frame(height: coordinator.isRemasterModeEnabled ? 20 : 16)
    }
}

// MARK: - 2. Static 2D Pond Background (`pond_<id>_big.png` + Night Tint)

private struct Static2DPondBackgroundView: View {
    let pondIndex: Int
    let isDayLight: Bool
    var isRemasterMode: Bool = false

    var body: some View {
        let pondNumber = max(1, min(15, pondIndex + 1))
        ZStack {
            if let pondImg = OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)_big")
                ?? OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)") {
                pondImg
                    .resizable()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.62, blue: 0.85),
                        Color(red: 0.14, green: 0.36, blue: 0.56),
                        Color(red: 0.05, green: 0.16, blue: 0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            if !isDayLight {
                Color(red: 0.0, green: 0.02, blue: isRemasterMode ? 0.14 : (30.0 / 255.0))
                    .opacity(isRemasterMode ? 0.48 : (120.0 / 255.0))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 3. Single-Row Non-Clipping Top Bar (`PondTopOverlayBarView`)

private struct PondTopOverlayBarView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onOpenQuickTackle: () -> Void

    private var localizedCurrentPondTitle: String {
        guard let pond = coordinator.currentPondItem else { return "Кедровый остров" }
        return coordinator.localeManager.pondName(for: pond).capitalized
    }

    var body: some View {
        if coordinator.isRemasterModeEnabled {
            remasterSingleRowTopBar
        } else {
            classicTopBar
        }
    }

    private var remasterSingleRowTopBar: some View {
        HStack(spacing: 8) {
            Button {
                if coordinator.stateMachine.state == .fishFight {
                    return
                } else if coordinator.stateMachine.state != .idle {
                    coordinator.resetCastToIdle()
                } else {
                    coordinator.selectedTab = .baseHub
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: coordinator.stateMachine.state == .idle ? "chevron.left" : "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .bold))
                    Text(coordinator.stateMachine.state == .idle ? "База" : "Сброс")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.95))
                .frame(height: 34)
                .padding(.horizontal, 12)
                .background(FishingPondView.matteSlateSurface.opacity(0.84), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                .opacity(coordinator.stateMachine.state == .fishFight ? 0.45 : 1.0)
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: true)

            Button {
                if coordinator.stateMachine.state == .idle {
                    onOpenQuickTackle()
                }
            } label: {
                HStack(spacing: 5) {
                    Text(localizedCurrentPondTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(FishingPondView.goldTextColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .padding(.horizontal, 10)
                .background(FishingPondView.matteSlateSurface.opacity(0.84), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.5).onEnded { _ in
                    coordinator.isDebugOverlayEnabled.toggle()
                }
            )

            HStack(spacing: 6) {
                Button {
                    coordinator.cycleRemasterWeather()
                } label: {
                    Image(systemName: coordinator.currentResolvedWeather.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FishingPondView.goldTextColor)
                        .frame(width: 34, height: 34)
                        .background(FishingPondView.matteSlateSurface.opacity(0.84), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        coordinator.isSonarRadarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(coordinator.isSonarRadarVisible ? FishingPondView.sageAccentColor : .white.opacity(0.75))
                        .frame(width: 34, height: 34)
                        .background(FishingPondView.matteSlateSurface.opacity(0.84), in: Circle())
                        .overlay(
                            Circle().stroke(
                                coordinator.isSonarRadarVisible
                                    ? FishingPondView.sageAccentColor.opacity(0.65)
                                    : Color.white.opacity(0.14),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    guard coordinator.stateMachine.state == .idle else { return }
                    coordinator.selectedTab = .progress
                } label: {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(FishingPondView.matteSlateSurface.opacity(0.84), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.45)
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: true, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(FishingPondView.matteSlateSurface.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private var classicTopBar: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                if coordinator.stateMachine.state == .fishFight {
                    return
                } else if coordinator.stateMachine.state != .idle {
                    coordinator.resetCastToIdle()
                } else {
                    coordinator.selectedTab = .baseHub
                }
            } label: {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "pond_out",
                    fallbackSystemName: "arrow.uturn.backward.square.fill",
                    width: 40,
                    height: 40
                )
                .opacity(coordinator.stateMachine.state == .fishFight ? 0.45 : 1.0)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(localizedCurrentPondTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FishingPondView.goldTextColor)
                .shadow(color: .black, radius: 2, x: 0, y: 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.45), in: Capsule())
                .onLongPressGesture(minimumDuration: 1.5) {
                    coordinator.isDebugOverlayEnabled.toggle()
                }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    coordinator.selectedTab = .online
                } label: {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "tchat",
                        fallbackSystemName: "bubble.left.and.bubble.right.fill",
                        width: 52,
                        height: 30
                    )
                }
                .buttonStyle(.plain)

                Button {
                    guard coordinator.stateMachine.state == .idle else { return }
                    coordinator.selectedTab = .progress
                } label: {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "task_btn",
                        fallbackSystemName: "checklist",
                        width: 38,
                        height: 38
                    )
                    .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.45)
                }
                .buttonStyle(.plain)

                Button {
                    coordinator.selectedTab = .online
                } label: {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "tours_btn",
                        fallbackSystemName: "trophy.circle.fill",
                        width: 38,
                        height: 38
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }
}

// MARK: - 3A. Remaster Compact Sonar Widget & Live Fight Telemetry Banner

private struct RemasterPondFloatingHUDView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onOpenBaitChooser: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if coordinator.stateMachine.state == .fishFight {
                RemasterLiveFightTelemetryBanner(coordinator: coordinator)
            } else if coordinator.isSonarRadarVisible {
                RemasterCompactSonarWidgetView(
                    coordinator: coordinator,
                    onOpenBaitChooser: onOpenBaitChooser
                )
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct RemasterLiveFightTelemetryBanner: View {
    @ObservedObject var coordinator: FishingAppCoordinator

    private var distanceMeters: Double {
        guard let bobber = coordinator.stateMachine.bobber else { return 0.0 }
        let viewH = Float(max(1, coordinator.stateMachine.viewHeight))
        let remainingPx = max(0.0, viewH - (bobber.y + Float(bobber.bitmapHeight / 2)))
        return Double(remainingPx / viewH) * 25.0
    }

    private var fishStatusTextAndColor: (String, Color) {
        let tension = coordinator.stateMachine.tension
        let isExhausted = coordinator.stateMachine.fishController?.isExhausted ?? false
        if coordinator.stateMachine.isPreHookBobbing {
            return ("Поклёвка • зажмите катушку для подсечки", FishingPondView.goldTextColor)
        } else if tension >= 195 {
            return ("Опасная нагрузка • отпустите катушку!", Color(red: 0.94, green: 0.40, blue: 0.36))
        } else if isExhausted {
            return ("Рыба утомлена • плавно подтягивайте к берегу", FishingPondView.sageAccentColor)
        } else if coordinator.stateMachine.isPulled {
            return ("Вываживание • контролируйте натяжение", .white.opacity(0.95))
        } else {
            return ("Катушка отпущена • натяжение снижается", FishingPondView.goldTextColor)
        }
    }

    var body: some View {
        let status = fishStatusTextAndColor
        HStack(spacing: 8) {
            Circle()
                .fill(status.1)
                .frame(width: 7, height: 7)
            Text(status.0)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(status.1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(String(format: "%.1f м", distanceMeters))
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(FishingPondView.matteSlateSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct RemasterCompactSonarWidgetView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onOpenBaitChooser: () -> Void

    var body: some View {
        let forecast = coordinator.currentPondBiteForecast
        let baitName = coordinator.assembledTackle.userBait?.bait.name.capitalized ?? "Нет наживки"

        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 148, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    ForEach(0..<min(4, max(1, forecast.count)), id: \.self) { idx in
                        Image(systemName: "fish.fill")
                            .font(.system(size: idx == 0 ? 13 : 10))
                            .foregroundStyle(
                                idx == 0
                                    ? FishingPondView.goldTextColor.opacity(0.90)
                                    : Color.white.opacity(0.60)
                            )
                            .offset(y: CGFloat((idx % 2 == 0) ? -6 : 5))
                    }
                }
                .frame(width: 148, height: 48)

                Text("Глуб. \(coordinator.currentCastDepthFactor)/10")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(FishingPondView.sageAccentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
            }

            if forecast.isEmpty {
                Button(action: onOpenBaitChooser) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Нет клёва на «\(baitName)»")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FishingPondView.goldTextColor)
                        Text("Нажмите, чтобы сменить")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(width: 148, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(forecast.prefix(4)) { item in
                        HStack(spacing: 4) {
                            if item.isQuestOrTaskTarget {
                                Circle()
                                    .fill(FishingPondView.goldTextColor)
                                    .frame(width: 5, height: 5)
                            }
                            Text(item.fishName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(item.isQuestOrTaskTarget ? FishingPondView.goldTextColor : .white.opacity(0.92))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(item.probabilityPercent)%")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(FishingPondView.sageAccentColor)
                        }
                    }
                }
                .frame(width: 148)
            }
        }
        .padding(9)
        .background(FishingPondView.matteSlateSurface.opacity(0.84), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - 3B. Separated Developer Debug Toolbar (Hidden by Default for Normal Players)

private struct PondDeveloperDebugToolbarView: View {
    @ObservedObject var coordinator: FishingAppCoordinator

    var body: some View {
        HStack(spacing: 8) {
            Text("DEV")
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.black)

            if coordinator.stateMachine.state == .waitingForBite {
                Button {
                    coordinator.fastForwardToScheduledBite()
                } label: {
                    Text("⚡ Клёв сейчас")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }

            Button {
                for _ in 0..<60 {
                    coordinator.stepGameClockMinute()
                }
            } label: {
                Text("+1ч")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            if !coordinator.assembledTackle.isComplete {
                Button {
                    coordinator.equipBestOwnedTackle()
                } label: {
                    Text("Собрать снасть")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(FishingPondView.goldTextColor, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                coordinator.isDebugOverlayEnabled = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.75))
    }
}

// MARK: - 4A. Remaster Bottom Control Deck (With Dedicated Separate "Вымотать" Tile!)

private struct RemasterPondBottomDeckView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onPresentBaitChooser: () -> Void
    let onPresentQuickTackle: () -> Void
    @State private var didCastDuringCurrentPress: Bool = false

    private var tensionFraction: Double {
        let tension = coordinator.stateMachine.tension
        return Double(min(225, max(0, tension))) / 225.0
    }

    private var equippedBaitId: Int {
        coordinator.assembledTackle.userBait?.bait.id ?? 0
    }

    private var equippedBaitAmount: Int {
        coordinator.assembledTackle.userBait?.amount ?? 0
    }

    private var rodStrength: Int {
        coordinator.assembledTackle.userRod?.strength ?? 0
    }

    private var coilStrength: Int {
        coordinator.assembledTackle.userCoil?.strength ?? 0
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                // 1. Tension header & calm smooth progress bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("НАГРУЗКА СНАСТИ \(coordinator.stateMachine.tension) / 225")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.88))
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: coordinator.dayNightLighting.isDayLight ? "sun.max.fill" : "moon.stars.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(FishingPondView.goldTextColor)
                            Text(String(format: "%02d:%02d", coordinator.gameClock.hour, coordinator.gameClock.minute))
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(FishingPondView.goldTextColor)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.45))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            FishingPondView.sageAccentColor,
                                            FishingPondView.goldTextColor,
                                            Color(red: 0.90, green: 0.38, blue: 0.32)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, geo.size.width * tensionFraction))
                                .animation(.linear(duration: 0.05), value: coordinator.stateMachine.tension)
                        }
                    }
                    .frame(height: 8)
                }

                // 2. Four distinct Matte-Slate Tiles: Наживка, Снасть, Садок (clean, no X!), and dedicated Вымотать / Сброс
                HStack(spacing: 6) {
                    // Tile 1: Bait
                    Button(action: onPresentBaitChooser) {
                        VStack(spacing: 3) {
                            let baitDrawable = equippedBaitId > 0 ? "bait_\(equippedBaitId)" : "bait_empty"
                            OriginalSpriteOrFallbackIcon(
                                drawableName: baitDrawable,
                                fallbackSystemName: "circle.hexagongrid.fill",
                                width: 26,
                                height: 26
                            )
                            Text("\(equippedBaitAmount) шт.")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.55)
                    }
                    .buttonStyle(.plain)

                    // Tile 2: Tackle & Durability
                    Button(action: onPresentQuickTackle) {
                        VStack(spacing: 4) {
                            Image(systemName: "figure.fishing")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(FishingPondView.goldTextColor)
                            Text("У\(rodStrength)%•К\(coilStrength)%")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.55)
                    }
                    .buttonStyle(.plain)

                    // Tile 3: Fishnet (clean — never has a delete/close X on top of it!)
                    Button {
                        guard coordinator.stateMachine.state == .idle else { return }
                        coordinator.selectedTab = .fishnet
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "basket.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FishingPondView.sageAccentColor)
                            Text("\(coordinator.fishnetEntries.count)/\(PlayerStateRepository.maxFishnetCapacity)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundStyle(FishingPondView.goldTextColor)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.55)
                    }
                    .buttonStyle(.plain)

                    // Tile 4: Dedicated "Вымотать" (Reel-In / Cancel Cast) when cast, or "Продать" when idle
                    if coordinator.stateMachine.state != .idle {
                        Button {
                            coordinator.resetCastToIdle()
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.down.circle.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.94, green: 0.45, blue: 0.38))
                                Text("Вымотать")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(red: 0.94, green: 0.45, blue: 0.38).opacity(0.45), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            if coordinator.fishnetEntries.isEmpty {
                                onPresentQuickTackle()
                            } else {
                                coordinator.sellAllFishInFishnet()
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: coordinator.fishnetEntries.isEmpty ? "slider.horizontal.3" : "rublesign.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(coordinator.fishnetEntries.isEmpty ? FishingPondView.goldTextColor : FishingPondView.sageAccentColor)
                                Text(coordinator.fishnetEntries.isEmpty ? "Оснастка" : "Продать")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 3. Modern Brushed-Metal Circular Reel Wheel (`96x96 pt`)
            RemasterMetallicReelWheelView(
                tensionFraction: tensionFraction,
                isPulled: coordinator.stateMachine.isPulled,
                isFighting: coordinator.stateMachine.state == .fishFight,
                isIdle: coordinator.stateMachine.state == .idle
            )
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if coordinator.stateMachine.state == .idle {
                            guard !didCastDuringCurrentPress else { return }
                            didCastDuringCurrentPress = true
                            let targetX = coordinator.stateMachine.lastCastMetadata?.bobberX
                                ?? (Float(coordinator.stateMachine.viewWidth) * 0.5)
                            let targetY = coordinator.stateMachine.lastCastMetadata?.bobberY
                                ?? (Float(coordinator.stateMachine.viewHeight) * 0.55)
                            coordinator.castAt(x: targetX, y: targetY)
                        } else if !didCastDuringCurrentPress {
                            coordinator.setReelPulled(true)
                        }
                    }
                    .onEnded { _ in
                        didCastDuringCurrentPress = false
                        if coordinator.stateMachine.state != .idle {
                            coordinator.setReelPulled(false)
                        }
                    }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FishingPondView.matteSlateSurface.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
        }
    }
}

/// Custom-drawn Brushed-Metal Circular Reel Wheel with Radial Tension Arc (`0..225`).
private struct RemasterMetallicReelWheelView: View {
    let tensionFraction: Double
    let isPulled: Bool
    let isFighting: Bool
    let isIdle: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPulled)) { timeline in
            let spinDegrees = isPulled
                ? (timeline.date.timeIntervalSinceReferenceDate * 360.0).truncatingRemainder(dividingBy: 360.0)
                : 0.0

            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 92, height: 92)

                Circle()
                    .trim(from: 0.12, to: 0.12 + 0.76 * CGFloat(max(0.02, tensionFraction)))
                    .stroke(
                        AngularGradient(
                            colors: [
                                FishingPondView.sageAccentColor,
                                FishingPondView.goldTextColor,
                                Color(red: 0.92, green: 0.36, blue: 0.30)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 92, height: 92)
                    .animation(.linear(duration: 0.05), value: tensionFraction)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.24, green: 0.29, blue: 0.33),
                                Color(red: 0.13, green: 0.17, blue: 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle()
                            .stroke(
                                isPulled ? FishingPondView.goldTextColor.opacity(0.75) : Color.white.opacity(0.20),
                                lineWidth: 1.5
                            )
                    )

                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color(red: 0.32, green: 0.37, blue: 0.42),
                                Color(red: 0.18, green: 0.22, blue: 0.26),
                                Color(red: 0.36, green: 0.41, blue: 0.46),
                                Color(red: 0.16, green: 0.20, blue: 0.24),
                                Color(red: 0.32, green: 0.37, blue: 0.42)
                            ],
                            center: .center
                        )
                    )
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(spinDegrees))

                Circle()
                    .fill(FishingPondView.matteSlateSurface)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle().stroke(FishingPondView.goldTextColor.opacity(0.6), lineWidth: 1)
                    )

                if isIdle {
                    Text("ЗАБРОС")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(FishingPondView.goldTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FishingPondView.matteSlateSurface.opacity(0.92), in: Capsule())
                        .offset(y: 38)
                } else if isFighting {
                    Text(isPulled ? "ТЯНЕМ" : "КАТУШКА")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isPulled ? .black : .white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isPulled ? FishingPondView.goldTextColor : FishingPondView.matteSlateSurface.opacity(0.92),
                            in: Capsule()
                        )
                        .offset(y: 38)
                }
            }
            .frame(width: 96, height: 96)
        }
    }
}

// MARK: - 4B. Classic v1.81 Bottom Controls Panel (`res/Ak.xml` — preserved 100% when Remaster is OFF)

private struct ClassicPondBottomControlsPanelView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onPresentBaitChooser: () -> Void
    @State private var didCastDuringCurrentPress: Bool = false

    private var tensionFraction: Double {
        let tension = coordinator.stateMachine.tension
        return Double(min(225, max(0, tension))) / 225.0
    }

    private var tensionColor: Color {
        let tension = coordinator.stateMachine.tension
        if tension >= 200 { return .red }
        if tension >= 145 { return .orange }
        return .green
    }

    private var equippedBaitId: Int {
        coordinator.assembledTackle.userBait?.bait.id ?? 0
    }

    private var equippedBaitAmount: Int {
        coordinator.assembledTackle.userBait?.amount ?? 0
    }

    private var rodStrength: Int {
        coordinator.assembledTackle.userRod?.strength ?? 0
    }

    private var coilStrength: Int {
        coordinator.assembledTackle.userCoil?.strength ?? 0
    }

    private var isBitingOrPulling: Bool {
        coordinator.stateMachine.isPulled
            || (coordinator.stateMachine.state == .fishFight && coordinator.stateMachine.isPreHookBobbing)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(spacing: 4) {
                tensionProgressBar
                upperControlsRow
                lowerControlsRow
            }
            reelPullButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45))
    }

    private var tensionProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.65))
                RoundedRectangle(cornerRadius: 4)
                    .fill(tensionColor)
                    .frame(width: geo.size.width * tensionFraction)
                    .animation(.linear(duration: 0.05), value: coordinator.stateMachine.tension)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            }
        }
        .frame(height: 12)
    }

    private var upperControlsRow: some View {
        HStack(spacing: 8) {
            currentBaitButton
            gameTimePlaque
            durabilityReadout
        }
    }

    private var currentBaitButton: some View {
        Button(action: onPresentBaitChooser) {
            ZStack(alignment: .bottomTrailing) {
                if let btnBg = OriginalGameAssetsLoader.image(named: "btn_background") {
                    btnBg.resizable().frame(width: 44, height: 44)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
                let baitDrawable = equippedBaitId > 0 ? "bait_\(equippedBaitId)" : "bait_empty"
                OriginalSpriteOrFallbackIcon(
                    drawableName: baitDrawable,
                    fallbackSystemName: "circle.hexagongrid.fill",
                    width: 34,
                    height: 34
                )
                .frame(width: 44, height: 44)

                if equippedBaitAmount > 0 {
                    Text("\(equippedBaitAmount)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                }
            }
            .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
    }

    private var gameTimePlaque: some View {
        ZStack {
            if let timeBg = OriginalGameAssetsLoader.image(named: "time_background") {
                timeBg
                    .resizable()
                    .frame(height: 40)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.65))
                    .frame(height: 40)
            }
            Text(String(format: "%02d:%02d", coordinator.gameClock.hour, coordinator.gameClock.minute))
                .font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundStyle(FishingPondView.goldTextColor)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var durabilityReadout: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("У - \(rodStrength)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
            Text("К - \(coilStrength)")
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .shadow(color: .black, radius: 1, x: 0, y: 1)
    }

    private var lowerControlsRow: some View {
        HStack(spacing: 8) {
            Button {
                guard coordinator.stateMachine.state == .idle else { return }
                coordinator.selectedTab = .fishnet
            } label: {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "fishpond_small",
                    fallbackSystemName: "basket.fill",
                    width: 44,
                    height: 38
                )
                .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.45)
            }
            .buttonStyle(.plain)

            Text("\(coordinator.fishnetEntries.count)")
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 28, minHeight: 36)

            Button {
                guard coordinator.stateMachine.state == .idle else { return }
                coordinator.selectedTab = .inventory
            } label: {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "backpack_small",
                    fallbackSystemName: "backpack.fill",
                    width: 44,
                    height: 38
                )
                .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.45)
            }
            .buttonStyle(.plain)

            Button {
                coordinator.resetCastToIdle()
            } label: {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "drop_me",
                    fallbackSystemName: "xmark.circle.fill",
                    width: 56,
                    height: 40
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var reelPullButton: some View {
        ZStack {
            OriginalSpriteOrFallbackIcon(
                drawableName: "push_me",
                fallbackSystemName: "arrow.triangle.2.circlepath.circle.fill",
                width: 96,
                height: 110
            )
            .opacity(isBitingOrPulling ? 0.0 : 1.0)

            OriginalSpriteOrFallbackIcon(
                drawableName: "push_me_on",
                fallbackSystemName: "arrow.triangle.2.circlepath.circle.fill",
                width: 96,
                height: 110
            )
            .opacity(isBitingOrPulling ? 1.0 : 0.0)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if coordinator.stateMachine.state == .idle {
                        guard !didCastDuringCurrentPress else { return }
                        didCastDuringCurrentPress = true
                        let targetX = coordinator.stateMachine.lastCastMetadata?.bobberX
                            ?? (Float(coordinator.stateMachine.viewWidth) * 0.5)
                        let targetY = coordinator.stateMachine.lastCastMetadata?.bobberY
                            ?? (Float(coordinator.stateMachine.viewHeight) * 0.55)
                        coordinator.castAt(x: targetX, y: targetY)
                    } else if !didCastDuringCurrentPress {
                        coordinator.setReelPulled(true)
                    }
                }
                .onEnded { _ in
                    didCastDuringCurrentPress = false
                    if coordinator.stateMachine.state != .idle {
                        coordinator.setReelPulled(false)
                    }
                }
        )
    }
}

// MARK: - Helper View for Rendering Bundled APK PNG Sprites with Graceful SF Symbol Fallback

public struct OriginalSpriteOrFallbackIcon: View {
    public let drawableName: String
    public let fallbackSystemName: String
    public let width: CGFloat
    public let height: CGFloat

    public init(
        drawableName: String,
        fallbackSystemName: String,
        width: CGFloat,
        height: CGFloat
    ) {
        self.drawableName = drawableName
        self.fallbackSystemName = fallbackSystemName
        self.width = width
        self.height = height
    }

    public var body: some View {
        if let img = OriginalGameAssetsLoader.image(named: drawableName) {
            img
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
        } else {
            Image(systemName: fallbackSystemName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.65, height: height * 0.65)
                .frame(width: width, height: height)
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 5. Remaster Quick Full-Tackle & Pond Switcher Sheet (`Быстрая оснастка и смена водоёма на берегу`)

private struct RemasterQuickTackleAndPondSheet: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FishingPondView.matteSlateSurface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            coordinator.equipBestOwnedTackle()
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 16, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Авто-сборка лучшей снасти")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Экипирует самые крепкие удилище, катушку, леску, крючок и подходящую наживку")
                                        .font(.system(size: 11))
                                        .opacity(0.85)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(.black)
                            .padding(12)
                            .background(FishingPondView.goldTextColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Быстрый переход на другой водоём")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(FishingPondView.goldTextColor)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(coordinator.availablePonds, id: \.id) { pond in
                                        let unlocked = coordinator.profile.category >= pond.requiredRank
                                            && (!pond.requiresCoupon || coordinator.activeCoupon != nil)
                                        let isCurrent = coordinator.selectedPondIndex == pond.id
                                        Button {
                                            coordinator.selectPond(pondIndex: pond.id)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("#\(pond.id + 1) \(coordinator.localeManager.pondName(for: pond).capitalized)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(isCurrent ? .black : (unlocked ? .white : .white.opacity(0.45)))
                                                Text("Разряд \(pond.requiredRank)\(pond.requiresCoupon ? " • Купон" : "")")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(isCurrent ? .black.opacity(0.8) : FishingPondView.sageAccentColor)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(
                                                isCurrent
                                                    ? FishingPondView.goldTextColor
                                                    : FishingPondView.matteCardSurface.opacity(unlocked ? 1.0 : 0.45),
                                                in: RoundedRectangle(cornerRadius: 8)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(!unlocked)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))

                        quickSectionHeader("Удилище (\(coordinator.ownedRods.count))")
                        ForEach(coordinator.ownedRods) { item in
                            quickEquipRow(
                                icon: "fishing_rods",
                                title: item.rod.name,
                                subtitle: "Мощность: \(item.rod.weight) кг • Прочность: \(item.strength)%",
                                isEquipped: coordinator.tackleSlots.fishingRodId == item.id
                            ) {
                                coordinator.equipRod(rowId: item.id)
                            }
                        }

                        quickSectionHeader("Катушка (\(coordinator.ownedCoils.count))")
                        ForEach(coordinator.ownedCoils) { item in
                            quickEquipRow(
                                icon: "coil",
                                title: item.coil.name,
                                subtitle: "Подшипников: \(item.coil.bearingCount) • Прочность: \(item.strength)%",
                                isEquipped: coordinator.tackleSlots.coilId == item.id
                            ) {
                                coordinator.equipCoil(rowId: item.id)
                            }
                        }

                        quickSectionHeader("Леска (\(coordinator.ownedLines.count))")
                        ForEach(coordinator.ownedLines) { item in
                            quickEquipRow(
                                icon: "fishing_line",
                                title: item.line.name,
                                subtitle: "Тест: \(item.line.weight) кг • Длина: \(item.length) м",
                                isEquipped: coordinator.tackleSlots.fishingLineId == item.id
                            ) {
                                coordinator.equipLine(rowId: item.id)
                            }
                        }

                        quickSectionHeader("Крючок (\(coordinator.ownedHooks.count))")
                        ForEach(coordinator.ownedHooks) { item in
                            quickEquipRow(
                                icon: "hooks",
                                title: item.hook.name,
                                subtitle: "Остаток: \(item.amount) шт.",
                                isEquipped: coordinator.tackleSlots.hookId == item.id
                            ) {
                                coordinator.equipHook(rowId: item.id)
                            }
                        }

                        quickSectionHeader("Наживка (\(coordinator.ownedBaits.count))")
                        ForEach(coordinator.ownedBaits) { item in
                            let worksHere = coordinator.stateMachine.pondData.activeBaitIndices0Based.contains(item.bait.id - 1)
                            quickEquipRow(
                                icon: "bait_\(item.bait.id)",
                                title: item.bait.name.capitalized + (worksHere ? " • Клюёт здесь" : ""),
                                subtitle: "Остаток: \(item.amount) шт.",
                                isEquipped: coordinator.tackleSlots.baitId == item.id
                            ) {
                                coordinator.equipBait(rowId: item.id)
                            }
                        }
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Быстрая оснастка")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Готово") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("В магазин") {
                        dismiss()
                        coordinator.selectedTab = .shop
                    }
                }
            }
        }
    }

    private func quickSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(FishingPondView.goldTextColor)
            .padding(.top, 4)
    }

    private func quickEquipRow(
        icon: String,
        title: String,
        subtitle: String,
        isEquipped: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: icon,
                    fallbackSystemName: "circle.fill",
                    width: 36,
                    height: 36
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: isEquipped ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isEquipped ? FishingPondView.sageAccentColor : .white.opacity(0.35))
            }
            .padding(10)
            .background(
                FishingPondView.matteCardSurface,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isEquipped ? FishingPondView.sageAccentColor.opacity(0.65) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Bait Chooser Sheet (`bait_chooser_dialog_list_item`, `res/RY.xml`)

private struct BaitQuickChooserSheet: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FishingPondView.matteSlateSurface.ignoresSafeArea()
                sheetContent
            }
            .navigationTitle("Выбор наживки")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var sheetContent: some View {
        if coordinator.ownedBaits.isEmpty {
            VStack(spacing: 12) {
                Text("В рюкзаке нет наживок")
                    .font(.headline)
                    .foregroundStyle(.white)
                Button("Открыть магазин") {
                    dismiss()
                    coordinator.selectedTab = .shop
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(coordinator.ownedBaits) { item in
                        let worksOnPond = coordinator.stateMachine.pondData.activeBaitIndices0Based.contains(item.bait.id - 1)
                        BaitQuickChooserRowView(
                            item: item,
                            worksOnCurrentPond: worksOnPond,
                            isEquipped: coordinator.tackleSlots.baitId == item.id
                        ) {
                            coordinator.equipBait(rowId: item.id)
                            dismiss()
                        }
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct BaitQuickChooserRowView: View {
    let item: UserBaitItem
    var worksOnCurrentPond: Bool = false
    let isEquipped: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "bait_\(item.bait.id)",
                    fallbackSystemName: "circle.fill",
                    width: 40,
                    height: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.bait.name.capitalized)
                            .font(.headline)
                            .foregroundStyle(FishingPondView.goldTextColor)
                        if worksOnCurrentPond {
                            Text("Клюёт здесь")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FishingPondView.sageAccentColor, in: Capsule())
                        }
                    }
                    Text("Остаток: \(item.amount) шт.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(FishingPondView.sageAccentColor)
                }
            }
            .padding(10)
            .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isEquipped ? FishingPondView.sageAccentColor.opacity(0.6) : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
