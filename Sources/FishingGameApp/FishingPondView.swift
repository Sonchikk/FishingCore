import SwiftUI
import FishingCore
import FishingDatabase

/// Authentic fishing pond screen (`GameActivity` + `GameView` + `F0.n` `WaterMetalRenderer`),
/// reconstructed 1:1 from `res/layout/game_activity.xml` (`res/Ak.xml`) and `RENDERER.md`:
/// - Full-screen `@drawable/second_background` frame;
/// - Top `pbExp` experience bar + `btPonds` (`@drawable/pond_out`) exit button + `top_menu` (`@drawable/tchat`, `@drawable/task_btn`, `@drawable/tours_btn`);
/// - Interactive `GameView` combining 3-pass Metal water (`pond_<id>_big.png` + `wNoise3/4.tga`), expanding ripples (`D0.a`),
///   original bobber sprites (`@drawable/bobber` `16x52` / `@drawable/bobber_hide` `12x12`), Quadratic Bezier line (`D0.b`),
///   and 16-frame bent rod sprites (`@drawable/fishing_rod_0..15`, `D0.c`);
/// - Bottom control panel with `game_progress` tension bar (`max="225"` in `res/Ak.xml`), `game_current_bait` (`@drawable/btn_background` + `@drawable/bait_<id>`),
///   `game_time` (`@drawable/time_background`, `#EBB968`), `"У - X"` / `"К - Y"` durability labels,
///   `game_fishpond` (`@drawable/fishpond_small`), `game_backpack` (`@drawable/backpack_small`),
///   `game_cancel` (`@drawable/drop_me`), and the right-hand reel button `game_pull` (`@drawable/push_me` / `@drawable/push_me_on`).
public struct FishingPondView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var isBaitChooserPresented: Bool = false

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
                        // Match `GameActivity.onClick`: block bait chooser while rod is cast (`state != .idle`)
                        guard coordinator.stateMachine.state == .idle else {
                            return
                        }
                        if coordinator.ownedBaits.isEmpty {
                            coordinator.activeAlert = .operationError(message: "В рюкзаке нет наживок.")
                        } else {
                            isBaitChooserPresented = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isBaitChooserPresented) {
            BaitQuickChooserSheet(coordinator: coordinator)
        }
    }

    @ViewBuilder
    private var pondFrameBackground: some View {
        if let secondBg = OriginalGameAssetsLoader.image(named: "second_background") {
            secondBg
                .resizable()
                .ignoresSafeArea()
        } else {
            Color(red: 0.08, green: 0.12, blue: 0.16)
                .ignoresSafeArea()
        }
    }

    // MARK: - Main Pond Area (`GameView` + Top Overlay Buttons `btPonds` & `top_menu`)

    private var pondInteractiveArea: some View {
        GeometryReader { geo in
            let w = max(320, Int(geo.size.width.rounded()))
            let h = max(240, Int(geo.size.height.rounded()))

            ZStack(alignment: .top) {
                pondWaterLayer
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                pondCanvasLayer(viewportWidth: w, viewportHeight: h)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                PondTopOverlayBarView(coordinator: coordinator)
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
                isDayLight: coordinator.dayNightLighting.isDayLight
            )
        }
    }

    private func pondCanvasLayer(viewportWidth: Int, viewportHeight: Int) -> some View {
        Canvas { context, size in
            let activeRod = resolvedRodSprite(for: size)
            drawFishingLine(in: &context, rod: activeRod)
            drawRipplesAndBobber(in: &context, canvasWidth: max(1, Int(size.width)))
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

    // MARK: - Modular Canvas Drawing Helpers (`GameView.draw(Canvas)`)

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

    private func drawRipplesAndBobber(in context: inout GraphicsContext, canvasWidth: Int) {
        guard let bobber = coordinator.stateMachine.bobber else { return }
        // Match `GameView.draw(Canvas)` (`pc=0067..008d`): only draw bobber & ripples once `!isCastAnimating || castProgress > 0.95`
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
            context.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 2.0)
        }

        let displayPos = coordinator.renderedBobberPosition ?? Point2D(x: bobber.x, y: bobber.y)
        let bobberDrawableName = bobber.isBiteTexture ? "bobber_hide" : "bobber"

        // Preserve exact native sprite proportions from `fishing181.apk`:
        // - `bobber.png` (`res/ky.png`) is `16 x 52` px (full float with top bead, thin stem, and bulb)
        // - `bobber_hide.png` (`res/uh1.png`) is `12 x 12` px (submerged float showing only the top red bead)
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
        context.stroke(
            linePath,
            with: .color(.white.opacity(alpha)),
            lineWidth: CGFloat(curve.strokeWidth)
        )
    }
}

// MARK: - 1. Top Experience Progress Bar (`pbExp` + `pbExpText`, `res/Ak.xml`)

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
                        .fill(Color.black.opacity(0.65))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
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
            Text("\(coordinator.profile.experience) / \(nextThreshold) XP  •  Разряд \(coordinator.profile.category)  •  \(coordinator.profile.balance) руб")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 1)
        }
        .frame(height: 16)
    }
}

// MARK: - 2. Static 2D Pond Background (`pond_<id>_big.png` + `GameView.u()` Night Tint)

private struct Static2DPondBackgroundView: View {
    let pondIndex: Int
    let isDayLight: Bool

    var body: some View {
        let pondNumber = max(1, min(15, pondIndex + 1))
        ZStack {
            if let pondImg = OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)_big")
                ?? OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)") {
                // Match `GameView.t()` (`Bitmap.createScaledBitmap(bmp, width, height, true)`)
                // and `MetalWaterSurfaceView` UV mapping (`0..1` across the exact `GameView` bounds)
                // so the visual shoreline horizon aligns with `y = viewHeight / 4` (25% from top).
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
            // Exact `GameView.u()` night overlay `Color.argb(120, 0, 0, 30)` (`#7800001E`, `RENDERER.md` Section 1.1)
            if !isDayLight {
                Color(red: 0.0, green: 0.0, blue: 30.0 / 255.0)
                    .opacity(120.0 / 255.0)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 3. Top Overlay Bar (`btPonds` on left, Pond Title in center, `top_menu` on right)

private struct PondTopOverlayBarView: View {
    @ObservedObject var coordinator: FishingAppCoordinator

    private var localizedCurrentPondTitle: String {
        guard let pond = coordinator.currentPondItem else { return "Кедровый остров" }
        return coordinator.localeManager.pondName(for: pond).capitalized
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                // Match `GameActivity.U()`: during fish fight (`state == .fishFight`) cannot exit directly;
                // during waitingForBite (`state == .waitingForBite`), first tap reels in (`resetCastToIdle`),
                // and when idle (`state == .idle`), returns to the base hub (`PondListActivity` / `MainActivity`).
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
                coordinator.isWaterShaderEnabled.toggle()
            } label: {
                Text(coordinator.isWaterShaderActive ? "GL Вода" : "2D Вода")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2), in: Capsule())
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
                    coordinator.buyAndEquipStarterKit()
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

// MARK: - 4. Authentic Bottom Controls Panel (`res/Ak.xml`)

private struct PondBottomControlsPanelView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    let onPresentBaitChooser: () -> Void
    @State private var didCastDuringCurrentPress: Bool = false

    /// Exact progress bar normalization from `res/Ak.xml` (`game_progress`, `android:max="225"`)
    /// and `GameView$c.v(FishingRod)` (`h >= 225` critical tension overload threshold).
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
                // Match `GameActivity.onClick`: fishnet (`game_fishpond`) is locked while rod is cast (`state != .idle`)
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
                // Match `GameActivity.onClick`: backpack (`game_backpack`) is locked while rod is cast (`state != .idle`)
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
                        // Match `GameActivity$s.onTouch`: re-cast into saved `Xbobber, Ybobber` (or center)
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
                        BaitQuickChooserRowView(
                            item: item,
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
                    Text(item.bait.name.capitalized)
                        .font(.headline)
                        .foregroundStyle(FishingPondView.goldTextColor)
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
