import SwiftUI
import FishingCore
import FishingDatabase

/// Authentic fishing pond screen (`GameActivity` + `GameView` + `F0.n` `WaterMetalRenderer`),
/// supporting both:
/// 1. **Classic v1.81 Mode (`coordinator.isRemasterModeEnabled == false`)**: 1:1 reconstruction of `res/layout/game_activity.xml` (`res/Ak.xml`);
/// 2. **Remaster Mode (`coordinator.isRemasterModeEnabled == true`)**: dynamic 24-hour sky & water lighting gradients (dawn, day, golden sunset, starry night),
///    procedural weather effects (rain + water micro-ripples, drifting morning mist, sunbeams, night fireflies),
///    animated underwater fish silhouette + fight splash particles, built-in free Echolot/Bite Radar, live quest/task tracker,
///    quick full-tackle switcher on the shore, and a radial tension tachometer arc around the reel wheel.
public struct FishingPondView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var isBaitChooserPresented: Bool = false
    @State private var isQuickTackleSheetPresented: Bool = false

    public static let goldTextColor = Color(red: 235.0 / 255.0, green: 185.0 / 255.0, blue: 104.0 / 255.0) // #EBB968

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
                PondBottomControlsPanelView(
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
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.09, blue: 0.14),
                    Color(red: 0.08, green: 0.14, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
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

                VStack(spacing: 6) {
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
                    drawRemasterSkyStarsAndFireflies(in: &context, size: size, phaseSec: phaseSec)
                    drawRemasterUnderwaterFishSilhouette(in: &context, size: size, phaseSec: phaseSec)
                }
                drawFishingLine(in: &context, rod: activeRod)
                drawRipplesAndBobber(in: &context, canvasWidth: max(1, Int(size.width)), phaseSec: phaseSec)
                if coordinator.isRemasterModeEnabled {
                    drawRemasterWaterSplashes(in: &context, phaseSec: phaseSec)
                    drawRemasterWeatherParticles(in: &context, size: size, phaseSec: phaseSec)
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

    // MARK: - Modular Canvas Drawing Helpers (`GameView.draw(Canvas)` + Remaster Visual Effects)

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
            for i in 0..<24 {
                let seed = Double(i * 97 + 13)
                let x = (sin(seed * 1.37) * 0.5 + 0.5) * size.width
                let y = (cos(seed * 2.11) * 0.5 + 0.5) * horizonY
                let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(phaseSec * (1.8 + Double(i % 5) * 0.4) + seed))
                let starRadius = (i % 4 == 0) ? 1.8 : 1.2
                let rect = CGRect(x: x - starRadius, y: y - starRadius, width: starRadius * 2, height: starRadius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(twinkle * 0.85)))
            }
        }

        if weather == .starryCalm || (isNight && weather != .rain) {
            // Glowing fireflies floating gently above the water
            for i in 0..<10 {
                let seed = Double(i * 53 + 7)
                let baseX = (sin(seed * 0.91 + phaseSec * 0.18) * 0.42 + 0.5) * size.width
                let baseY = (0.32 + 0.52 * (cos(seed * 1.43 + phaseSec * 0.14) * 0.5 + 0.5)) * size.height
                let pulse = 0.25 + 0.75 * max(0.0, sin(phaseSec * 2.6 + seed))
                let glowRect = CGRect(x: baseX - 5.0, y: baseY - 5.0, width: 10.0, height: 10.0)
                let coreRect = CGRect(x: baseX - 2.0, y: baseY - 2.0, width: 4.0, height: 4.0)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(Color(red: 0.75, green: 1.0, blue: 0.35).opacity(pulse * 0.28))
                )
                context.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(Color(red: 0.92, green: 1.0, blue: 0.55).opacity(pulse * 0.90))
                )
            }
        } else if weather == .clear && !isNight {
            // Subtle sunlit water sparkle motes
            for i in 0..<14 {
                let seed = Double(i * 71 + 19)
                let x = (0.12 + 0.76 * (sin(seed * 1.7) * 0.5 + 0.5)) * size.width
                let y = (0.28 + 0.58 * (cos(seed * 2.3) * 0.5 + 0.5)) * size.height
                let sparkle = max(0.0, sin(phaseSec * 3.2 + seed * 1.9))
                if sparkle > 0.35 {
                    let alpha = (sparkle - 0.35) * 0.75
                    let w = 4.0 + sparkle * 5.0
                    let rect = CGRect(x: x - w * 0.5, y: y - 1.0, width: w, height: 2.0)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(red: 1.0, green: 0.96, blue: 0.78).opacity(alpha))
                    )
                }
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
            ? min(2.15, max(0.78, CGFloat(log10(Double(weightGrams) + 10.0) * 0.46)))
            : 0.82

        let bodyLen: CGFloat = 34.0 * weightScale
        let bodyHalfWidth: CGFloat = 8.5 * weightScale

        let isPulled = coordinator.stateMachine.isPulled
        let isExhausted = coordinator.stateMachine.fishController?.isExhausted ?? false
        let tensionNorm = CGFloat(min(225, max(0, coordinator.stateMachine.tension))) / 225.0

        // Tail wag speed & heading angle
        let wagFreq = isFighting ? (isExhausted ? 4.5 : (9.0 + Double(tensionNorm) * 11.0)) : 3.2
        let tailSway = CGFloat(sin(phaseSec * wagFreq)) * (isFighting ? (5.5 + tensionNorm * 4.5) : 3.0) * weightScale

        let centerOffsetX: CGFloat
        let centerOffsetY: CGFloat
        let headingAngle: Double

        if isFighting {
            let driftAngle = sin(phaseSec * 2.1) * 0.35
            headingAngle = (isPulled ? (Double.pi * 0.5) : (-Double.pi * 0.5)) + driftAngle
            centerOffsetX = CGFloat(sin(phaseSec * 3.0)) * 7.0
            centerOffsetY = isPulled ? -10.0 : 12.0
        } else {
            // Slowly circling shadow under the float while waiting for bite
            let orbitAngle = phaseSec * 0.85
            centerOffsetX = CGFloat(cos(orbitAngle)) * 22.0
            centerOffsetY = CGFloat(sin(orbitAngle)) * 11.0 + 10.0
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

            // Pectoral fins
            var finsPath = Path()
            finsPath.move(to: CGPoint(x: bodyLen * 0.12, y: -bodyHalfWidth * 0.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.08, y: -bodyHalfWidth * 1.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.05, y: -bodyHalfWidth * 0.45))
            finsPath.closeSubpath()

            finsPath.move(to: CGPoint(x: bodyLen * 0.12, y: bodyHalfWidth * 0.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.08, y: bodyHalfWidth * 1.55))
            finsPath.addLine(to: CGPoint(x: -bodyLen * 0.05, y: bodyHalfWidth * 0.45))
            finsPath.closeSubpath()

            let shadowOpacity = isFighting ? 0.46 : 0.22
            layer.fill(fishPath, with: .color(Color(red: 0.02, green: 0.07, blue: 0.12).opacity(shadowOpacity)))
            layer.fill(finsPath, with: .color(Color(red: 0.02, green: 0.07, blue: 0.12).opacity(shadowOpacity * 0.85)))

            if isFighting {
                layer.stroke(
                    fishPath,
                    with: .color(Color(red: 0.55, green: 0.88, blue: 1.0).opacity(0.24)),
                    lineWidth: 1.2
                )
            }
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
            intensity = 0.35
        } else if isPulled || tension >= 100 {
            intensity = min(1.0, 0.45 + Double(tension) / 250.0)
        } else {
            intensity = 0.25
        }

        let center = CGPoint(x: CGFloat(displayPos.x), y: CGFloat(displayPos.y) + 2.0)

        // White foam ring around submerged bobber
        let foamPulse = CGFloat(0.65 + 0.35 * sin(phaseSec * 9.0))
        let foamW = CGFloat(18.0 + intensity * 22.0) * foamPulse
        let foamH = foamW * 0.46
        let foamRect = CGRect(
            x: center.x - foamW * 0.5,
            y: center.y - foamH * 0.5,
            width: foamW,
            height: foamH
        )
        context.stroke(
            Path(ellipseIn: foamRect),
            with: .color(Color.white.opacity(0.38 * intensity)),
            lineWidth: 2.2
        )

        // Airborne water splash droplets
        let dropletCount = isPreHook ? 4 : 9
        for i in 0..<dropletCount {
            let seed = Double(i * 41 + 11)
            let cycle = (phaseSec * (2.6 + Double(i % 3) * 0.55) + seed).truncatingRemainder(dividingBy: 1.0)
            let angle = -Double.pi * (0.12 + 0.76 * (Double(i) / Double(max(1, dropletCount - 1))))
            let maxRadius = (14.0 + intensity * 26.0) * (0.7 + 0.3 * sin(seed))
            let dist = cycle * maxRadius
            let arcLift = -sin(cycle * .pi) * (10.0 + intensity * 18.0)

            let dropX = center.x + CGFloat(cos(angle) * dist)
            let dropY = center.y + CGFloat(sin(angle) * dist * 0.45 + arcLift)
            let dropAlpha = (1.0 - cycle) * 0.82 * intensity
            let dropSize = CGFloat(max(2.0, (1.0 - cycle * 0.5) * 4.2))

            let dropRect = CGRect(
                x: dropX - dropSize * 0.5,
                y: dropY - dropSize * 0.5,
                width: dropSize,
                height: dropSize * 1.25
            )
            context.fill(
                Path(ellipseIn: dropRect),
                with: .color(Color(red: 0.90, green: 0.97, blue: 1.0).opacity(dropAlpha))
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
            let dropCount = (weather == .thunderstorm) ? 48 : 28
            let streakLen: CGFloat = (weather == .thunderstorm) ? 18.0 : 13.0
            for i in 0..<dropCount {
                let seed = Double(i * 61 + 29)
                let speed = (weather == .thunderstorm) ? 1.85 : 1.35
                let progress = (phaseSec * speed + seed * 0.17).truncatingRemainder(dividingBy: 1.0)
                let startX = ((sin(seed * 2.13) * 0.5 + 0.5) * (size.width + 80.0)) - 40.0
                let x = startX + CGFloat(progress) * 36.0
                let y = CGFloat(progress) * size.height

                var streak = Path()
                streak.move(to: CGPoint(x: x, y: y))
                streak.addLine(to: CGPoint(x: x + 4.5, y: y + streakLen))
                context.stroke(
                    streak,
                    with: .color(Color(red: 0.80, green: 0.90, blue: 1.0).opacity(0.34)),
                    lineWidth: 1.15
                )

                // Raindrop splash ring on water surface
                if y > size.height * 0.25 && progress > 0.72 {
                    let ringT = (progress - 0.72) / 0.28
                    let rw = CGFloat(4.0 + ringT * 14.0)
                    let rh = rw * 0.42
                    let rRect = CGRect(x: x - rw * 0.5, y: y - rh * 0.5, width: rw, height: rh)
                    context.stroke(
                        Path(ellipseIn: rRect),
                        with: .color(Color.white.opacity((1.0 - ringT) * 0.25)),
                        lineWidth: 1.0
                    )
                }
            }

        case .morningMist:
            // Soft drifting mist bands over the water horizon
            for band in 0..<4 {
                let seed = Double(band * 37 + 5)
                let yCenter = size.height * CGFloat(0.20 + Double(band) * 0.11)
                let xShift = CGFloat(sin(phaseSec * 0.22 + seed)) * (size.width * 0.18)
                let mistRect = CGRect(
                    x: -size.width * 0.15 + xShift,
                    y: yCenter - 22.0,
                    width: size.width * 1.30,
                    height: 44.0
                )
                context.fill(
                    Path(ellipseIn: mistRect),
                    with: .color(Color(red: 0.88, green: 0.94, blue: 0.98).opacity(0.11))
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
                ? Color(red: 0.85, green: 0.96, blue: 1.0).opacity(min(1.0, alpha * 1.15))
                : Color.white.opacity(alpha)
            context.stroke(path, with: .color(rippleColor), lineWidth: isRemaster ? 2.2 : 2.0)
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

        // In Remaster mode, add a soft luminous halo around the float tip at night or during bite
        if isRemaster {
            let isNight = !coordinator.dayNightLighting.isDayLight
            if bobber.isBiteTexture || isNight {
                let pulse = 0.65 + 0.35 * sin(phaseSec * 6.0)
                let glowRadius: CGFloat = bobber.isBiteTexture ? 14.0 : 10.0
                let glowCenterY = bobber.isBiteTexture ? CGFloat(displayPos.y) : (bobberRect.minY + 8.0)
                let glowRect = CGRect(
                    x: CGFloat(displayPos.x) - glowRadius,
                    y: glowCenterY - glowRadius,
                    width: glowRadius * 2.0,
                    height: glowRadius * 2.0
                )
                let glowColor = bobber.isBiteTexture
                    ? Color(red: 1.0, green: 0.28, blue: 0.18).opacity(0.45 * pulse)
                    : Color(red: 0.35, green: 1.0, blue: 0.65).opacity(0.35 * pulse)
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
                ? Color(red: 1.0, green: 0.42, blue: 0.38).opacity(min(1.0, alpha + 0.15))
                : Color(red: 0.90, green: 0.97, blue: 1.0).opacity(min(1.0, alpha + 0.10))
            context.stroke(
                linePath,
                with: .color(lineColor),
                lineWidth: CGFloat(curve.strokeWidth) + 0.35
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

// MARK: - 0. Remaster Smooth 24-Hour Atmospheric Sky & Water Lighting Overlay

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
            // Dawn / Sunrise: rose-violet top, warm peach-gold horizon, amber water reflection
            return [
                Color(red: 0.22, green: 0.16, blue: 0.38).opacity(0.34),
                Color(red: 0.96, green: 0.54, blue: 0.32).opacity(0.28),
                Color(red: 0.98, green: 0.76, blue: 0.42).opacity(0.14),
                Color(red: 0.06, green: 0.18, blue: 0.26).opacity(0.18)
            ]
        } else if h >= 8.0 && h < 17.5 {
            // Daylight: crisp sky blue & sunlit aqua water depth
            if weather == .rain || weather == .thunderstorm {
                return [
                    Color(red: 0.14, green: 0.20, blue: 0.28).opacity(0.42),
                    Color(red: 0.20, green: 0.28, blue: 0.36).opacity(0.28),
                    Color(red: 0.05, green: 0.12, blue: 0.18).opacity(0.32)
                ]
            }
            return [
                Color(red: 0.20, green: 0.58, blue: 0.92).opacity(0.12),
                Color(red: 1.0, green: 0.96, blue: 0.82).opacity(0.08),
                Color(red: 0.02, green: 0.22, blue: 0.32).opacity(0.14)
            ]
        } else if h >= 17.5 && h < 21.5 {
            // Golden Hour / Sunset: deep magenta-indigo sky, fiery sunset gold horizon, warm bronze water
            return [
                Color(red: 0.28, green: 0.12, blue: 0.36).opacity(0.38),
                Color(red: 0.95, green: 0.38, blue: 0.22).opacity(0.32),
                Color(red: 0.98, green: 0.68, blue: 0.28).opacity(0.18),
                Color(red: 0.08, green: 0.10, blue: 0.22).opacity(0.28)
            ]
        } else {
            // Starry Night: deep midnight navy sky & moonlight cyan-indigo water
            return [
                Color(red: 0.02, green: 0.05, blue: 0.16).opacity(0.56),
                Color(red: 0.05, green: 0.12, blue: 0.28).opacity(0.42),
                Color(red: 0.02, green: 0.08, blue: 0.20).opacity(0.48)
            ]
        }
    }

    var body: some View {
        LinearGradient(
            colors: atmosphereColors,
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.plusLighter)
    }
}

// MARK: - 1. Top Experience Progress Bar (`pbExp` + `pbExpText`, `res/Ak.xml` + Remaster Styling)

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
                        .fill(Color.black.opacity(0.72))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: coordinator.isRemasterModeEnabled
                                    ? [
                                        Color(red: 0.12, green: 0.68, blue: 0.52),
                                        Color(red: 0.24, green: 0.86, blue: 0.68)
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
            HStack(spacing: 8) {
                Text("Разряд \(coordinator.profile.category)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(FishingPondView.goldTextColor)
                Text("•")
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(coordinator.profile.experience) / \(nextThreshold) XP")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                Text("•")
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(coordinator.profile.balance) руб")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.45, green: 0.98, blue: 0.58))
            }
            .shadow(color: .black, radius: 1, x: 0, y: 1)
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
                Color(red: 0.0, green: 0.02, blue: isRemasterMode ? 0.18 : (30.0 / 255.0))
                    .opacity(isRemasterMode ? 0.52 : (120.0 / 255.0))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 3. Top Overlay Bar (`btPonds` on left, Pond Title in center, `top_menu` + Remaster Pills on right)

private struct PondTopOverlayBarView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onOpenQuickTackle: () -> Void

    private var localizedCurrentPondTitle: String {
        guard let pond = coordinator.currentPondItem else { return "Кедровый остров" }
        return coordinator.localeManager.pondName(for: pond).capitalized
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                if coordinator.stateMachine.state == .fishFight {
                    return
                } else if coordinator.stateMachine.state != .idle {
                    coordinator.resetCastToIdle()
                } else {
                    coordinator.selectedTab = .baseHub
                }
            } label: {
                if coordinator.isRemasterModeEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: coordinator.stateMachine.state == .idle ? "chevron.left" : "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .bold))
                        Text(coordinator.stateMachine.state == .idle ? "База" : "Сброс")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .opacity(coordinator.stateMachine.state == .fishFight ? 0.45 : 1.0)
                } else {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "pond_out",
                        fallbackSystemName: "arrow.uturn.backward.square.fill",
                        width: 40,
                        height: 40
                    )
                    .opacity(coordinator.stateMachine.state == .fishFight ? 0.45 : 1.0)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                if coordinator.isRemasterModeEnabled && coordinator.stateMachine.state == .idle {
                    onOpenQuickTackle()
                }
            } label: {
                HStack(spacing: 5) {
                    Text(localizedCurrentPondTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FishingPondView.goldTextColor)
                    if coordinator.isRemasterModeEnabled {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.cyan)
                    }
                }
                .shadow(color: .black, radius: 2, x: 0, y: 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    coordinator.isRemasterModeEnabled
                        ? AnyShapeStyle(.ultraThinMaterial)
                        : AnyShapeStyle(Color.black.opacity(0.45)),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(
                        coordinator.isRemasterModeEnabled ? Color.white.opacity(0.22) : Color.clear,
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.5).onEnded { _ in
                    coordinator.isDebugOverlayEnabled.toggle()
                }
            )

            Spacer()

            if coordinator.isRemasterModeEnabled {
                HStack(spacing: 6) {
                    Button {
                        coordinator.cycleRemasterWeather()
                    } label: {
                        let weather = coordinator.currentResolvedWeather
                        HStack(spacing: 4) {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.yellow)
                            Text(weather.shortBadgeRu)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            coordinator.isSonarRadarVisible.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(coordinator.isSonarRadarVisible ? .green : .white.opacity(0.75))
                            Text("Эхолот")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(
                                coordinator.isSonarRadarVisible ? Color.green.opacity(0.55) : Color.white.opacity(0.22),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard coordinator.stateMachine.state == .idle else { return }
                        coordinator.selectedTab = .progress
                    } label: {
                        Image(systemName: "checklist")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(FishingPondView.goldTextColor)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                            .opacity(coordinator.stateMachine.state == .idle ? 1.0 : 0.45)
                    }
                    .buttonStyle(.plain)

                    Button {
                        coordinator.selectedTab = .online
                    } label: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.cyan)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            } else {
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
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }
}

// MARK: - 3A. Remaster Floating HUD: Free Echolot/Bite Radar + Active Quest/Task Pill + Live Fight Telemetry

private struct RemasterPondFloatingHUDView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onOpenBaitChooser: () -> Void

    private var timeOfDayTitleRu: String {
        switch coordinator.stateMachine.timeOfDay {
        case .morning: return "🌅 Утро"
        case .afternoon: return "☀️ День"
        case .evening: return "🌇 Вечер"
        case .night: return "🌙 Ночь"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 1. Active Quest / Fisherman Task tracker banner
            if let contract = coordinator.activeContract, contract.made == 0 {
                let targetFishName = coordinator.fishCatalogById[contract.targetFishId]?.name ?? "Рыба #\(contract.targetFishId)"
                Button {
                    guard coordinator.stateMachine.state == .idle else { return }
                    coordinator.selectedProgressSection = .tasks
                    coordinator.selectedTab = .progress
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.cyan)
                        Text("Поручение: \(targetFishName) • \(contract.goalSummaryDescriptionRu)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if let quest = coordinator.activeQuestForPlayer {
                            Text("Квест #\(quest.id)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(FishingPondView.goldTextColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.52), in: Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else if let quest = coordinator.activeQuestForPlayer {
                Button {
                    guard coordinator.stateMachine.state == .idle else { return }
                    coordinator.selectedProgressSection = .quests
                    coordinator.selectedTab = .progress
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: quest.made == 1 ? "gift.fill" : "flag.checkered")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(quest.made == 1 ? .green : FishingPondView.goldTextColor)
                        Text(
                            quest.made == 1
                                ? "🎉 Квест #\(quest.id) «\(coordinator.localeManager.questTitle(id1Based: quest.id))» выполнен! Нажмите за наградой"
                                : "Квест #\(quest.id): «\(coordinator.localeManager.questTitle(id1Based: quest.id))»"
                        )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.52), in: Capsule())
                    .overlay(Capsule().stroke(FishingPondView.goldTextColor.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // 2. Live Fight Telemetry Banner during `fishFight`
            if coordinator.stateMachine.state == .fishFight {
                RemasterLiveFightTelemetryBanner(coordinator: coordinator)
            }

            // 3. Collapsible Free Echolot / Bite Radar Panel
            if coordinator.isSonarRadarVisible && coordinator.stateMachine.state != .fishFight {
                RemasterSonarRadarCardView(
                    coordinator: coordinator,
                    timeOfDayTitleRu: timeOfDayTitleRu,
                    onOpenBaitChooser: onOpenBaitChooser
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 8)
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
            return ("🎣 Поклёвка! Удерживайте катушку справа для подсечки", .yellow)
        } else if tension >= 195 {
            return ("⚠️ КРИТИЧЕСКАЯ НАГРУЗКА! Отпустите катушку!", .red)
        } else if isExhausted {
            return ("💤 Рыба выбилась из сил — смело подматывайте к берегу!", .green)
        } else if coordinator.stateMachine.isPulled {
            return ("💪 Подмотка: следите за шкалой натяжения", .cyan)
        } else {
            return ("🌊 Фрикцион ослаблен — нагрузка снижается", .orange)
        }
    }

    var body: some View {
        let status = fishStatusTextAndColor
        HStack(spacing: 10) {
            Text(status.0)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(status.1)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(String(format: "До берега: %.1f м", distanceMeters))
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.14), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(status.1.opacity(0.65), lineWidth: 1.2)
        )
    }
}

private struct RemasterSonarRadarCardView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let timeOfDayTitleRu: String
    let onOpenBaitChooser: () -> Void

    var body: some View {
        let forecast = coordinator.currentPondBiteForecast
        let baitName = coordinator.assembledTackle.userBait?.bait.name.capitalized ?? "Не выбрана"

        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "wave.3.forward.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.green)
                Text("Эхолот • \(coordinator.currentCastDepthZoneTitleRu)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                Spacer()
                Text("\(timeOfDayTitleRu) • \(baitName)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FishingPondView.goldTextColor)
            }

            if forecast.isEmpty {
                HStack(spacing: 8) {
                    Text("⚠️ На наживку «\(baitName)» сейчас на этом водоёме клёва нет.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                    Spacer()
                    if coordinator.stateMachine.state == .idle {
                        Button("Сменить наживку", action: onOpenBaitChooser)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(FishingPondView.goldTextColor, in: Capsule())
                            .buttonStyle(.plain)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(forecast.prefix(8)) { item in
                            HStack(spacing: 5) {
                                OriginalSpriteOrFallbackIcon(
                                    drawableName: "fish_\(item.id)",
                                    fallbackSystemName: "fish.fill",
                                    width: 24,
                                    height: 16
                                )
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 3) {
                                        if item.isQuestOrTaskTarget {
                                            Text("🎯")
                                                .font(.system(size: 9))
                                        }
                                        Text(item.fishName)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(item.isQuestOrTaskTarget ? .cyan : .white)
                                        Text("\(item.probabilityPercent)%")
                                            .font(.system(size: 10, weight: .heavy).monospacedDigit())
                                            .foregroundStyle(.green)
                                    }
                                    Text("\(PlayerStateRepository.formatGramsAsKgOrGrams(item.minWeightGrams))–\(PlayerStateRepository.formatGramsAsKgOrGrams(item.maxWeightGrams))")
                                        .font(.system(size: 9).monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                item.isQuestOrTaskTarget
                                    ? Color.cyan.opacity(0.22)
                                    : Color.black.opacity(0.45),
                                in: RoundedRectangle(cornerRadius: 7)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(
                                        item.isQuestOrTaskTarget ? Color.cyan.opacity(0.7) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.32), lineWidth: 1)
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
                coordinator.isRemasterModeEnabled.toggle()
            } label: {
                Text(coordinator.isRemasterModeEnabled ? "✨ Ремастер" : "Классика")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.3), in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

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

// MARK: - 4. Bottom Controls Panel (`res/Ak.xml` Classic + Remaster Glassmorphic Control Deck with Radial Tension Gauge)

private struct PondBottomControlsPanelView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onPresentBaitChooser: () -> Void
    let onPresentQuickTackle: () -> Void
    @State private var didCastDuringCurrentPress: Bool = false

    /// Exact progress bar normalization from `res/Ak.xml` (`game_progress`, `android:max="225"`)
    /// and `GameView$c.v(FishingRod)` (`h >= 225` critical tension overload threshold).
    private var tensionFraction: Double {
        let tension = coordinator.stateMachine.tension
        return Double(min(225, max(0, tension))) / 225.0
    }

    private var tensionColor: Color {
        let tension = coordinator.stateMachine.tension
        if tension >= 195 { return .red }
        if tension >= 140 { return .orange }
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

    private var rodMaxKg: Int {
        coordinator.assembledTackle.userRod?.rod.weight ?? 0
    }

    private var lineMaxKg: Int {
        coordinator.assembledTackle.userLine?.line.weight ?? 0
    }

    private var isBitingOrPulling: Bool {
        coordinator.stateMachine.isPulled
            || (coordinator.stateMachine.state == .fishFight && coordinator.stateMachine.isPreHookBobbing)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(spacing: 5) {
                tensionProgressBar
                upperControlsRow
                lowerControlsRow
            }
            reelPullButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            coordinator.isRemasterModeEnabled
                ? AnyShapeStyle(.ultraThinMaterial)
                : AnyShapeStyle(Color.black.opacity(0.45))
        )
    }

    private var tensionProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.68))
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                .green,
                                coordinator.stateMachine.tension >= 120 ? .orange : .green,
                                coordinator.stateMachine.tension >= 185 ? .red : tensionColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * tensionFraction)
                    .animation(.linear(duration: 0.05), value: coordinator.stateMachine.tension)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)

                if coordinator.isRemasterModeEnabled {
                    HStack {
                        Text("НАГРУЗКА СНАСТИ")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Text("\(coordinator.stateMachine.tension) / 225")
                            .font(.system(size: 10, weight: .heavy).monospacedDigit())
                            .foregroundStyle(coordinator.stateMachine.tension >= 185 ? .red : .white)
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
        .frame(height: coordinator.isRemasterModeEnabled ? 15 : 12)
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
            if !coordinator.isRemasterModeEnabled, let timeBg = OriginalGameAssetsLoader.image(named: "time_background") {
                timeBg
                    .resizable()
                    .frame(height: 40)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.55))
                    .frame(height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            HStack(spacing: 6) {
                if coordinator.isRemasterModeEnabled {
                    Image(systemName: coordinator.dayNightLighting.isDayLight ? "sun.max.fill" : "moon.stars.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(coordinator.dayNightLighting.isDayLight ? .yellow : .cyan)
                }
                Text(String(format: "%02d:%02d", coordinator.gameClock.hour, coordinator.gameClock.minute))
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(FishingPondView.goldTextColor)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var durabilityReadout: some View {
        Button {
            if coordinator.isRemasterModeEnabled {
                onPresentQuickTackle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("У - \(rodStrength)%")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(rodStrength <= 20 ? .red : .white)
                    if coordinator.isRemasterModeEnabled && rodMaxKg > 0 {
                        Text("(\(rodMaxKg)кг)")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(FishingPondView.goldTextColor)
                    }
                }
                HStack(spacing: 4) {
                    Text("К - \(coilStrength)%")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(coilStrength <= 20 ? .red : .white)
                    if coordinator.isRemasterModeEnabled && lineMaxKg > 0 {
                        Text("Л:\(lineMaxKg)кг")
                            .font(.system(size: 10, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .padding(.horizontal, coordinator.isRemasterModeEnabled ? 8 : 0)
            .padding(.vertical, coordinator.isRemasterModeEnabled ? 4 : 0)
            .background(
                coordinator.isRemasterModeEnabled ? Color.black.opacity(0.45) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .shadow(color: .black, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
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
                .font(.system(size: 15, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 24, minHeight: 36)

            if coordinator.isRemasterModeEnabled && !coordinator.fishnetEntries.isEmpty && coordinator.stateMachine.state == .idle {
                Button {
                    coordinator.sellAllFishInFishnet()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "rublesign.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Продать")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.green, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                guard coordinator.stateMachine.state == .idle else { return }
                if coordinator.isRemasterModeEnabled {
                    onPresentQuickTackle()
                } else {
                    coordinator.selectedTab = .inventory
                }
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

            // Remaster Radial Tension Tachometer Arc around the Reel Wheel
            if coordinator.isRemasterModeEnabled {
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 5)
                    .frame(width: 92, height: 92)

                Circle()
                    .trim(from: 0.0, to: CGFloat(tensionFraction))
                    .stroke(
                        AngularGradient(
                            colors: [.green, .yellow, .orange, .red],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 92, height: 92)
                    .animation(.linear(duration: 0.05), value: coordinator.stateMachine.tension)

                if coordinator.stateMachine.state == .idle {
                    Text("ЗАБРОС")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .offset(y: 42)
                } else if coordinator.stateMachine.state == .fishFight {
                    Text(coordinator.stateMachine.isPulled ? "ТЯНЕМ" : "КАТУШКА")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(coordinator.stateMachine.isPulled ? .black : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            coordinator.stateMachine.isPulled ? FishingPondView.goldTextColor : Color.black.opacity(0.65),
                            in: Capsule()
                        )
                        .offset(y: 42)
                }
            }
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
                Color(red: 0.07, green: 0.12, blue: 0.17).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. One-tap Auto-Rig Best Tackle button
                        Button {
                            coordinator.equipBestOwnedTackle()
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 16, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Авто-сборка лучшей снасти")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("В один тап экипирует самые крепкие удилище, катушку, леску, крючок и уловистую наживку")
                                        .font(.system(size: 11))
                                        .opacity(0.85)
                                }
                                Spacer()
                                Image(systemName: "bolt.fill")
                            }
                            .foregroundStyle(.black)
                            .padding(12)
                            .background(FishingPondView.goldTextColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        // 2. Quick Pond Switcher
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
                                                    .foregroundStyle(isCurrent ? .black.opacity(0.8) : .cyan)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(
                                                isCurrent
                                                    ? FishingPondView.goldTextColor
                                                    : Color.white.opacity(unlocked ? 0.12 : 0.05),
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
                        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))

                        // 3. Rods
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

                        // 4. Coils
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

                        // 5. Lines
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

                        // 6. Hooks
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

                        // 7. Baits
                        quickSectionHeader("Наживка (\(coordinator.ownedBaits.count))")
                        ForEach(coordinator.ownedBaits) { item in
                            let worksHere = coordinator.stateMachine.pondData.activeBaitIndices0Based.contains(item.bait.id - 1)
                            quickEquipRow(
                                icon: "bait_\(item.bait.id)",
                                title: item.bait.name.capitalized + (worksHere ? " • Клюёт здесь ✅" : ""),
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
                    .foregroundStyle(isEquipped ? .green : .white.opacity(0.35))
            }
            .padding(10)
            .background(
                isEquipped ? Color.green.opacity(0.16) : Color.black.opacity(0.45),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isEquipped ? Color.green.opacity(0.55) : Color.white.opacity(0.10), lineWidth: 1)
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
                sheetBackground
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
    private var sheetBackground: some View {
        if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
            bg.resizable().ignoresSafeArea()
        } else {
            Color(red: 0.10, green: 0.14, blue: 0.18).ignoresSafeArea()
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
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green, in: Capsule())
                        }
                    }
                    Text("Остаток: \(item.amount) шт.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                if isEquipped {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "tick",
                        fallbackSystemName: "checkmark.circle.fill",
                        width: 28,
                        height: 28
                    )
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
