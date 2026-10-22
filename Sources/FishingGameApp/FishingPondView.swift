import SwiftUI
import FishingCore
import FishingDatabase

/// Minimal working fishing screen (`GameActivity` + `GameView`) rendered with SwiftUI `Canvas`
/// (classic 2D mode without Metal shaders), displaying game state, horizon, water ripples,
/// bobber (`D0.a`), Bezier line (`D0.b`), 16-frame rod bend (`D0.c`), tension bar (`0..250`),
/// and player actions (tap to cast, hold to pull reel, fast-forward bite, reset cast).
public struct FishingPondView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    private let fightTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    private let gameClockTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            topStatusBar
            tensionLoadBar
            pondInteractiveCanvas
            bottomControlPanel
        }
        .background(Color.black)
        .onReceive(fightTimer) { _ in
            if coordinator.stateMachine.state != .idle {
                coordinator.stepSimulationTick()
            }
        }
        .onReceive(gameClockTimer) { _ in
            coordinator.stepGameClockMinute()
        }
    }

    // MARK: - 1. Top HUD Bar (`GameActivity` header)

    private var topStatusBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(coordinator.currentPondItem?.nameRu.capitalized ?? "Кедровый остров")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Image(systemName: coordinator.dayNightLighting.isDayLight ? "sun.max.fill" : "moon.stars.fill")
                        .foregroundStyle(coordinator.dayNightLighting.isDayLight ? .yellow : .cyan)
                    Text(String(format: "%02d:%02d", coordinator.gameClock.hour, coordinator.gameClock.minute))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.white)
                    Text("(\(timeOfDayLabel(coordinator.stateMachine.timeOfDay)))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 10) {
                    Label("\(coordinator.profile.balance)", systemImage: "bitcoinsign.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                    Label("Разряд \(coordinator.profile.category) (\(coordinator.profile.experience) XP)", systemImage: "star.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                HStack(spacing: 8) {
                    Text("Садок: \(coordinator.fishnetEntries.count)/\(PlayerStateRepository.maxFishnetCapacity)")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Состояние: \(stateLabel(coordinator.stateMachine.state))")
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.08, green: 0.14, blue: 0.22))
    }

    // MARK: - 2. Tension Load Progress Bar (`0x7f0a018d`, range `0..250`, critical `>= 225`)

    private var tensionLoadBar: some View {
        let tension = coordinator.stateMachine.tension
        let fraction = Double(min(250, max(0, tension))) / 250.0
        let barColor: Color = {
            if tension >= 225 { return .red }
            if tension >= 160 { return .orange }
            return .green
        }()

        return VStack(spacing: 3) {
            HStack {
                Text("Нагрузка на снасть: \(tension) / 250")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(tension >= 225 ? .red : .white)
                Spacer()
                Text("Изгиб удилища: кадр \(coordinator.stateMachine.rodSprite.frameIndex)/15")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.05, green: 0.09, blue: 0.15))
    }

    // MARK: - 3. Interactive 2D Pond Canvas (`GameView` without Metal shader)

    private var pondInteractiveCanvas: some View {
        GeometryReader { proxy in
            let canvasSize = proxy.size
            ZStack {
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    let horizonY = CGFloat(coordinator.stateMachine.horizonMinY)
                        * (h / CGFloat(max(1, coordinator.stateMachine.viewHeight)))

                    // 1. Sky / Distant Shore (Top ~20%..25%)
                    let skyRect = CGRect(x: 0, y: 0, width: w, height: horizonY)
                    context.fill(
                        Path(skyRect),
                        with: .linearGradient(
                            Gradient(colors: coordinator.dayNightLighting.isDayLight
                                ? [Color(red: 0.42, green: 0.68, blue: 0.92), Color(red: 0.22, green: 0.45, blue: 0.30)]
                                : [Color(red: 0.05, green: 0.07, blue: 0.18), Color(red: 0.08, green: 0.14, blue: 0.20)]
                            ),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: horizonY)
                        )
                    )

                    // 2. Water Surface (`horizonY .. h`)
                    let waterRect = CGRect(x: 0, y: horizonY, width: w, height: h - horizonY)
                    context.fill(
                        Path(waterRect),
                        with: .linearGradient(
                            Gradient(colors: coordinator.dayNightLighting.isDayLight
                                ? [Color(red: 0.10, green: 0.36, blue: 0.58), Color(red: 0.04, green: 0.18, blue: 0.34)]
                                : [Color(red: 0.03, green: 0.08, blue: 0.18), Color(red: 0.01, green: 0.04, blue: 0.11)]
                            ),
                            startPoint: CGPoint(x: 0, y: horizonY),
                            endPoint: CGPoint(x: 0, y: h)
                        )
                    )

                    // Horizon boundary line (`Y_cast > floor(H/5) + H_bobber`)
                    var horizonPath = Path()
                    horizonPath.move(to: CGPoint(x: 0, y: horizonY))
                    horizonPath.addLine(to: CGPoint(x: w, y: horizonY))
                    context.stroke(
                        horizonPath,
                        with: .color(.white.opacity(0.25)),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )

                    let scaleX = w / CGFloat(max(1, coordinator.stateMachine.viewWidth))
                    let scaleY = h / CGFloat(max(1, coordinator.stateMachine.viewHeight))

                    // 3. Expanding Water Ripples (`D0.a.d(Canvas)`)
                    if let bobber = coordinator.stateMachine.bobber {
                        for ripple in bobber.ripples {
                            let alphaInt = BobberState.rippleAlpha(
                                ovalWidth: ripple.width,
                                canvasWidth: coordinator.stateMachine.viewWidth
                            )
                            let alpha = Double(alphaInt) / 255.0
                            let rect = CGRect(
                                x: CGFloat(ripple.left) * scaleX,
                                y: CGFloat(ripple.top) * scaleY,
                                width: CGFloat(ripple.width) * scaleX,
                                height: CGFloat(ripple.height) * scaleY
                            )
                            context.stroke(
                                Path(ellipseIn: rect),
                                with: .color(.white.opacity(alpha)),
                                lineWidth: 2.0
                            )
                        }

                        // 4. Bobber Sprite (`D0.a.c(Canvas)`)
                        let bobX = CGFloat(bobber.x) * scaleX
                        let bobY = CGFloat(bobber.y) * scaleY
                        let bodyRect = CGRect(x: bobX - 7, y: bobY - 12, width: 14, height: 24)
                        context.fill(
                            Path(ellipseIn: bodyRect),
                            with: .color(bobber.isBiteTexture ? .red : .orange)
                        )
                        context.stroke(
                            Path(ellipseIn: bodyRect),
                            with: .color(.white),
                            lineWidth: 1.5
                        )
                    }

                    // 5. Quadratic Bezier Fishing Line (`D0.b.b(Canvas)`)
                    if let curve = coordinator.currentLineCurve {
                        var linePath = Path()
                        linePath.move(to: CGPoint(x: CGFloat(curve.start.x) * scaleX, y: CGFloat(curve.start.y) * scaleY))
                        linePath.addQuadCurve(
                            to: CGPoint(x: CGFloat(curve.end.x) * scaleX, y: CGFloat(curve.end.y) * scaleY),
                            control: CGPoint(x: CGFloat(curve.control.x) * scaleX, y: CGFloat(curve.control.y) * scaleY)
                        )
                        context.stroke(
                            linePath,
                            with: .color(.white.opacity(Double(curve.alpha) / 255.0)),
                            lineWidth: CGFloat(curve.strokeWidth)
                        )
                    }

                    // 6. Flexible Fishing Rod (`D0.c.a(Canvas)`, 16 bend frames `fishing_rod_0..15`)
                    let rod = coordinator.stateMachine.rodSprite
                    let buttPoint = CGPoint(
                        x: CGFloat(rod.originX + Float(rod.width)) * scaleX,
                        y: h
                    )
                    let tipPoint2D = FishingLineGeometry.rodTipPoint(for: rod)
                    let tipPoint = CGPoint(
                        x: CGFloat(tipPoint2D.x) * scaleX,
                        y: CGFloat(tipPoint2D.y) * scaleY
                    )
                    let midControl = CGPoint(
                        x: (buttPoint.x + tipPoint.x) * 0.55,
                        y: min(buttPoint.y, tipPoint.y) - CGFloat(rod.frameIndex) * 4.0
                    )
                    var rodPath = Path()
                    rodPath.move(to: buttPoint)
                    rodPath.addQuadCurve(to: tipPoint, control: midControl)
                    context.stroke(
                        rodPath,
                        with: .color(Color(red: 0.72, green: 0.52, blue: 0.24)),
                        style: StrokeStyle(lineWidth: 5.0, lineCap: .round)
                    )

                    // 7. Classic 2D Night Overlay (`#7800001E` when shader is off and `isDayLight == false`)
                    if !coordinator.dayNightLighting.isDayLight {
                        context.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(Color(red: 0.0, green: 0.0, blue: 0.12, opacity: 0.35))
                        )
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard coordinator.stateMachine.state == .idle else { return }
                            let logicalX = Float(value.location.x / max(1, canvasSize.width))
                                * Float(coordinator.stateMachine.viewWidth)
                            let logicalY = Float(value.location.y / max(1, canvasSize.height))
                                * Float(coordinator.stateMachine.viewHeight)
                            coordinator.castAt(x: logicalX, y: logicalY)
                        }
                )

                // Overlay helper banner when tackle is incomplete or waiting for cast
                VStack {
                    tackleSummaryBanner
                    Spacer()
                }
                .padding(10)
            }
            .onAppear {
                coordinator.updateViewportSize(
                    width: Int(max(320, canvasSize.width)),
                    height: Int(max(320, canvasSize.height))
                )
            }
        }
    }

    private var tackleSummaryBanner: some View {
        let tackle = coordinator.assembledTackle
        return HStack(spacing: 8) {
            if tackle.isComplete {
                Text("Уд: \(tackle.userRod?.rod.weight ?? 0)кг (\(tackle.userRod?.strength ?? 0)%)")
                Text("Леска: \(tackle.userLine?.line.weight ?? 0)кг (\(tackle.userLine?.length ?? 0)м)")
                Text("Кат: \(tackle.userCoil?.strength ?? 0)%")
                Text("Кр: \(tackle.userHook?.amount ?? 0)шт")
                Text("Наж: \(tackle.userBait?.bait.name ?? "") (\(tackle.userBait?.amount ?? 0))")
            } else {
                Text("⚠️ Снасть не собрана: \(tackle.missingComponentNames().joined(separator: ", "))")
                    .foregroundStyle(.yellow)
                Button("Купить и собрать стартовый набор") {
                    coordinator.buyAndEquipStarterKit()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .font(.caption2.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - 4. Bottom Player Action Controls

    private var bottomControlPanel: some View {
        HStack(spacing: 12) {
            switch coordinator.stateMachine.state {
            case .idle:
                Button {
                    let centerX = Float(coordinator.stateMachine.viewWidth) * 0.5
                    let castY = Float(coordinator.stateMachine.viewHeight) * 0.62
                    coordinator.castAt(x: centerX, y: castY)
                } label: {
                    Label("Забросить удочку", systemImage: "figure.fishing")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Text("Или коснитесь воды ниже линии горизонта")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))

            case .waitingForBite:
                Button {
                    coordinator.fastForwardToScheduledBite()
                } label: {
                    Label("Ждём поклёвку (Ускорить)", systemImage: "bolt.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(role: .destructive) {
                    coordinator.resetCastToIdle()
                } label: {
                    Label("Вытащить", systemImage: "xmark.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

            case .fishFight:
                // Hold-to-pull reel control (`GameActivity$s.onTouch` -> `GameView.setPulled`)
                Text(coordinator.stateMachine.isPulled ? "КАТУШКА: ТЯНЕМ!" : "УДЕРЖИВАЙТЕ КАТУШКУ")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        coordinator.stateMachine.isPulled ? Color.red : Color.green,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !coordinator.stateMachine.isPulled {
                                    coordinator.setReelPulled(true)
                                }
                            }
                            .onEnded { _ in
                                coordinator.setReelPulled(false)
                            }
                    )

                Button {
                    coordinator.setReelPulled(!coordinator.stateMachine.isPulled)
                } label: {
                    Text(coordinator.stateMachine.isPulled ? "Отпустить" : "Тянуть (Вкл)")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    coordinator.resetCastToIdle()
                } label: {
                    Text("Сброс")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

            default:
                Button {
                    coordinator.resetCastToIdle()
                } label: {
                    Label("Продолжить", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.14, blue: 0.22))
    }

    private func timeOfDayLabel(_ tod: BiteTimeOfDay) -> String {
        switch tod {
        case .morning: return "Утро"
        case .afternoon: return "День"
        case .evening: return "Вечер"
        case .night: return "Ночь"
        }
    }

    private func stateLabel(_ state: FishingState) -> String {
        switch state {
        case .idle: return "Покой"
        case .waitingForBite: return "Ожидание клёва"
        case .fishFight: return "Вываживание!"
        case .fishCaught: return "Улов!"
        case .missingTackleHold: return "Нет снасти"
        case .lineBroken: return "Обрыв лески"
        case .fishEscaped: return "Сход рыбы"
        case .rodBroken: return "Поломка удилища"
        case .coilBroken: return "Поломка катушки"
        case .alarmPermissionHold: return "Будильник"
        }
    }
}
