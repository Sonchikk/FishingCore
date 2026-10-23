import SwiftUI
import FishingCore
import FishingDatabase

/// Authentic fishing pond screen (`GameActivity` + `GameView` + `F0.n` `WaterMetalRenderer`),
/// reconstructed 1:1 from `res/layout/game_activity.xml` (`res/Ak.xml`) and `RENDERER.md`:
/// - Full-screen `@drawable/second_background` frame;
/// - Top `pbExp` experience bar + `btPonds` (`@drawable/pond_out`) exit button + `top_menu` (`@drawable/tchat`, `@drawable/task_btn`, `@drawable/tours_btn`);
/// - Interactive `GameView` combining 3-pass Metal water (`pond_<id>_big.png` + `wNoise3/4.tga`), expanding ripples (`D0.a`),
///   original bobber sprites (`@drawable/bobber` / `@drawable/bobber_hide`), Quadratic Bezier line (`D0.b`),
///   and 16-frame bent rod sprites (`@drawable/fishing_rod_0..15`, `D0.c`);
/// - Bottom control panel with `game_progress` tension bar (`0..250`), `game_current_bait` (`@drawable/btn_background` + `@drawable/bait_<id>`),
///   `game_time` (`@drawable/time_background`, `#EBB968`), `"У - X"` / `"К - Y"` durability labels,
///   `game_fishpond` (`@drawable/fishpond_small`), `game_backpack` (`@drawable/backpack_small`),
///   `game_cancel` (`@drawable/drop_me`), and the right-hand reel button `game_pull` (`@drawable/push_me` / `@drawable/push_me_on`).
public struct FishingPondView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var isBaitChooserPresented: Bool = false

    private let fightTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    private let gameClockTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    private static let goldTextColor = Color(red: 235.0 / 255.0, green: 185.0 / 255.0, blue: 104.0 / 255.0) // #EBB968

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            if let secondBg = OriginalGameAssetsLoader.image(named: "second_background") {
                secondBg
                    .resizable()
                    .ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                experienceTopBar
                pondInteractiveArea
                bottomGameControlsPanel
            }
        }
        .onReceive(fightTimer) { _ in
            if coordinator.stateMachine.state != .idle {
                coordinator.stepSimulationTick()
            }
        }
        .onReceive(gameClockTimer) { _ in
            coordinator.stepGameClockMinute()
        }
        .sheet(isPresented: $isBaitChooserPresented) {
            BaitQuickChooserSheet(coordinator: coordinator)
        }
    }

    // MARK: - 1. Top Experience Progress Bar (`pbExp` + `pbExpText`, `res/Ak.xml`)

    private var experienceTopBar: some View {
        let exp = coordinator.profile.experience
        let rank = coordinator.profile.category
        let thresholds = coordinator.balanceTables.categoryThresholds
        let prevThreshold: Int = (rank > 0 && rank - 1 < thresholds.count) ? thresholds[rank - 1] : 0
        let nextThreshold: Int = (rank < thresholds.count) ? thresholds[rank] : max(exp, 70_000_000)
        let span = max(1, nextThreshold - prevThreshold)
        let fraction = min(1.0, max(0.0, Double(exp - prevThreshold) / Double(span)))

        return ZStack {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.65))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.18, green: 0.55, blue: 0.22), Color(red: 0.32, green: 0.78, blue: 0.30)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                }
            }
            Text("\(exp) / \(nextThreshold) XP  •  Разряд \(rank)  •  \(coordinator.profile.balance) руб")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 1)
        }
        .frame(height: 16)
    }

    // MARK: - 2. Main Pond Area (`GameView` + Top Overlay Buttons `btPonds` & `top_menu`)

    private var pondInteractiveArea: some View {
        GeometryReader { geo in
            let w = max(320, Int(geo.size.width.rounded()))
            let h = max(240, Int(geo.size.height.rounded()))

            ZStack(alignment: .top) {
                // Layer 1: 3-pass Metal Water (`F0.n`) or 2D Pond Bitmap (`pond_<id>_big.png`)
                if coordinator.isWaterShaderActive {
                    MetalWaterSurfaceView(
                        isDayLight: coordinator.dayNightLighting.isDayLight,
                        pondIndex: coordinator.selectedPondIndex
                    )
                    .allowsHitTesting(false)
                } else {
                    static2DPondBackground
                }

                // Layer 2: Transparent 2D Canvas (`GameView.u()`: Ripples, Bobber `D0.a`, Bezier Line `D0.b`, 16-Frame Rod `D0.c`)
                Canvas { context, size in
                    // 2.1 Expanding oval water ripples (`D0.a.d(Canvas)`)
                    if let bobber = coordinator.stateMachine.bobber {
                        for oval in bobber.ripples {
                            let rect = CGRect(
                                x: CGFloat(oval.left),
                                y: CGFloat(oval.top),
                                width: CGFloat(max(2, oval.width)),
                                height: CGFloat(max(2, oval.height))
                            )
                            let path = Path(ellipseIn: rect)
                            let alpha = Double(oval.alpha(maxWidth: bobber.maxRippleWidth(canvasWidth: Int(size.width)))) / 255.0
                            context.stroke(path, with: .color(.white.opacity(alpha)), lineWidth: 2.0)
                        }

                        // 2.2 Bobber sprite (`@drawable/bobber` or `@drawable/bobber_hide` during bite/fight)
                        let bobberDrawableName = bobber.isBiteTexture ? "bobber_hide" : "bobber"
                        let bobberRect = CGRect(
                            x: CGFloat(bobber.x) - 14,
                            y: CGFloat(bobber.y) - 22,
                            width: 28,
                            height: 44
                        )
                        if let bobberImg = OriginalGameAssetsLoader.image(named: bobberDrawableName) {
                            let resolved = context.resolve(bobberImg)
                            context.draw(resolved, in: bobberRect)
                        } else {
                            let topHalf = CGRect(x: bobberRect.minX + 6, y: bobberRect.minY, width: 16, height: 18)
                            let bottomHalf = CGRect(x: bobberRect.minX + 6, y: bobberRect.minY + 18, width: 16, height: 18)
                            context.fill(Path(ellipseIn: topHalf), with: .color(bobber.isBiteTexture ? .orange : .red))
                            context.fill(Path(ellipseIn: bottomHalf), with: .color(.white))
                        }
                    }

                    // 2.3 Flexible 16-frame fishing rod (`D0.c`: `@drawable/fishing_rod_0..15`)
                    let rod = coordinator.stateMachine.rodSprite
                    let rodFrameName = "fishing_rod_\(min(15, max(0, rod.frameIndex)))"
                    let rodRect = CGRect(
                        x: CGFloat(rod.originX),
                        y: CGFloat(rod.originY),
                        width: CGFloat(rod.rodWidth),
                        height: CGFloat(rod.rodHeight)
                    )
                    if let rodImg = OriginalGameAssetsLoader.image(named: rodFrameName) {
                        let resolvedRod = context.resolve(rodImg)
                        context.draw(resolvedRod, in: rodRect)
                    } else {
                        let buttPoint = CGPoint(
                            x: CGFloat(rod.originX + rod.rodWidth * 0.85),
                            y: CGFloat(rod.originY + rod.rodHeight)
                        )
                        let tipNormalized = FishingLineGeometry.rodTipNormalizedOffsets[min(15, max(0, rod.frameIndex))]
                        let tipPoint = CGPoint(
                            x: CGFloat(rod.originX + rod.rodWidth * tipNormalized.x),
                            y: CGFloat(rod.originY + rod.rodHeight * tipNormalized.y)
                        )
                        let rodCtrl = CGPoint(
                            x: (buttPoint.x + tipPoint.x) * 0.55,
                            y: (buttPoint.y + tipPoint.y) * 0.45
                        )
                        var rodPath = Path()
                        rodPath.move(to: buttPoint)
                        rodPath.addQuadCurve(to: tipPoint, control: rodCtrl)
                        context.stroke(rodPath, with: .color(Color(red: 0.48, green: 0.30, blue: 0.14)), lineWidth: 5.0)
                    }

                    // 2.4 Quadratic Bezier fishing line (`D0.b`: `Path.quadTo`)
                    if let curve = coordinator.currentLineCurve {
                        var linePath = Path()
                        linePath.move(to: CGPoint(x: CGFloat(curve.startX), y: CGFloat(curve.startY)))
                        linePath.addQuadCurve(
                            to: CGPoint(x: CGFloat(curve.endX), y: CGFloat(curve.endY)),
                            control: CGPoint(x: CGFloat(curve.controlX), y: CGFloat(curve.controlY))
                        )
                        let alpha = Double(curve.alpha) / 255.0
                        context.stroke(
                            linePath,
                            with: .color(.white.opacity(alpha)),
                            lineWidth: CGFloat(curve.strokeWidth)
                        )
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            coordinator.updateViewportSize(width: w, height: h)
                            if coordinator.stateMachine.state == .idle {
                                coordinator.castAt(
                                    x: Float(value.location.x),
                                    y: Float(value.location.y)
                                )
                            }
                        }
                )

                // Layer 3: Top Overlay Bar (`btPonds` on left, Pond Title in center, `top_menu` on right — `res/Ak.xml`)
                HStack(alignment: .top, spacing: 8) {
                    // `btPonds` (`@drawable/pond_out` — return to Base / Pond List)
                    Button {
                        coordinator.resetCastToIdle()
                        coordinator.selectedTab = .baseHub
                    } label: {
                        OriginalSpriteOrFallbackIcon(
                            drawableName: "pond_out",
                            fallbackSystemName: "arrow.uturn.backward.square.fill",
                            width: 40,
                            height: 40
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Current Pond Name + Shader Toggle
                    HStack(spacing: 6) {
                        Text(localizedCurrentPondTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Self.goldTextColor)
                            .shadow(color: .black, radius: 2, x: 0, y: 1)

                        Button {
                            coordinator.isWaterShaderEnabled.toggle()
                        } label: {
                            Text(coordinator.isWaterShaderActive ? "GL Вода" : "2D Вода")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.55), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.45), in: Capsule())

                    Spacer()

                    // `top_menu` (`pond_chat_butt` `@drawable/tchat`, `btTasks` `@drawable/task_btn`, `btTours` `@drawable/tours_btn`)
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
                            coordinator.selectedTab = .progress
                        } label: {
                            OriginalSpriteOrFallbackIcon(
                                drawableName: "task_btn",
                                fallbackSystemName: "checklist",
                                width: 38,
                                height: 38
                            )
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
            .onAppear {
                coordinator.updateViewportSize(width: w, height: h)
            }
            .onChange(of: geo.size) { _, newSize in
                coordinator.updateViewportSize(
                    width: max(320, Int(newSize.width.rounded())),
                    height: max(240, Int(newSize.height.rounded()))
                )
            }
        }
    }

    private var static2DPondBackground: some View {
        let pondNumber = max(1, min(15, coordinator.selectedPondIndex + 1))
        return ZStack {
            if let pondImg = OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)_big")
                ?? OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)") {
                pondImg
                    .resizable()
                    .scaledToFill()
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
            if !coordinator.dayNightLighting.isDayLight {
                Color(
                    red: Double(coordinator.dayNightLighting.overlayRed) / 255.0,
                    green: Double(coordinator.dayNightLighting.overlayGreen) / 255.0,
                    blue: Double(coordinator.dayNightLighting.overlayBlue) / 255.0
                )
                .opacity(Double(coordinator.dayNightLighting.overlayAlpha) / 255.0)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 3. Authentic Bottom Controls Panel (`res/Ak.xml`: `game_progress`, `game_current_bait`, `game_time`, `game_fishpond`, `game_backpack`, `game_cancel`, `game_pull`)

    private var bottomGameControlsPanel: some View {
        let tension = coordinator.stateMachine.tension
        let tensionFraction = Double(min(250, max(0, tension))) / 250.0
        let tensionColor: Color = {
            if tension >= 225 { return .red }
            if tension >= 160 { return .orange }
            return .green
        }()

        let equippedBaitId = coordinator.assembledTackle.bait?.baitId ?? 0
        let equippedBaitCount = coordinator.assembledTackle.bait?.count ?? 0
        let rodStrength = coordinator.assembledTackle.rod?.strength ?? 0
        let coilStrength = coordinator.assembledTackle.coil?.strength ?? 0
        let isBitingOrPulling = coordinator.stateMachine.isPulled
            || (coordinator.stateMachine.state == .fishFight && coordinator.stateMachine.isPreHookBobbing)

        return HStack(alignment: .bottom, spacing: 8) {
            // Left area: `game_progress` bar + 2 rows of controls (`res/Ak.xml`)
            VStack(spacing: 4) {
                // `game_progress` (`max="225"` / `250`)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.65))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tensionColor)
                            .frame(width: geo.size.width * tensionFraction)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    }
                }
                .frame(height: 12)

                // Upper row: `game_current_bait`, `game_time`, `game_rod_strength` / `game_coil_strength`
                HStack(spacing: 8) {
                    // `game_current_bait` (`@drawable/btn_background` + `@drawable/bait_<id>`)
                    Button {
                        isBaitChooserPresented = true
                    } label: {
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

                            if equippedBaitCount > 0 {
                                Text("\(equippedBaitCount)")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 3)
                                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // `game_time` (`@drawable/time_background`, `#EBB968` gold text)
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
                        HStack(spacing: 6) {
                            Text(String(format: "%02d:%02d", coordinator.gameClock.hour, coordinator.gameClock.minute))
                                .font(.system(size: 17, weight: .bold).monospacedDigit())
                                .foregroundStyle(Self.goldTextColor)

                            if coordinator.stateMachine.state == .waitingForBite {
                                Button {
                                    coordinator.fastForwardToScheduledBite()
                                } label: {
                                    Text("⚡Клёв")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.orange, in: Capsule())
                                        .foregroundStyle(.black)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)

                    // `game_rod_strength` ("У - 100") & `game_coil_strength` ("К - 100")
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

                // Lower row: `game_fishpond`, `fish_count`, `game_backpack`, `game_cancel`
                HStack(spacing: 8) {
                    Button {
                        coordinator.selectedTab = .fishnet
                    } label: {
                        OriginalSpriteOrFallbackIcon(
                            drawableName: "fishpond_small",
                            fallbackSystemName: "basket.fill",
                            width: 44,
                            height: 38
                        )
                    }
                    .buttonStyle(.plain)

                    Text("\(coordinator.fishnetEntries.count)")
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 28, minHeight: 36)

                    Button {
                        coordinator.selectedTab = .inventory
                    } label: {
                        OriginalSpriteOrFallbackIcon(
                            drawableName: "backpack_small",
                            fallbackSystemName: "backpack.fill",
                            width: 44,
                            height: 38
                        )
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

                    if !coordinator.assembledTackle.isComplete {
                        Button {
                            coordinator.buyAndEquipStarterKit()
                        } label: {
                            Text("Собрать снасть")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Self.goldTextColor, in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Right column: `game_pull` (`@drawable/push_me` / `@drawable/push_me_on`, `98 x 112` pt)
            ZStack {
                let pullDrawable = isBitingOrPulling ? "push_me_on" : "push_me"
                OriginalSpriteOrFallbackIcon(
                    drawableName: pullDrawable,
                    fallbackSystemName: "arrow.triangle.2.circlepath.circle.fill",
                    width: 96,
                    height: 110
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if coordinator.stateMachine.state == .idle {
                            if !coordinator.assembledTackle.isComplete {
                                coordinator.buyAndEquipStarterKit()
                            }
                            coordinator.castAt(
                                x: Float(coordinator.stateMachine.viewWidth) * 0.5,
                                y: Float(coordinator.stateMachine.viewHeight) * 0.55
                            )
                        } else {
                            coordinator.setReelPulled(true)
                        }
                    }
                    .onEnded { _ in
                        coordinator.setReelPulled(false)
                    }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45))
    }

    private var localizedCurrentPondTitle: String {
        guard let pond = coordinator.currentPondItem else { return "Кедровый остров" }
        return coordinator.localeManager
            .localizedPondName(for: pond, fallbackIndex: coordinator.selectedPondIndex)
            .capitalized
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
                if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                    bg.resizable().ignoresSafeArea()
                } else {
                    Color(red: 0.10, green: 0.14, blue: 0.18).ignoresSafeArea()
                }

                if coordinator.ownedBaits.isEmpty {
                    VStack(spacing: 12) {
                        Text("В рюкзаке нет наживок")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Button("Купить стартовый набор") {
                            coordinator.buyAndEquipStarterKit()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(coordinator.ownedBaits) { item in
                                Button {
                                    coordinator.equipBait(rowId: item.id)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        OriginalSpriteOrFallbackIcon(
                                            drawableName: "bait_\(item.baitId)",
                                            fallbackSystemName: "circle.fill",
                                            width: 40,
                                            height: 40
                                        )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name.capitalized)
                                                .font(.headline)
                                                .foregroundStyle(Color(red: 235/255, green: 185/255, blue: 104/255))
                                            Text("Остаток: \(item.count) шт.")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.85))
                                        }
                                        Spacer()
                                        if coordinator.tackleSlots.baitId == item.id {
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
                        .padding(12)
                    }
                }
            }
            .navigationTitle("Выбор наживки")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
