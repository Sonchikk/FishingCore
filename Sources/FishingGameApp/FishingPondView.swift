import SwiftUI
import FishingCore
import FishingDatabase

/// Authentic fishing pond screen (`GameActivity` + `GameView` + `F0.n` `WaterMetalRenderer`),
/// supporting two distinct, non-overlapping visual modes controlled from Settings (`coordinator.isRemasterModeEnabled`):
/// 1. **Classic v1.81 Mode (`false`)**: 1:1 reconstruction of the 2013 Android layout (`res/Ak.xml`) with classic PNG buttons;
/// 2. **Remaster Mode (`true`)**: calm Matte-Slate (`#182026`) & Warm-Brass (`#E2B872`) outdoor design inspired by *Russian Fishing 4*,
///    with enhanced multi-wave water shimmer, soft horizon mist, swaying foreground shoreline reeds, underwater fish silhouette,
///    water splashes, single-line non-clipping top bar, collapsible Echolot/Bite Radar, 3-tile matte control deck, and a brushed-metal circular reel wheel.
public struct FishingPondView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var isBaitChooserPresented: Bool = false
    @State private var isQuickTackleSheetPresented: Bool = false

    public static let goldTextColor = Color(red: 226.0 / 255.0, green: 184.0 / 255.0, blue: 114.0 / 255.0) // #E2B872 warm brass
    public static let sageAccentColor = Color(red: 78.0 / 255.0, green: 159.0 / 255.0, blue: 110.0 / 255.0) // #4E9F6E muted sage
    public static let matteSlateSurface = Color(red: 24.0 / 255.0, green: 32.0 / 255.0, blue: 38.0 / 255.0) // #182026 matte slate
    public static let matteCardSurface = Color(red: 32.0 / 255.0, green: 42.0 / 255.0, blue: 50.0 / 255.0) // #202A32 card fill

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
            Canvas { context, size in
                let activeRod = resolvedRodSprite(for: size)
                if coordinator.isRemasterModeEnabled {
                    drawRemasterWaterDepthAndHorizonSoftener(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterSkyStarsAndFireflies(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterUnderwaterFishSilhouette(in: &context, size: size, phaseSec: phaseSec)
                }
                drawFishingLine(in: &context, rod: activeRod)
                drawRipplesAndBobber(in: &context, canvasWidth: max(1, Int(size.width)), phaseSec: phaseSec)
                if coordinator.isRemasterModeEnabled {
                    drawRemasterWaterSplashes(in: &context, phaseSec: phaseSec)
                    drawRemasterWeatherParticles(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterForegroundShorelineReeds(in: &context, size: size, phaseSec: phaseSec)
                }
                drawRodSprite(in: &context, rod: activeRod)
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

    // MARK: - Modular Canvas Drawing Helpers (`GameView.draw(Canvas)` + Remaster Scenic Water & Effects)

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

    /// Softens the 25% horizon seam of the original 2013 texture with natural shoreline mist,
    /// subtle animated wave ribbons, and bottom depth vignetting.
    private func drawRemasterWaterDepthAndHorizonSoftener(
        in context: inout GraphicsContext,
        size: CGSize,
        phaseSec: Double
    ) {
        let horizonY = size.height * 0.245
        // 1. Soft atmospheric mist band along the distant shoreline (`y ≈ 0.20..0.30`)
        let mistBand = CGRect(x: 0, y: horizonY - 26, width: size.width, height: 56)
        context.fill(
            Path(mistBand),
            with: .linearGradient(
                Gradient(colors: [
                    Color.white.opacity(0.0),
                    Color(red: 0.86, green: 0.90, blue: 0.92).opacity(coordinator.dayNightLighting.isDayLight ? 0.18 : 0.08),
                    Color.white.opacity(0.0)
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: mistBand.minY),
                endPoint: CGPoint(x: size.width * 0.5, y: mistBand.maxY)
            )
        )

        // 2. Gentle horizontal water wave shimmer lines across the lake surface
        for row in 0..<11 {
            let normY = Double(row) / 10.0
            let y = horizonY + 14.0 + CGFloat(pow(normY, 1.35)) * (size.height * 0.70)
            let waveShift = CGFloat(sin(phaseSec * (0.7 + Double(row % 3) * 0.25) + Double(row) * 1.4)) * 24.0
            let segWidth = size.width * CGFloat(0.28 + 0.18 * (Double(row % 4) / 3.0))
            let centerX = size.width * CGFloat(0.22 + 0.56 * (0.5 + 0.5 * sin(Double(row * 31 + 7)))) + waveShift
            let rect = CGRect(x: centerX - segWidth * 0.5, y: y, width: segWidth, height: 1.4)
            let alpha = (1.0 - normY * 0.55) * (coordinator.dayNightLighting.isDayLight ? 0.11 : 0.06)
            context.fill(
                Path(roundedRect: rect, cornerRadius: 1),
                with: .color(Color(red: 0.88, green: 0.94, blue: 0.98).opacity(alpha))
            )
        }

        // 3. Subtle dark-water depth vignette near the bottom shore
        let bottomVignette = CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28)
        context.fill(
            Path(bottomVignette),
            with: .linearGradient(
                Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color(red: 0.04, green: 0.08, blue: 0.11).opacity(0.42)
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: bottomVignette.minY),
                endPoint: CGPoint(x: size.width * 0.5, y: bottomVignette.maxY)
            )
        )
    }

    /// Swaying foreground shoreline reeds (`камыши у берега`) in the bottom-left corner for depth and framing.
    private func drawRemasterForegroundShorelineReeds(
        in context: inout GraphicsContext,
        size: CGSize,
        phaseSec: Double
    ) {
        let baseOrigins: [(CGFloat, CGFloat, CGFloat)] = [
            (14, size.height, 92),
            (26, size.height, 114),
            (38, size.height, 84),
            (52, size.height, 102),
            (66, size.height, 74)
        ]
        for (idx, blade) in baseOrigins.enumerated() {
            let sway = CGFloat(sin(phaseSec * 1.35 + Double(idx) * 0.7)) * 7.0
            let start = CGPoint(x: blade.0, y: blade.1 + 4)
            let tip = CGPoint(x: blade.0 + sway + CGFloat(idx - 2) * 4.0, y: blade.1 - blade.2)
            let ctrl = CGPoint(x: blade.0 + sway * 0.4, y: blade.1 - blade.2 * 0.55)

            var stem = Path()
            stem.move(to: start)
            stem.addQuadCurve(to: tip, control: ctrl)
            context.stroke(
                stem,
                with: .color(Color(red: 0.09, green: 0.16, blue: 0.13).opacity(0.68)),
                lineWidth: 2.4
            )

            // Cattail reed head on tall stems
            if idx == 1 || idx == 3 {
                let headStart = CGPoint(
                    x: (ctrl.x + tip.x) * 0.5,
                    y: (ctrl.y + tip.y) * 0.5
                )
                var head = Path()
                head.move(to: headStart)
                head.addLine(to: CGPoint(x: tip.x - sway * 0.15, y: tip.y + 12))
                context.stroke(
                    head,
                    with: .color(Color(red: 0.22, green: 0.15, blue: 0.10).opacity(0.78)),
                    lineWidth: 5.0
                )
            }
        }
    }

    /// Twinkling night stars above horizon and glowing shoreline fireflies / sunbeam motes in Remaster mode.
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

    private func drawRipplesAndBobber(in context: inout GraphicsContext, canvasWidth: Int, phaseSec: Double) {
        guard let bobber = coordinator.stateMachine.bobber else { return }
        if let lineGeo = coordinator.stateMachine.lineGeometry,
           lineGeo.isCastAnimating && lineGeo.castProgress <= 0.95 {
            return
        }

        let isRemaster = coordinator.isRemasterModeEnabled
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
            let rippleColor: Color = isRemaster
                ? Color(red: 0.88, green: 0.94, blue: 0.98).opacity(min(1.0, alpha * 1.05))
                : Color.white.opacity(alpha)
            context.stroke(path, with: .color(rippleColor), lineWidth: isRemaster ? 2.0 : 2.0)
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

        if isRemaster {
            let isNight = !coordinator.dayNightLighting.isDayLight
            if bobber.isBiteTexture || isNight {
                let pulse = 0.65 + 0.35 * sin(phaseSec * 5.5)
                let glowRadius: CGFloat = bobber.isBiteTexture ? 12.0 : 9.0
                let glowCenterY = bobber.isBiteTexture ? CGFloat(displayPos.y) : (bobberRect.minY + 8.0)
                let glowRect = CGRect(
                    x: CGFloat(displayPos.x) - glowRadius,
                    y: glowCenterY - glowRadius,
                    width: glowRadius * 2.0,
                    height: glowRadius * 2.0
                )
                let glowColor = bobber.isBiteTexture
                    ? Color(red: 0.96, green: 0.32, blue: 0.22).opacity(0.38 * pulse)
                    : Color(red: 0.45, green: 0.92, blue: 0.65).opacity(0.30 * pulse)
                context.fill(Path(ellipseIn: glowRect), with: .color(glowColor))
            }
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

    private func drawRodSprite(in context: inout GraphicsContext, rod: RodSpriteState) {
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

    private func drawFishingLine(in context: inout GraphicsContext, rod: RodSpriteState) {
        guard let curve = coordinator.currentLineCurve else { return }
        let startTip = FishingLineGeometry.rodTipPoint(for: rod)
        var linePath = Path()
        linePath.move(to: CGPoint(x: CGFloat(startTip.x), y: CGFloat(startTip.y)))
        linePath.addQuadCurve(
            to: CGPoint(x: CGFloat(curve.end.x), y: CGFloat(curve.end.y)),
            control: CGPoint(x: CGFloat(curve.control.x), y: CGFloat(curve.control.y))
        )
        let alpha = Double(curve.alpha) / 255.0
        if coordinator.isRemasterModeEnabled && coordinator.stateMachine.state == .fishFight {
            let tension = coordinator.stateMachine.tension
            let lineColor: Color = tension >= 195
                ? Color(red: 0.96, green: 0.45, blue: 0.38).opacity(min(1.0, alpha + 0.12))
                : Color(red: 0.90, green: 0.94, blue: 0.98).opacity(min(1.0, alpha + 0.08))
            context.stroke(
                linePath,
                with: .color(lineColor),
                lineWidth: CGFloat(curve.strokeWidth) + 0.25
            )
        } else {
            context.stroke(
                linePath,
                with: .color(.white.opacity(alpha)),
                lineWidth: CGFloat(curve.strokeWidth)
            )
        }
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
            // 1. Back / Reset button (fixed compact pill)
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

            // 2. Centered single-line Pond Name Pill (never wraps onto 2 lines!)
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

            // 3. Three fixed 34x34 circular icon buttons (Weather, Sonar, Quests/Tasks)
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

/// Compact top-left Echolot widget matching the approved mockup (`Карась 65%`, `Карп 40%`, depth radar display).
private struct RemasterCompactSonarWidgetView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onOpenBaitChooser: () -> Void

    var body: some View {
        let forecast = coordinator.currentPondBiteForecast
        let baitName = coordinator.assembledTackle.userBait?.bait.name.capitalized ?? "Нет наживки"

        VStack(alignment: .leading, spacing: 6) {
            // Mini sonar screen header
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

// MARK: - 4A. Remaster Bottom Control Deck (Matte-Slate 3-Tile Layout + Brushed-Metal Reel Wheel)

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
        HStack(alignment: .center, spacing: 12) {
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

                // 2. Three equal-height Matte-Slate Tiles (Bait, Tackle/Durability, Fishnet & Reset)
                HStack(spacing: 8) {
                    // Tile 1: Bait
                    Button(action: onPresentBaitChooser) {
                        VStack(spacing: 4) {
                            let baitDrawable = equippedBaitId > 0 ? "bait_\(equippedBaitId)" : "bait_empty"
                            OriginalSpriteOrFallbackIcon(
                                drawableName: baitDrawable,
                                fallbackSystemName: "circle.hexagongrid.fill",
                                width: 30,
                                height: 30
                            )
                            Text("\(equippedBaitAmount)")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
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
                        VStack(spacing: 5) {
                            Image(systemName: "figure.fishing")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(FishingPondView.goldTextColor)
                            Text("У \(rodStrength)% • К \(coilStrength)%")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.55)
                    }
                    .buttonStyle(.plain)

                    // Tile 3: Fishnet + Quick Reset badge in top-right corner
                    ZStack(alignment: .topTrailing) {
                        Button {
                            guard coordinator.stateMachine.state == .idle else { return }
                            coordinator.selectedTab = .fishnet
                        } label: {
                            VStack(spacing: 3) {
                                Text("Садок")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(1)
                                Text("\(coordinator.fishnetEntries.count)/\(PlayerStateRepository.maxFishnetCapacity)")
                                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundStyle(FishingPondView.goldTextColor)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 62)
                            .background(FishingPondView.matteCardSurface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        if coordinator.stateMachine.state != .idle {
                            Button {
                                coordinator.resetCastToIdle()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.white.opacity(0.22), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                        } else if !coordinator.fishnetEntries.isEmpty {
                            Button {
                                coordinator.sellAllFishInFishnet()
                            } label: {
                                Image(systemName: "rublesign")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(width: 20, height: 20)
                                    .background(FishingPondView.sageAccentColor, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                        }
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
                // Outer track arc
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 92, height: 92)

                // Active tension gauge arc
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

                // Brushed dark-titanium outer housing ring
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

                // Conic brushed-steel rotor disc (rotates smoothly while pulling)
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

                // Center hub cap & label
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
