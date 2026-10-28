import SwiftUI
import FishingCore
import FishingDatabase

// MARK: - Shared Original Visual Theme Constants (`resources.arsc`)

private enum OriginalGameTheme {
    /// `@color/text_color` (`0xFFEBB968` — warm gold/amber text used across `MainActivity`, `GameActivity`, `Shop`, `Backpack`, `Fishpond`).
    static let goldText = Color(red: 235.0 / 255.0, green: 185.0 / 255.0, blue: 104.0 / 255.0)
    /// Record highlight red (`0xFFFF0000` in `C0.d.l()`).
    static let recordRed = Color(red: 1.0, green: 0.22, blue: 0.18)
    /// Repdigit weight highlight (`0x7f0600df` in `C0.d`).
    static let repdigitCyan = Color(red: 0.35, green: 0.92, blue: 1.0)
}

private enum RemasterHubPalette {
    static let bgTop = Color(red: 0.07, green: 0.10, blue: 0.13)
    static let bgMid = Color(red: 0.09, green: 0.13, blue: 0.16)
    static let bgBottom = Color(red: 0.11, green: 0.16, blue: 0.19)
    static let cardBg = Color(red: 0.11, green: 0.15, blue: 0.18)
    static let cardElevated = Color(red: 0.14, green: 0.19, blue: 0.23)
    static let stroke = Color.white.opacity(0.09)
    static let brass = Color(red: 0.87, green: 0.71, blue: 0.43)
    static let sage = Color(red: 0.34, green: 0.62, blue: 0.45)
    static let textPrimary = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let textSecondary = Color(red: 0.62, green: 0.68, blue: 0.73)
}

private struct RemasterModeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isRemasterMode: Bool {
        get { self[RemasterModeEnvironmentKey.self] }
        set { self[RemasterModeEnvironmentKey.self] = newValue }
    }
}

/// Pleasant tactile spring animation on every button press across the Remaster UI.
public struct RemasterSpringButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.04 : 0.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

/// Animated top toast notification banner with shimmer & quick-equip action when buying or equipping gear.
private struct RemasterPurchaseToastBannerView: View {
    let toast: RemasterToastNotification
    let onQuickEquip: () -> Void
    let onDismiss: () -> Void
    @State private var pulseScale: CGFloat = 0.85

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        toast.kind == .purchase
                            ? RemasterHubPalette.sage.opacity(0.24)
                            : RemasterHubPalette.brass.opacity(0.24)
                    )
                    .frame(width: 44, height: 44)
                    .scaleEffect(pulseScale)

                OriginalSpriteOrFallbackIcon(
                    drawableName: toast.drawableName,
                    fallbackSystemName: toast.fallbackSymbol,
                    width: 30,
                    height: 30
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(RemasterHubPalette.sage)
                    Text(toast.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                        .lineLimit(1)
                }
                Text(toast.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(RemasterHubPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if toast.quickEquipSlot != nil && toast.quickEquipRowId != nil {
                Button(action: {
                    onQuickEquip()
                    onDismiss()
                }) {
                    Text("Надеть")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(RemasterHubPalette.brass, in: Capsule())
                }
                .buttonStyle(RemasterSpringButtonStyle())
            } else {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RemasterHubPalette.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RemasterHubPalette.cardElevated,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) {
                pulseScale = 1.06
            }
        }
    }
}

/// Persistent Modern Bottom Navigation Dock for Remaster Mode so the player can switch between
/// Camp, Shop, Tackle, Fishnet, Journal, Online, and Pond in 1 tap with smooth spring animations.
private struct RemasterBottomNavigationDock: View {
    @ObservedObject var coordinator: FishingAppCoordinator

    var body: some View {
        HStack(spacing: 4) {
            dockTabButton(tab: .baseHub, icon: "house.fill", label: "Лагерь", badge: nil)
            dockTabButton(tab: .shop, icon: "storefront.fill", label: "Магазин", badge: nil)
            dockTabButton(tab: .inventory, icon: "backpack.fill", label: "Снасти", badge: nil)
            dockTabButton(
                tab: .fishnet,
                icon: "basket.fill",
                label: "Садок",
                badge: coordinator.fishnetEntries.isEmpty ? nil : "\(coordinator.fishnetEntries.count)"
            )
            dockTabButton(tab: .progress, icon: "trophy.fill", label: "Журнал", badge: nil)
            dockTabButton(tab: .online, icon: "globe", label: "Онлайн", badge: nil)

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                    coordinator.selectedTab = .fishingPond
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "figure.fishing")
                        .font(.system(size: 15, weight: .bold))
                    Text("Ловить")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(width: 54, height: 46)
                .background(RemasterHubPalette.brass, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(RemasterSpringButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RemasterHubPalette.bgTop.opacity(0.96),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: .black.opacity(0.42), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    private func dockTabButton(tab: AppNavigationTab, icon: String, label: String, badge: String?) -> some View {
        let isSelected = (coordinator.selectedTab == tab)
        return Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                coordinator.selectedTab = tab
            }
            coordinator.audioHaptics.playTouchClickHaptic()
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? RemasterHubPalette.brass : RemasterHubPalette.textSecondary)
                    Text(label)
                        .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? RemasterHubPalette.textPrimary : RemasterHubPalette.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    isSelected ? RemasterHubPalette.cardElevated : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(RemasterHubPalette.sage, in: Capsule())
                        .offset(x: -4, y: 3)
                }
            }
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }
}

/// Root container view replacing the generic iOS `TabView` with the authentic full-screen
/// screen switching of «Рыбалка для друзей» v1.81 (`SplashScreenActivity`, `MainActivity`, `PondListActivity`,
/// `GameActivity`, `ShopActivity`, `BackpackActivity`, `FishpondActivity`, `MyRecordsActivity`, `OnlineGameActivity`)
/// and the original `CatchDialog` (`C0.d`, `res/layout/catch_dialog.xml` `res/-w.xml`) overlay.
public struct FishingRootView: View {
    @StateObject private var coordinator: FishingAppCoordinator
    @State private var isShowingSplash: Bool
    @State private var gameLoopTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    public init(
        coordinator: FishingAppCoordinator? = nil,
        showSplashOnAppear: Bool = true
    ) {
        if let coordinator {
            _coordinator = StateObject(wrappedValue: coordinator)
        } else {
            let resolved = (try? AppBundleDatabaseBootstrapper.bootstrapAppCoordinator()) ?? (try! FishingAppCoordinator())
            _coordinator = StateObject(wrappedValue: resolved)
        }
        _isShowingSplash = State(initialValue: showSplashOnAppear)
    }

    public var body: some View {
        ZStack {
            if isShowingSplash {
                OriginalSplashScreenView(
                    versionString: FishingIOSAppConfiguration.marketingVersion
                ) {
                    finishSplashAndOpenMainHub()
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    activeScreenView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if coordinator.isRemasterModeEnabled && coordinator.selectedTab != .fishingPond {
                        RemasterBottomNavigationDock(coordinator: coordinator)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

            if coordinator.isRemasterModeEnabled, let toast = coordinator.activeToast {
                VStack {
                    RemasterPurchaseToastBannerView(
                        toast: toast,
                        onQuickEquip: {
                            coordinator.performQuickEquipFromToast(toast)
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                                coordinator.activeToast = nil
                            }
                        }
                    )
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.94)))
                .zIndex(20)
            }

            if let alert = coordinator.activeAlert {
                OriginalGameModalOverlay(
                    alert: alert,
                    questTaskBanner: coordinator.lastCatchQuestTaskBanner
                ) {
                    coordinator.activeAlert = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(30)
            }
        }
        .environment(\.isRemasterMode, coordinator.isRemasterModeEnabled)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: subScreen)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: coordinator.selectedTab)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: coordinator.activeToast?.id)
        .animation(.easeInOut(duration: 0.2), value: isShowingSplash)
        .animation(.easeInOut(duration: 0.15), value: coordinator.activeAlert?.id)
        .onReceive(gameLoopTimer) { _ in
            if !isShowingSplash {
                coordinator.stepRealtimeLoop()
            }
        }
    }

    private func finishSplashAndOpenMainHub() {
        guard isShowingSplash else { return }
        coordinator.selectedTab = .baseHub
        isShowingSplash = false
    }

    @ViewBuilder
    private var activeScreenView: some View {
        switch coordinator.selectedTab {
        case .fishingPond:
            FishingPondView(coordinator: coordinator)
        case .baseHub:
            BaseHubView(coordinator: coordinator)
        case .shop:
            ShopView(coordinator: coordinator)
        case .inventory:
            InventoryView(coordinator: coordinator)
        case .fishnet:
            FishnetView(coordinator: coordinator)
        case .progress:
            ProgressAndRecordsView(coordinator: coordinator)
        case .online:
            OnlineAndChatView(coordinator: coordinator)
        }
    }
}

// MARK: - 0A. Authentic `SplashScreenActivity` (`res/layout/splash.xml` `res/ym.xml`: `@drawable/screansaver` + `@id/splash_text`)

public struct OriginalSplashScreenView: View {
    public let versionString: String
    public let onFinish: () -> Void

    public init(
        versionString: String = "1.81",
        onFinish: @escaping () -> Void
    ) {
        self.versionString = versionString
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            splashArtworkBackground

            VStack(spacing: 6) {
                Text("Рыбалка для Друзей")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                    .shadow(color: .black, radius: 3, x: 0, y: 1)
                Text("Порт Android-версии на iOS • v\(versionString)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                ProgressView()
                    .tint(OriginalGameTheme.goldText)
                    .padding(.top, 2)
                Text("Загрузка...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                    .shadow(color: .black, radius: 3, x: 0, y: 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 36)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onFinish()
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            onFinish()
        }
    }

    @ViewBuilder
    private var splashArtworkBackground: some View {
        if let splashImg = OriginalGameAssetsLoader.image(named: "screansaver")
            ?? OriginalGameAssetsLoader.image(named: "background") {
            splashImg
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            Color(red: 0.06, green: 0.14, blue: 0.20)
                .ignoresSafeArea()
        }
    }
}

// MARK: - 0B. Authentic `CatchDialog` (`C0.d`, `res/-w.xml`) & Game Alert Modal Overlay

private struct OriginalGameModalOverlay: View {
    let alert: FishingModalAlert
    var questTaskBanner: String = ""
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.68)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            switch alert {
            case let .catchDialog(fish, result, isLucky25, isRepdigit, isCleanerTrash):
                CatchDialogModalCard(
                    fish: fish,
                    result: result,
                    isLucky25: isLucky25,
                    isRepdigit: isRepdigit,
                    isCleanerTrash: isCleanerTrash,
                    questTaskBanner: questTaskBanner,
                    onDismiss: onDismiss
                )
            default:
                StandardGameDialogModalCard(
                    title: alert.titleRu,
                    message: alert.messageRu,
                    onDismiss: onDismiss
                )
            }
        }
    }
}

private struct CatchDialogModalCard: View {
    let fish: CaughtUserFish
    let result: CatchTransactionResult
    let isLucky25: Bool
    let isRepdigit: Bool
    let isCleanerTrash: Bool
    var questTaskBanner: String = ""
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.45))
                    .frame(height: 120)
                OriginalSpriteOrFallbackIcon(
                    drawableName: "fish_\(fish.fish.id)",
                    fallbackSystemName: "fish.fill",
                    width: 180,
                    height: 110
                )
            }

            if result.isNewPersonalRecord || fish.weightGrams >= 5_000 {
                Text(result.isNewPersonalRecord ? "🏆 НОВЫЙ ЛИЧНЫЙ РЕКОРД!" : "✨ ТРОФЕЙНЫЙ ЭКЗЕМПЛЯР")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(result.isNewPersonalRecord ? Color.yellow : Color.cyan, in: Capsule())
            }

            Text(result.isNewPersonalRecord ? "\(fish.fish.name) (Рекорд!)" : fish.fish.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(result.isNewPersonalRecord ? OriginalGameTheme.recordRed : OriginalGameTheme.goldText)
                .multilineTextAlignment(.center)

            ZStack {
                Text("Вес: \(fish.weightGrams) г")
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(isRepdigit ? OriginalGameTheme.repdigitCyan : .white)

                if isLucky25 {
                    HStack {
                        Spacer()
                        OriginalSpriteOrFallbackIcon(
                            drawableName: "op25",
                            fallbackSystemName: "25.circle.fill",
                            width: 28,
                            height: 28
                        )
                    }
                    .padding(.trailing, 8)
                }
            }

            VStack(spacing: 4) {
                Text("Опыт: +\(result.experienceAwarded) (Разряд \(result.categoryRankAfter))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Text("Оценка: \(fish.sellingPriceCoins) руб  •  Садок: \(result.fishnetCountAfter)/\(PlayerStateRepository.maxFishnetCapacity)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                if isCleanerTrash {
                    Text("Вклад в достижение «Чистильщик»")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
                if !questTaskBanner.isEmpty {
                    Text(questTaskBanner)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.cyan)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }

            Button(action: onDismiss) {
                OriginalStyledActionButtonLabel(title: "ОК", minWidth: 120)
            }
            .buttonStyle(RemasterSpringButtonStyle())
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(OriginalModalCardBackground())
        .shadow(color: .black.opacity(0.8), radius: 14, x: 0, y: 6)
    }
}

private struct StandardGameDialogModalCard: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OriginalGameTheme.goldText)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Button(action: onDismiss) {
                OriginalStyledActionButtonLabel(title: "ОК", minWidth: 110)
            }
            .buttonStyle(RemasterSpringButtonStyle())
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(OriginalModalCardBackground())
        .shadow(color: .black.opacity(0.8), radius: 14, x: 0, y: 6)
    }
}

private struct OriginalModalCardBackground: View {
    @Environment(\.isRemasterMode) private var isRemasterMode

    var body: some View {
        if isRemasterMode {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RemasterHubPalette.cardElevated)
        } else {
            ZStack {
                if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                    bg.resizable()
                } else {
                    Color(red: 0.12, green: 0.16, blue: 0.20)
                }
                RoundedRectangle(cornerRadius: 12)
                    .stroke(OriginalGameTheme.goldText.opacity(0.8), lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Shared Original & Remaster Screen Header (`@drawable/sback_r` + `@drawable/info_background`)

private struct OriginalScreenTopBar: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let title: String
    let subtitle: String?
    let onBack: () -> Void

    init(title: String, subtitle: String? = nil, onBack: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
    }

    var body: some View {
        if isRemasterMode {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Назад")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(RemasterHubPalette.brass)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(RemasterHubPalette.cardElevated, in: Capsule())
                }
                .buttonStyle(RemasterSpringButtonStyle())

                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(RemasterHubPalette.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(RemasterHubPalette.brass)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(RemasterHubPalette.cardBg, in: Capsule())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
        } else {
            HStack(spacing: 10) {
                Button(action: onBack) {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "sback_r",
                        fallbackSystemName: "chevron.backward.square.fill",
                        width: 34,
                        height: 40
                    )
                }
                .buttonStyle(RemasterSpringButtonStyle())

                ZStack {
                    if let infoBg = OriginalGameAssetsLoader.image(named: "info_background") {
                        infoBg.resizable().frame(height: 42)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 42)
                    }
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(OriginalGameTheme.goldText)
                        if let subtitle {
                            Spacer()
                            Text(subtitle)
                                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }
}

private struct OriginalStyledActionButtonLabel: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let title: String
    var minWidth: CGFloat = 100

    var body: some View {
        if isRemasterMode {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(RemasterHubPalette.brass)
                .padding(.horizontal, 14)
                .frame(minWidth: minWidth, minHeight: 38, maxHeight: 38)
                .background(
                    RemasterHubPalette.cardElevated,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        } else {
            ZStack {
                if let btnBg = OriginalGameAssetsLoader.image(named: "btn_background") {
                    btnBg
                        .resizable()
                        .frame(minWidth: minWidth, minHeight: 38, maxHeight: 38)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.25, green: 0.20, blue: 0.14))
                        .frame(minWidth: minWidth, minHeight: 38, maxHeight: 38)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                    .padding(.horizontal, 14)
            }
        }
    }
}

private struct OriginalSecondBackgroundView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode

    var body: some View {
        if isRemasterMode {
            ZStack {
                LinearGradient(
                    colors: [
                        RemasterHubPalette.bgTop,
                        RemasterHubPalette.bgMid,
                        RemasterHubPalette.bgBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        RemasterHubPalette.sage.opacity(0.11),
                        RemasterHubPalette.brass.opacity(0.05),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 360
                )
            }
            .ignoresSafeArea()
        } else {
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }
        }
    }
}

// MARK: - 1. Authentic `MainActivity` (`res/layout/dashboard_ads.xml` `res/Yj.xml`) + `PondListActivity` (`res/Pa.xml`)

private enum BaseSubScreen: Equatable {
    case mainDashboard
    case pondListGrid
    case aboutMe
    case onlineShop
    case settings
    case aboutGame
}

public struct BaseHubView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var subScreen: BaseSubScreen = .mainDashboard

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Group {
            switch subScreen {
            case .mainDashboard:
                BaseDashboardSubView(coordinator: coordinator, subScreen: $subScreen)
            case .pondListGrid:
                PondListGridSubView(coordinator: coordinator, subScreen: $subScreen)
            case .aboutMe:
                AboutMeSubView(coordinator: coordinator, subScreen: $subScreen)
            case .onlineShop:
                OnlineShopSubView(coordinator: coordinator, subScreen: $subScreen)
            case .settings:
                SettingsSubView(coordinator: coordinator, subScreen: $subScreen)
            case .aboutGame:
                AboutGameSubView(coordinator: coordinator, subScreen: $subScreen)
            }
        }
        .environment(\.isRemasterMode, coordinator.isRemasterModeEnabled)
    }
}

// MARK: - 1.1 `MainActivity` (`res/Yj.xml` Classic Mode + Full Matte-Slate Remaster 2.0 Bento Dashboard)

private struct BaseDashboardSubView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen

    var body: some View {
        if coordinator.isRemasterModeEnabled {
            RemasterMainDashboardView(coordinator: coordinator, subScreen: $subScreen)
        } else {
            classicDashboardBody
        }
    }

    private var classicDashboardBody: some View {
        ZStack {
            dashboardBackground
            VStack(spacing: 8) {
                dashboardTopHeader
                dashboardGridScroll
                dashboardBottomInfoPlaque
            }
        }
    }

    @ViewBuilder
    private var dashboardBackground: some View {
        if let mainBg = OriginalGameAssetsLoader.image(named: "background") {
            mainBg
                .resizable()
                .ignoresSafeArea()
        } else {
            Color(red: 0.10, green: 0.18, blue: 0.14)
                .ignoresSafeArea()
        }
    }

    private var dashboardTopHeader: some View {
        ZStack {
            ZStack {
                if let timeBg = OriginalGameAssetsLoader.image(named: "time_background") {
                    timeBg
                        .resizable()
                        .frame(width: 190, height: 40)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.65))
                        .frame(width: 190, height: 40)
                }
                Text(String(format: "Время: %02d:%02d", coordinator.gameClock.hour, coordinator.gameClock.minute))
                    .font(.system(size: 16, weight: .bold).monospacedDigit())
                    .foregroundStyle(OriginalGameTheme.goldText)
            }

            HStack {
                Spacer()
                Button {
                    coordinator.selectedTab = .online
                } label: {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "tchat",
                        fallbackSystemName: "bubble.left.and.bubble.right.fill",
                        width: 56,
                        height: 32
                    )
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private var dashboardGridScroll: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                dashboardRow1
                dashboardRow2
                dashboardRow3
                dashboardRow4
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var dashboardRow1: some View {
        HStack(spacing: 12) {
            DashboardTileButton(drawable: "shop", fallbackIcon: "cart.fill", title: "Магазин") {
                coordinator.selectedTab = .shop
            }
            DashboardTileButton(drawable: "backpack", fallbackIcon: "backpack.fill", title: "Рюкзак") {
                coordinator.selectedTab = .inventory
            }
            DashboardTileButton(drawable: "pond", fallbackIcon: "water.waves", title: "Локации") {
                subScreen = .pondListGrid
            }
        }
    }

    private var dashboardRow2: some View {
        HStack(spacing: 12) {
            DashboardTileButton(drawable: "evaluation", fallbackIcon: "rublesign.circle.fill", title: "Продать рыбу") {
                if coordinator.fishnetEntries.isEmpty {
                    coordinator.activeAlert = .operationError(message: "Садок пуст")
                } else {
                    coordinator.sellAllFishInFishnet()
                }
            }
            DashboardTileButton(drawable: "fishpond", fallbackIcon: "basket.fill", title: "Садок (\(coordinator.fishnetEntries.count))") {
                coordinator.selectedTab = .fishnet
            }
            DashboardTileButton(drawable: "records", fallbackIcon: "trophy.fill", title: "Рекорды") {
                coordinator.selectedTab = .progress
            }
        }
    }

    private var dashboardRow3: some View {
        HStack(spacing: 12) {
            DashboardTileButton(drawable: "online", fallbackIcon: "globe", title: "Онлайн-игра") {
                coordinator.selectedTab = .online
            }
            DashboardTileButton(drawable: "about_me", fallbackIcon: "person.crop.rectangle.fill", title: "О себе") {
                subScreen = .aboutMe
            }
            DashboardTileButton(drawable: "on_shop", fallbackIcon: "sparkles", title: "Онлайн-магазин") {
                subScreen = .onlineShop
            }
        }
    }

    private var dashboardRow4: some View {
        HStack(spacing: 12) {
            DashboardTileButton(drawable: "settings", fallbackIcon: "gearshape.fill", title: "Настройки") {
                subScreen = .settings
            }
            DashboardTileButton(drawable: "about_game", fallbackIcon: "info.circle.fill", title: "Об игре") {
                coordinator.ensureEncyclopediaGuideLoaded()
                subScreen = .aboutGame
            }
            DashboardTileButton(drawable: "exit", fallbackIcon: "play.circle.fill", title: "На водоём") {
                coordinator.selectedTab = .fishingPond
            }
        }
    }

    private var dashboardBottomInfoPlaque: some View {
        ZStack(alignment: .leading) {
            if let infoBg = OriginalGameAssetsLoader.image(named: "info_background") {
                infoBg
                    .resizable()
                    .frame(height: 54)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.65))
                    .frame(height: 54)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Деньги: \(coordinator.profile.balance) руб")
                        .font(.system(size: 15, weight: .bold).monospacedDigit())
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text("Разряд: \(coordinator.profile.category)  (Опыт: \(coordinator.profile.experience))")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    coordinator.selectedTab = .fishingPond
                } label: {
                    OriginalStyledActionButtonLabel(title: "Ловить →", minWidth: 110)
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
            .padding(.horizontal, 14)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
}

/// Completely new, calm Matte-Slate & Warm-Brass Main Menu for Remaster Mode (inspired by *Russian Fishing 4* & modern iOS outdoor apps).
/// Contains zero 2013 parchment textures or orange square bitmaps; the Remaster switch lives strictly inside Settings.
private struct RemasterMainDashboardView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen

    private static let bgTop = Color(red: 21.0 / 255.0, green: 30.0 / 255.0, blue: 35.0 / 255.0)
    private static let bgBottom = Color(red: 13.0 / 255.0, green: 19.0 / 255.0, blue: 23.0 / 255.0)
    private static let cardFill = Color(red: 28.0 / 255.0, green: 37.0 / 255.0, blue: 44.0 / 255.0)
    private static let warmBrass = Color(red: 221.0 / 255.0, green: 180.0 / 255.0, blue: 109.0 / 255.0)
    private static let sageGreen = Color(red: 86.0 / 255.0, green: 158.0 / 255.0, blue: 114.0 / 255.0)

    private var rankProgressFraction: Double {
        let rank = coordinator.profile.category
        let thresholds = BalanceTables.playerRankExpThresholds
        let prev = (rank > 0 && (rank - 1) < thresholds.count) ? thresholds[rank - 1] : 0
        let next = (rank >= 0 && rank < thresholds.count) ? thresholds[rank] : max(coordinator.profile.experience, 70_000_000)
        let span = max(1, next - prev)
        return min(1.0, max(0.0, Double(coordinator.profile.experience - prev) / Double(span)))
    }

    private var currentPondTitle: String {
        guard let pond = coordinator.currentPondItem else { return "Кедровый Остров" }
        return coordinator.localeManager.pondName(for: pond).capitalized
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Self.bgTop, Self.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                remasterTopProfileHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        remasterPondHeroCard
                        remasterBentoGrid
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var remasterTopProfileHeader: some View {
        HStack(spacing: 10) {
            Button {
                subScreen = .aboutMe
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: CGFloat(rankProgressFraction))
                        .stroke(
                            Self.warmBrass,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 48, height: 48)
                    VStack(spacing: 0) {
                        Text("Ранг")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                        Text("\(coordinator.profile.category)")
                            .font(.system(size: 15, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Spacer()

            HStack(spacing: 6) {
                Text("\(coordinator.profile.balance) руб")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.95))
                Circle()
                    .fill(Self.warmBrass)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Text("₽")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Self.cardFill, in: Capsule())

            HStack(spacing: 5) {
                Image(systemName: coordinator.dayNightLighting.isDayLight ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Self.warmBrass)
                Text(String(format: "%02d:%02d", coordinator.gameClock.hour, coordinator.gameClock.minute))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Self.cardFill, in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private var remasterPondHeroCard: some View {
        let pondNum = max(1, min(15, coordinator.selectedPondIndex + 1))
        let rodKg = coordinator.assembledTackle.userRod?.rod.weight ?? 0
        let lineKg = coordinator.assembledTackle.userLine?.line.weight ?? 0
        let baitCount = coordinator.assembledTackle.userBait?.amount ?? 0

        return VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if let pondImg = OriginalGameAssetsLoader.image(named: "pond_\(pondNum)_big")
                    ?? OriginalGameAssetsLoader.image(named: "pond_\(pondNum)") {
                    pondImg
                        .resizable()
                        .scaledToFill()
                        .frame(height: 176)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Self.bgTop, Self.cardFill],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 176)
                }

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.05),
                        Self.cardFill.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 176)

                VStack(spacing: 10) {
                    Text(currentPondTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 4, x: 0, y: 2)
                        .padding(.top, 14)

                    Spacer()

                    HStack(spacing: 6) {
                        tackleStatPill(
                            icon: "figure.fishing",
                            text: rodKg > 0 ? "Удочка \(rodKg) кг" : "Нет удочки",
                            isReady: rodKg > 0,
                            highlightSage: true
                        )
                        tackleStatPill(
                            icon: "circle.dotted.circle",
                            text: lineKg > 0 ? "Леска \(lineKg) кг" : "Нет лески",
                            isReady: lineKg > 0,
                            highlightSage: false
                        )
                        tackleStatPill(
                            icon: "leaf.fill",
                            text: baitCount > 0 ? "Наживка \(baitCount)" : "Нет наживки",
                            isReady: baitCount > 0,
                            highlightSage: false
                        )

                        Button {
                            coordinator.equipBestOwnedTackle()
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Self.warmBrass)
                                .frame(width: 28, height: 26)
                                .background(Color.black.opacity(0.52), in: Capsule())
                        }
                        .buttonStyle(RemasterSpringButtonStyle())
                    }
                    .padding(.horizontal, 10)

                    Button {
                        coordinator.selectedTab = .fishingPond
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.fishing")
                                .font(.system(size: 15, weight: .bold))
                            Text("Начать рыбалку")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color(red: 0.10, green: 0.13, blue: 0.16))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Self.warmBrass, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .frame(height: 176)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tackleStatPill(
        icon: String,
        text: String,
        isReady: Bool,
        highlightSage: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isReady ? (highlightSage ? .white : Self.sageGreen) : .orange)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            isReady && highlightSage
                ? Self.sageGreen.opacity(0.88)
                : Color.black.opacity(0.52),
            in: Capsule()
        )
    }

    private var remasterBentoGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RemasterBentoCardButton(
                    icon: "map.fill",
                    iconColor: Self.sageGreen,
                    title: "Локации",
                    badgeText: "(\(coordinator.availablePonds.count))"
                ) {
                    subScreen = .pondListGrid
                }

                RemasterBentoCardButton(
                    icon: "storefront.fill",
                    iconColor: Self.warmBrass,
                    title: "Магазин",
                    badgeText: nil
                ) {
                    coordinator.selectedTab = .shop
                }
            }

            HStack(spacing: 10) {
                RemasterBentoCardButton(
                    icon: "backpack.fill",
                    iconColor: Self.warmBrass,
                    title: "Рюкзак и снасти",
                    badgeText: nil
                ) {
                    coordinator.selectedTab = .inventory
                }

                RemasterBentoCardButton(
                    icon: "basket.fill",
                    iconColor: Self.sageGreen,
                    title: "Садок",
                    badgeText: "(\(coordinator.fishnetEntries.count)/\(PlayerStateRepository.maxFishnetCapacity))"
                ) {
                    coordinator.selectedTab = .fishnet
                }
            }

            HStack(spacing: 10) {
                RemasterBentoCardButton(
                    icon: "book.closed.fill",
                    iconColor: Self.warmBrass,
                    title: "Квесты и Задания",
                    badgeText: coordinator.activeQuestForPlayer.map { "#\($0.id)" }
                ) {
                    coordinator.selectedProgressSection = .quests
                    coordinator.selectedTab = .progress
                }

                RemasterBentoCardButton(
                    icon: "trophy.fill",
                    iconColor: Self.warmBrass,
                    title: "Рекорды",
                    badgeText: nil
                ) {
                    coordinator.selectedProgressSection = .records
                    coordinator.selectedTab = .progress
                }
            }

            HStack(spacing: 10) {
                RemasterBentoCardButton(
                    icon: "flag.2.crossed.fill",
                    iconColor: Self.sageGreen,
                    title: "Онлайн и Турниры",
                    badgeText: nil
                ) {
                    coordinator.selectedTab = .online
                }

                RemasterBentoCardButton(
                    icon: "gearshape.fill",
                    iconColor: Self.warmBrass,
                    title: "Настройки",
                    badgeText: nil
                ) {
                    subScreen = .settings
                }
            }

            HStack(spacing: 8) {
                remasterCompactFooterButton(icon: "info.circle", title: "Энциклопедия рыб") {
                    coordinator.ensureEncyclopediaGuideLoaded()
                    subScreen = .aboutGame
                }
                remasterCompactFooterButton(icon: "person.text.rectangle", title: "Статистика") {
                    subScreen = .aboutMe
                }
                remasterCompactFooterButton(icon: "sparkles", title: "Онлайн-лавка") {
                    subScreen = .onlineShop
                }
            }
            .padding(.top, 2)
        }
    }

    private func remasterCompactFooterButton(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Self.warmBrass)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Self.cardFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }
}

private struct RemasterBentoCardButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let badgeText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let badgeText {
                        Text(badgeText)
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(
                Color(red: 28.0 / 255.0, green: 37.0 / 255.0, blue: 44.0 / 255.0),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }
}

private struct DashboardTileButton: View {
    let drawable: String
    let fallbackIcon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: drawable,
                    fallbackSystemName: fallbackIcon,
                    width: 74,
                    height: 74
                )
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                    .shadow(color: .black, radius: 2, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }
}

// MARK: - 1.2 `PondListActivity` (`res/layout/gridview.xml` `res/Pa.xml` + `cellgrid.xml` `res/iy.xml`)

private struct PondListGridSubView: View {
    public enum PondFilter: String, CaseIterable, Identifiable {
        case all = "Все (15)"
        case unlocked = "Доступные"
        case coupon = "По купону"

        public var id: String { rawValue }
    }

    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen
    @State private var selectedFilter: PondFilter = .all

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private func isPondUnlocked(_ pond: PondCatalogItem) -> Bool {
        coordinator.profile.category >= pond.requiredRank
            && (!pond.requiresCoupon || coordinator.activeCoupon != nil)
    }

    private var filteredPonds: [PondCatalogItem] {
        coordinator.availablePonds.filter { pond in
            switch selectedFilter {
            case .all:
                return true
            case .unlocked:
                return isPondUnlocked(pond)
            case .coupon:
                return pond.requiresCoupon
            }
        }
    }

    var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: coordinator.isRemasterModeEnabled ? "Атлас локаций" : "Выбор водоёма (Локации)",
                    subtitle: "Разряд \(coordinator.profile.category)"
                ) {
                    subScreen = .mainDashboard
                }

                if coordinator.isRemasterModeEnabled {
                    remasterLocationsExplorerBody
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(coordinator.availablePonds, id: \.id) { pond in
                                PondGridCellView(
                                    pond: pond,
                                    localizedName: coordinator.localeManager.pondName(for: pond).capitalized,
                                    isSelected: coordinator.selectedPondIndex == pond.id,
                                    isUnlocked: isPondUnlocked(pond)
                                ) {
                                    coordinator.selectPond(pondIndex: pond.id)
                                    if coordinator.selectedPondIndex == pond.id {
                                        subScreen = .mainDashboard
                                        coordinator.selectedTab = .fishingPond
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    private var remasterLocationsExplorerBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Featured Selected Location Expedition Card
                if let currentPond = coordinator.currentPondItem {
                    let pondNum = max(1, min(15, currentPond.id + 1))
                    let pondTitle = coordinator.localeManager.pondName(for: currentPond).capitalized

                    ZStack(alignment: .bottomLeading) {
                        if let img = OriginalGameAssetsLoader.image(named: "pond_\(pondNum)_big")
                            ?? OriginalGameAssetsLoader.image(named: "pond_\(pondNum)") {
                            img.resizable()
                                .scaledToFill()
                                .frame(height: 148)
                                .clipped()
                        } else {
                            RemasterHubPalette.cardElevated.frame(height: 148)
                        }

                        LinearGradient(
                            colors: [Color.black.opacity(0.10), Color.black.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 148)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("ТЕКУЩАЯ ЭКСПЕДИЦИЯ • #\(pondNum)")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.brass)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.55), in: Capsule())

                                if currentPond.id == 0 {
                                    Text("✨ 2.5D ВОДА И ПАРАЛЛАКС")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(RemasterHubPalette.sage, in: Capsule())
                                }
                            }

                            Spacer()

                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pondTitle)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Мин. разряд: \(currentPond.requiredRank)  •  \(currentPond.requiresCoupon ? "Требуется купон" : "Свободный доступ")")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                                Spacer()
                                Button {
                                    subScreen = .mainDashboard
                                    coordinator.selectedTab = .fishingPond
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "figure.fishing")
                                        Text("Ловить")
                                    }
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(RemasterHubPalette.brass, in: Capsule())
                                }
                                .buttonStyle(RemasterSpringButtonStyle())
                            }
                        }
                        .padding(14)
                        .frame(height: 148)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // 2. Filter Segmented Bar
                HStack(spacing: 8) {
                    ForEach(PondFilter.allCases) { filter in
                        let isSel = (selectedFilter == filter)
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(isSel ? .black : RemasterHubPalette.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    isSel ? RemasterHubPalette.brass : RemasterHubPalette.cardBg,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(RemasterSpringButtonStyle())
                    }
                }

                // 3. 2-Column Expedition Atlas Grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredPonds, id: \.id) { pond in
                        PondGridCellView(
                            pond: pond,
                            localizedName: coordinator.localeManager.pondName(for: pond).capitalized,
                            isSelected: coordinator.selectedPondIndex == pond.id,
                            isUnlocked: isPondUnlocked(pond)
                        ) {
                            coordinator.selectPond(pondIndex: pond.id)
                            if coordinator.selectedPondIndex == pond.id {
                                subScreen = .mainDashboard
                                coordinator.selectedTab = .fishingPond
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }
}

private struct PondGridCellView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let pond: PondCatalogItem
    let localizedName: String
    let isSelected: Bool
    let isUnlocked: Bool
    let onSelect: () -> Void

    var body: some View {
        let pondNumber = max(1, min(15, pond.id + 1))
        let badgeText = pond.requiresCoupon ? "Разр. \(pond.requiredRank) • Купон" : "Разр. \(pond.requiredRank)"

        if isRemasterMode {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        pondThumbnail(pondNumber: pondNumber)
                            .overlay(
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        HStack(spacing: 4) {
                            Image(systemName: isUnlocked ? (isSelected ? "checkmark.circle.fill" : "lock.open.fill") : "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (isUnlocked ? (isSelected ? RemasterHubPalette.sage : Color.black.opacity(0.72)) : Color.red.opacity(0.80)),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                        .padding(8)
                    }

                    HStack(spacing: 6) {
                        Text("#\(pondNumber)")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(RemasterHubPalette.brass)
                        Text(localizedName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if isSelected {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(RemasterHubPalette.sage)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(isSelected ? RemasterHubPalette.cardElevated : RemasterHubPalette.cardBg)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(isUnlocked ? 1.0 : 0.65)
            }
            .buttonStyle(RemasterSpringButtonStyle())
        } else {
            let badgeBg = isUnlocked ? Color.black.opacity(0.7) : Color.red.opacity(0.85)
            let strokeColor = isSelected ? Color.green : OriginalGameTheme.goldText.opacity(0.8)
            let strokeWidth: CGFloat = isSelected ? 2.5 : 1.5

            Button(action: onSelect) {
                VStack(spacing: 6) {
                    ZStack(alignment: .topTrailing) {
                        pondThumbnail(pondNumber: pondNumber)
                        Text(badgeText)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeBg, in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.white)
                            .padding(4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )

                    Text(localizedName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                        .lineLimit(1)
                }
            }
            .buttonStyle(RemasterSpringButtonStyle())
        }
    }

    @ViewBuilder
    private func pondThumbnail(pondNumber: Int) -> some View {
        if let img = OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)")
            ?? OriginalGameAssetsLoader.image(named: "pond_\(pondNumber)_big") {
            img
                .resizable()
                .scaledToFill()
                .frame(height: 98)
                .clipped()
        } else {
            Rectangle()
                .fill(Color.teal.opacity(0.4))
                .frame(height: 98)
        }
    }
}

// MARK: - 1.3 `AboutMeActivity` (`res/layout/about_me.xml` `res/MT.xml`)

private struct AboutMeSubView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen

    private var expToNextRank: Int {
        let exp = coordinator.profile.experience
        let rank = coordinator.profile.category
        let thresholds = BalanceTables.playerRankExpThresholds
        let nextThreshold: Int = (rank >= 0 && rank < thresholds.count) ? thresholds[rank] : exp
        return max(0, nextThreshold - exp)
    }

    private var couponStatusText: String {
        if let coupon = coordinator.activeCoupon {
            return "\(coupon.remainingTimeUnits) ед."
        }
        return "нет"
    }

    private var rankProgressFraction: Double {
        let rank = coordinator.profile.category
        let thresholds = BalanceTables.playerRankExpThresholds
        let prev = (rank > 0 && (rank - 1) < thresholds.count) ? thresholds[rank - 1] : 0
        let next = (rank >= 0 && rank < thresholds.count) ? thresholds[rank] : max(coordinator.profile.experience, 70_000_000)
        let span = max(1, next - prev)
        return min(1.0, max(0.0, Double(coordinator.profile.experience - prev) / Double(span)))
    }

    var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 10) {
                OriginalScreenTopBar(
                    title: coordinator.isRemasterModeEnabled ? "Карточка рыболова" : "О себе",
                    subtitle: "Разряд \(coordinator.profile.category)"
                ) {
                    subScreen = .mainDashboard
                }

                if coordinator.isRemasterModeEnabled {
                    remasterAnglerLicenseBody
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            profileStatsBlock
                            navigationShortcutsBlock
                        }
                        .padding(18)
                        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 14)
                    }
                }
            }
        }
    }

    private var remasterAnglerLicenseBody: some View {
        let caughtSpeciesCount = coordinator.personalRecords.filter { $0.weightGrams > 0 }.count
        let completedQuestsCount = coordinator.quests.filter { $0.made >= 2 }.count
        let unlockedAchCount = coordinator.achievements.filter { $0.level > 0 }.count

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // 1. Angler License ID & XP Bar Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.28))
                                .frame(width: 60, height: 60)
                            Image(systemName: "figure.fishing")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(RemasterHubPalette.brass)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(coordinator.profile.login.isEmpty ? "Рыболов-мастер" : coordinator.profile.login)
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Text("Разряд \(coordinator.profile.category)  •  Всего опыта: \(coordinator.profile.experience) XP")
                                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.brass)
                            Text("До следующего разряда: \(expToNextRank) XP")
                                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                        }
                        Spacer()
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.35))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [RemasterHubPalette.sage, RemasterHubPalette.brass],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * rankProgressFraction))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(14)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                // 2. 2x2 Career Metrics Grid
                HStack(spacing: 10) {
                    careerMetricCard(icon: "rublesign.circle.fill", label: "Баланс", value: "\(coordinator.profile.balance) ₽", color: RemasterHubPalette.brass)
                    careerMetricCard(icon: "ticket.fill", label: "Путевой купон", value: couponStatusText, color: RemasterHubPalette.sage)
                }
                HStack(spacing: 10) {
                    careerMetricCard(icon: "fish.fill", label: "Открыто видов", value: "\(caughtSpeciesCount) / 141", color: RemasterHubPalette.sage)
                    careerMetricCard(icon: "trophy.fill", label: "Квесты • Медали", value: "\(completedQuestsCount)/44 • \(unlockedAchCount)/14", color: RemasterHubPalette.brass)
                }

                // 3. Quick Journal & Encyclopedia Tiles
                VStack(spacing: 8) {
                    remasterNavRow(icon: "book.closed.fill", title: "Сюжетные квесты (44)", subtitle: "Цели, награды и прогресс кампании") {
                        subScreen = .mainDashboard
                        coordinator.selectedProgressSection = .quests
                        coordinator.selectedTab = .progress
                    }
                    remasterNavRow(icon: "checklist", title: "Поручения рыбака", subtitle: "Динамические контракты на опыт") {
                        subScreen = .mainDashboard
                        coordinator.selectedProgressSection = .tasks
                        coordinator.selectedTab = .progress
                    }
                    remasterNavRow(icon: "medal.fill", title: "Зал достижений (14)", subtitle: "Бронзовые, серебряные и золотые кубки") {
                        subScreen = .mainDashboard
                        coordinator.selectedProgressSection = .achievements
                        coordinator.selectedTab = .progress
                    }
                    remasterNavRow(icon: "trophy.circle.fill", title: "Коллекция рекордов (141 вид)", subtitle: "Ваши максимальные трофеи по каждому виду") {
                        subScreen = .mainDashboard
                        coordinator.selectedProgressSection = .records
                        coordinator.selectedTab = .progress
                    }
                    remasterNavRow(icon: "books.vertical.fill", title: "Энциклопедия рыб, водоёмов и FAQ", subtitle: "Где, на что и в какое время суток клюёт") {
                        coordinator.ensureEncyclopediaGuideLoaded()
                        subScreen = .aboutGame
                    }
                    remasterNavRow(icon: "person.badge.key.fill", title: "Онлайн-профиль и синхронизация", subtitle: "Облачное сохранение, чат и турниры") {
                        subScreen = .mainDashboard
                        coordinator.selectedTab = .online
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    private func careerMetricCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(RemasterHubPalette.textSecondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(RemasterHubPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func remasterNavRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(RemasterHubPalette.brass)
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RemasterHubPalette.textSecondary)
            }
            .padding(12)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }

    private var profileStatsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Имя: \(coordinator.profile.login.isEmpty ? "Рыболов" : coordinator.profile.login)")
            Text("Деньги: \(coordinator.profile.balance) руб")
            Text("Разряд: \(coordinator.profile.category)")
            Text("Опыт: \(coordinator.profile.experience)")
            Text("До следующего разряда: \(expToNextRank)")
            Text("Купон: \(couponStatusText)")
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(OriginalGameTheme.goldText)
    }

    private var navigationShortcutsBlock: some View {
        VStack(spacing: 10) {
            Button {
                subScreen = .mainDashboard
                coordinator.selectedTab = .online
            } label: {
                OriginalStyledActionButtonLabel(title: "Аккаунт / Профиль", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                subScreen = .mainDashboard
                coordinator.selectedProgressSection = .quests
                coordinator.selectedTab = .progress
            } label: {
                OriginalStyledActionButtonLabel(title: "Квесты (44 сюжетных квеста)", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                subScreen = .mainDashboard
                coordinator.selectedProgressSection = .tasks
                coordinator.selectedTab = .progress
            } label: {
                OriginalStyledActionButtonLabel(title: "Задание (Поручения рыбака)", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                subScreen = .mainDashboard
                coordinator.selectedProgressSection = .achievements
                coordinator.selectedTab = .progress
            } label: {
                OriginalStyledActionButtonLabel(title: "Достижения (14)", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                subScreen = .mainDashboard
                coordinator.selectedProgressSection = .records
                coordinator.selectedTab = .progress
            } label: {
                OriginalStyledActionButtonLabel(title: "Личные рекорды (141 вид)", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                coordinator.ensureEncyclopediaGuideLoaded()
                subScreen = .aboutGame
            } label: {
                OriginalStyledActionButtonLabel(title: "Гайд по рыбам, водоёмам и FAQ", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }
}

// MARK: - 1.4 `OnlineShopActivity` (`res/layout/online_shop.xml` `res/73.xml`)

private struct OnlineShopSubView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen

    var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: "Онлайн-магазин",
                    subtitle: "Жемчуг: \(coordinator.onlineShopSnapshot?.pearlsBalance ?? 0)"
                ) {
                    subScreen = .mainDashboard
                }

                ScrollView {
                    VStack(spacing: 10) {
                        Button {
                            coordinator.refreshOnlineShopLive()
                        } label: {
                            OriginalStyledActionButtonLabel(title: "Обновить каталог", minWidth: 260)
                        }
                        .buttonStyle(RemasterSpringButtonStyle())

                        if !coordinator.lastOnlineStatusMessage.isEmpty {
                            Text(coordinator.lastOnlineStatusMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.cyan)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }

                        if let snap = coordinator.onlineShopSnapshot {
                            ForEach(0..<min(3, snap.onlineRodWeightsKg.count), id: \.self) { idx in
                                OnlineShopRodRowView(
                                    rodNumber: idx + 11,
                                    weightKg: snap.onlineRodWeightsKg[idx],
                                    pearlPrice: snap.onlineRodPearlPrices[idx]
                                )
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .onAppear {
            if coordinator.onlineShopSnapshot == nil {
                syncDemoCatalog()
            }
        }
    }

    private func syncDemoCatalog() {
        var tokens: [String] = []
        for idx in 0..<37 {
            switch idx {
            case 0: tokens.append("250")
            case 1, 2, 3: tokens.append("\(525 + (idx - 1) * 600)")
            case 4, 5, 6: tokens.append("\(45 + (idx - 4) * 35)")
            case 7, 8, 9: tokens.append("\(10 + (idx - 7) * 2)")
            case 10, 11, 12: tokens.append("\(30 + (idx - 10) * 20)")
            case 13, 14, 15: tokens.append("\(600 + (idx - 13) * 700)")
            case 16, 17, 18: tokens.append("250")
            case 19, 20, 21: tokens.append("\(25 + (idx - 19) * 15)")
            case 30...36: tokens.append("\((idx - 29) * 10)")
            default: tokens.append("0")
            }
        }
        let sampleCSV = tokens.joined(separator: ",") + ",note=1"
        _ = try? coordinator.syncOnlineShopFromCSV(sampleCSV)
    }
}

private struct OnlineShopRodRowView: View {
    let rodNumber: Int
    let weightKg: Int
    let pearlPrice: Int

    var body: some View {
        HStack {
            OriginalSpriteOrFallbackIcon(
                drawableName: "fishing_rods",
                fallbackSystemName: "wand.and.rays",
                width: 42,
                height: 42
            )
            VStack(alignment: .leading) {
                Text("Онлайн-удилище #\(rodNumber)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Text("Мощность: \(weightKg) кг")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("\(pearlPrice) жемч.")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.cyan)
        }
        .padding(10)
        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 1.5 `SettingsActivity` (`res/layout/settings.xml` `res/yp.xml`)

private struct SettingsSubView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen

    var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 10) {
                OriginalScreenTopBar(title: "Настройки") {
                    subScreen = .mainDashboard
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Group 1: Remaster Mode & Atmosphere
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ВИЗУАЛ И РЕЖИМ ИГРЫ")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.brass)

                            Toggle("✨ Режим «Ремастер» (современный UI и 2.5D)", isOn: $coordinator.isRemasterModeEnabled)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                                .tint(RemasterHubPalette.sage)

                            Text("Переключает всю игру между переосмысленным современным интерфейсом (с 2.5D-сценой на первой локации, процедурным спиннингом, шкалами снасти и эхолотом) и классическим видом Android v1.81.")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)

                            if coordinator.isRemasterModeEnabled {
                                Toggle("Встроенный эхолот и радар клёва", isOn: $coordinator.isSonarRadarVisible)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.textPrimary)
                                    .tint(RemasterHubPalette.sage)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Погода на водоёме")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(RemasterHubPalette.textSecondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(RemasterWeatherKind.allCases) { kind in
                                                let isSel = (coordinator.remasterWeatherPreference == kind)
                                                Button {
                                                    coordinator.remasterWeatherPreference = kind
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: kind.symbolName)
                                                            .font(.system(size: 11, weight: .bold))
                                                        Text(kind.titleRu)
                                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    }
                                                    .foregroundStyle(isSel ? .black : RemasterHubPalette.textPrimary)
                                                    .padding(.horizontal, 11)
                                                    .padding(.vertical, 7)
                                                    .background(
                                                        isSel ? RemasterHubPalette.brass : RemasterHubPalette.cardElevated,
                                                        in: Capsule()
                                                    )
                                                }
                                                .buttonStyle(RemasterSpringButtonStyle())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // Group 2: Audio, Haptics & Water Shader
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ЗВУК, ОТДАЧА И ГЕЙМПЛЕЙ")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.brass)

                            Toggle("Анимация воды (Metal шейдер)", isOn: $coordinator.isWaterShaderEnabled)
                            Toggle("Звуковые эффекты и атмосфера", isOn: $coordinator.audioHaptics.soundEnabled)
                            Toggle("Тактильная отдача (Haptics)", isOn: $coordinator.audioHaptics.vibrationEnabled)
                            Toggle("Квесты и поручения рыбака", isOn: $coordinator.tasksEnabled)
                            Toggle("Уведомление о поклёвке в фоне", isOn: $coordinator.checkModeEnabled)
                            Toggle("Онлайн-синхронизация", isOn: $coordinator.onlineModeEnabled)
                            Toggle("Панель разработчика (DEV)", isOn: $coordinator.isDebugOverlayEnabled)
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                        .tint(RemasterHubPalette.sage)
                        .padding(14)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // Group 3: Language & About
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Язык интерфейса")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.textPrimary)
                                Spacer()
                                Picker("Язык", selection: $coordinator.languageCode) {
                                    ForEach(FishingLanguage.allCases, id: \.rawValue) { lang in
                                        Text(lang.displayName).tag(lang.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(RemasterHubPalette.brass)
                            }

                            HStack {
                                Text("Рыбалка для Друзей • iOS Edition")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.brass)
                                Spacer()
                                Text("База v1.81 • Remaster 3.0")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}


// MARK: - 1.6 `AboutGameActivity` (`res/layout/about_game.xml` `res/o-.xml` + Fish & Pond Encyclopedia Guide)

private struct AboutGameSubView: View {
    public enum GuideTab: String, CaseIterable, Identifiable {
        case fishes = "Рыбы (141)"
        case ponds = "Водоёмы (15)"
        case faq = "FAQ (17)"

        public var id: String { rawValue }
    }

    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen
    @State private var selectedTab: GuideTab = .fishes
    @State private var searchText: String = ""
    @State private var selectedPondFilter: Int = -1 // -1 = all ponds
    @State private var expandedFishIds: Set<Int> = []
    @State private var expandedPondIds: Set<Int> = [0]
    @State private var expandedFaqIds: Set<Int> = [0]

    private var recordWeightByFishId: [Int: Int] {
        var map: [Int: Int] = [:]
        for r in coordinator.personalRecords {
            map[r.id] = r.weightGrams
        }
        return map
    }

    private var filteredFishes: [FishEncyclopediaGuideEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return coordinator.fishEncyclopediaGuide.filter { entry in
            let matchesPond = (selectedPondFilter < 0) || entry.habitats.contains(where: { $0.pondId == selectedPondFilter })
            guard matchesPond else { return false }
            if query.isEmpty { return true }
            if entry.fish.name.lowercased().contains(query) { return true }
            return entry.habitats.contains(where: {
                $0.pondNameRu.lowercased().contains(query)
                    || $0.baits.contains(where: { $0.baitName.lowercased().contains(query) })
            })
        }
    }

    var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: "Об игре и Энциклопедия",
                    subtitle: "v1.81 • iOS"
                ) {
                    subScreen = .mainDashboard
                }

                guideTabPicker

                switch selectedTab {
                case .fishes:
                    fishesGuideSection
                case .ponds:
                    pondsGuideSection
                case .faq:
                    faqGuideSection
                }
            }
        }
        .onAppear {
            coordinator.ensureEncyclopediaGuideLoaded()
        }
    }

    private var guideTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(GuideTab.allCases) { tab in
                let isSel = (selectedTab == tab)
                Button {
                    selectedTab = tab
                } label: {
                    if coordinator.isRemasterModeEnabled {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(isSel ? .black : RemasterHubPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSel ? RemasterHubPalette.brass : RemasterHubPalette.cardBg, in: Capsule())
                    } else {
                        OriginalStyledActionButtonLabel(title: tab.rawValue, minWidth: 96)
                            .opacity(isSel ? 1.0 : 0.65)
                    }
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
        }
        .padding(.horizontal, 12)
    }

    private var fishesGuideSection: some View {
        VStack(spacing: 8) {
            VStack(spacing: 6) {
                TextField("Поиск рыбы, водоёма или наживки...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Фильтр по водоёму:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Spacer()
                    Picker("Водоём", selection: $selectedPondFilter) {
                        Text("Все водоёмы (\(coordinator.fishEncyclopediaGuide.count))").tag(-1)
                        ForEach(coordinator.availablePonds, id: \.id) { pond in
                            Text("#\(pond.id + 1) \(coordinator.localeManager.pondName(for: pond))").tag(pond.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 10)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredFishes) { entry in
                        FishGuideCardView(
                            entry: entry,
                            personalRecordGrams: recordWeightByFishId[entry.id] ?? 0,
                            isExpanded: expandedFishIds.contains(entry.id),
                            onToggleExpand: {
                                if expandedFishIds.contains(entry.id) {
                                    expandedFishIds.remove(entry.id)
                                } else {
                                    expandedFishIds.insert(entry.id)
                                }
                            }
                        )
                    }
                }
                .padding(10)
            }
        }
    }

    private var pondsGuideSection: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(coordinator.pondEncyclopediaGuide) { pondEntry in
                    PondGuideCardView(
                        entry: pondEntry,
                        localizedPondName: coordinator.localeManager.pondName(for: pondEntry.pond),
                        isExpanded: expandedPondIds.contains(pondEntry.id),
                        onToggleExpand: {
                            if expandedPondIds.contains(pondEntry.id) {
                                expandedPondIds.remove(pondEntry.id)
                            } else {
                                expandedPondIds.insert(pondEntry.id)
                            }
                        }
                    )
                }
            }
            .padding(10)
        }
    }

    private var faqGuideSection: some View {
        let faqItems = coordinator.localeManager.aboutGameFaqItems(versionString: "1.81")
        return ScrollView {
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("Рыбалка для Друзей")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text("Версия 1.81 • Порт Android-версии на iOS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.cyan)
                    Text("База данных: 141 вид рыб • 15 водоёмов • 21 наживка • 44 сюжетных квеста • 14 достижений")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                ForEach(faqItems) { item in
                    let isOpen = expandedFaqIds.contains(item.id)
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            if isOpen {
                                expandedFaqIds.remove(item.id)
                            } else {
                                expandedFaqIds.insert(item.id)
                            }
                        } label: {
                            HStack {
                                Text(item.question)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(OriginalGameTheme.goldText)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: isOpen ? "chevron.up.circle.fill" : "chevron.down.circle")
                                    .foregroundStyle(OriginalGameTheme.goldText)
                            }
                        }
                        .buttonStyle(RemasterSpringButtonStyle())

                        if isOpen {
                            Divider().background(Color.white.opacity(0.2))
                            Text(item.answer)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(10)
        }
    }
}

private struct FishGuideCardView: View {
    let entry: FishEncyclopediaGuideEntry
    let personalRecordGrams: Int
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "fish_\(entry.fish.id)",
                        fallbackSystemName: "fish.fill",
                        width: 68,
                        height: 46
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("#\(entry.fish.id) \(entry.fish.name)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(OriginalGameTheme.goldText)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                                .foregroundStyle(OriginalGameTheme.goldText)
                        }
                        Text("Цена: \(entry.fish.unitPrice) руб / \(entry.fish.unitWeight) г  •  Опыт: 1 XP за \(entry.xpWeightDivisor) г")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.9))
                        HStack(spacing: 8) {
                            Text(personalRecordGrams > 0 ? "🏆 Ваш рекорд: \(PlayerStateRepository.formatGramsAsKgOrGrams(personalRecordGrams))" : "Ещё не поймана")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(personalRecordGrams > 0 ? .green : .white.opacity(0.6))
                            Spacer()
                            Text("Водоёмов: \(entry.habitats.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .buttonStyle(RemasterSpringButtonStyle())

            if isExpanded {
                Divider().background(Color.white.opacity(0.2))

                Text("Характеристики сопротивления: Сила \(entry.fish.strength) • Выносл. \(entry.fish.stamina) • Интелл. \(entry.fish.intelligence) • Агрессия \(entry.fish.aggression)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(OriginalGameTheme.goldText.opacity(0.9))

                if entry.habitats.isEmpty {
                    Text("Редкий / специальный предмет (попадается при особых условиях).")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                } else {
                    ForEach(entry.habitats) { hab in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("📍 #\(hab.pondId + 1) \(hab.pondNameRu)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.green)
                                Spacer()
                                Text("Вес: \(PlayerStateRepository.formatGramsAsKgOrGrams(hab.minWeightGrams)) – \(PlayerStateRepository.formatGramsAsKgOrGrams(hab.maxWeightGrams))")
                                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                            ForEach(hab.baits) { b in
                                HStack(spacing: 6) {
                                    OriginalSpriteOrFallbackIcon(
                                        drawableName: "bait_\(b.baitId1Based)",
                                        fallbackSystemName: "leaf.fill",
                                        width: 22,
                                        height: 22
                                    )
                                    Text(b.baitName.capitalized)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(OriginalGameTheme.goldText)
                                    Spacer()
                                    Text("У:\(b.morningProbabilityPercent)%  Д:\(b.afternoonProbabilityPercent)%  В:\(b.eveningProbabilityPercent)%  Н:\(b.nightProbabilityPercent)%")
                                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                                        .foregroundStyle(.cyan)
                                }
                            }
                        }
                        .padding(8)
                        .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
        }
        .padding(10)
        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PondGuideCardView: View {
    let entry: PondEncyclopediaGuideEntry
    let localizedPondName: String
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        let pondNum = max(1, min(15, entry.pond.id + 1))
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "pond_\(pondNum)",
                        fallbackSystemName: "water.waves",
                        width: 72,
                        height: 48
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("#\(pondNum). \(localizedPondName.capitalized)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(OriginalGameTheme.goldText)
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                                .foregroundStyle(OriginalGameTheme.goldText)
                        }
                        Text("Требуемый разряд: \(entry.pond.requiredRank)  •  \(entry.pond.requiresCoupon ? "Нужен путевой купон" : "Без купона")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(entry.pond.requiresCoupon ? .orange : .green)
                        Text("Видов рыб: \(entry.uniqueSpeciesCount)  •  Активных наживок: \(entry.baitSlots.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .buttonStyle(RemasterSpringButtonStyle())

            if isExpanded {
                Divider().background(Color.white.opacity(0.2))

                ForEach(entry.baitSlots) { slot in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            OriginalSpriteOrFallbackIcon(
                                drawableName: "bait_\(slot.baitId1Based)",
                                fallbackSystemName: "leaf.fill",
                                width: 24,
                                height: 24
                            )
                            Text("Наживка: \(slot.baitName.capitalized)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(OriginalGameTheme.goldText)
                            Spacer()
                            Text("Видов: \(slot.species.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }

                        ForEach(slot.species) { sp in
                            HStack(spacing: 6) {
                                OriginalSpriteOrFallbackIcon(
                                    drawableName: "fish_\(sp.fishId1Based)",
                                    fallbackSystemName: "fish.fill",
                                    width: 32,
                                    height: 22
                                )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(sp.fishName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("\(PlayerStateRepository.formatGramsAsKgOrGrams(sp.minWeightGrams)) – \(PlayerStateRepository.formatGramsAsKgOrGrams(sp.maxWeightGrams))")
                                        .font(.system(size: 10).monospacedDigit())
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                                Text("У:\(sp.morningProbabilityPercent)% Д:\(sp.afternoonProbabilityPercent)% В:\(sp.eveningProbabilityPercent)% Н:\(sp.nightProbabilityPercent)%")
                                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                                    .foregroundStyle(.cyan)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                    .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
        }
        .padding(10)
        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - 2. Authentic `ShopActivity` (`res/layout/shop.xml` `res/Kz.xml`)

public struct ShopView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public enum ShopCategory: String, CaseIterable, Identifiable {
        case rods = "удочки"
        case coils = "катушки"
        case lines = "лески"
        case hooks = "крючки"
        case baits = "наживки"

        public var id: String { rawValue }

        var drawableName: String {
            switch self {
            case .rods: return "fishing_rods"
            case .coils: return "coil"
            case .lines: return "fishing_line"
            case .hooks: return "hooks"
            case .baits: return "baits"
            }
        }
    }

    @State private var selectedCategory: ShopCategory = .rods
    @State private var onlyAffordable: Bool = false

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: coordinator.isRemasterModeEnabled ? "Рыболовный магазин" : "Магазин",
                    subtitle: "\(coordinator.profile.balance) ₽"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                if coordinator.isRemasterModeEnabled {
                    remasterShopCurrentLoadoutStrip
                }

                ShopCategoryStripView(selectedCategory: $selectedCategory)

                if coordinator.isRemasterModeEnabled {
                    HStack {
                        Text("Каталог: \(selectedCategory.rawValue.capitalized)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textSecondary)
                        Spacer()
                        Button {
                            onlyAffordable.toggle()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: onlyAffordable ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12, weight: .bold))
                                Text("По карману")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(onlyAffordable ? .black : RemasterHubPalette.textPrimary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(onlyAffordable ? RemasterHubPalette.brass : RemasterHubPalette.cardBg, in: Capsule())
                        }
                        .buttonStyle(RemasterSpringButtonStyle())
                    }
                    .padding(.horizontal, 14)
                }

                shopItemsScrollView
            }
        }
        .environment(\.isRemasterMode, coordinator.isRemasterModeEnabled)
    }

    /// Top comparison bar showing the player's currently equipped tackle right inside the shop.
    private var remasterShopCurrentLoadoutStrip: some View {
        let rodText = coordinator.assembledTackle.userRod.map { "\($0.rod.weight) кг" } ?? "Нет"
        let coilText = coordinator.assembledTackle.userCoil.map { "\($0.coil.bearingCount) подш." } ?? "Нет"
        let lineText = coordinator.assembledTackle.userLine.map { "\($0.line.weight) кг" } ?? "Нет"
        let hookText = coordinator.assembledTackle.userHook.map { "\($0.amount) шт" } ?? "Нет"
        let baitText = coordinator.assembledTackle.userBait.map { "\($0.bait.name.capitalized)" } ?? "Нет"

        return HStack(spacing: 6) {
            shopLoadoutMiniPill(label: "Удочка", value: rodText, isActive: selectedCategory == .rods) { selectedCategory = .rods }
            shopLoadoutMiniPill(label: "Катушка", value: coilText, isActive: selectedCategory == .coils) { selectedCategory = .coils }
            shopLoadoutMiniPill(label: "Леска", value: lineText, isActive: selectedCategory == .lines) { selectedCategory = .lines }
            shopLoadoutMiniPill(label: "Крючок", value: hookText, isActive: selectedCategory == .hooks) { selectedCategory = .hooks }
            shopLoadoutMiniPill(label: "Наживка", value: baitText, isActive: selectedCategory == .baits) { selectedCategory = .baits }
        }
        .padding(.horizontal, 14)
    }

    private func shopLoadoutMiniPill(label: String, value: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive ? RemasterHubPalette.brass : RemasterHubPalette.textSecondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(RemasterHubPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(isActive ? RemasterHubPalette.cardElevated : RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }

    private let remasterShopGridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var shopItemsScrollView: some View {
        ScrollView(showsIndicators: false) {
            if coordinator.isRemasterModeEnabled {
                LazyVGrid(columns: remasterShopGridColumns, spacing: 10) {
                    switch selectedCategory {
                    case .rods:
                        shopRodsList
                    case .coils:
                        shopCoilsList
                    case .lines:
                        shopLinesList
                    case .hooks:
                        shopHooksList
                    case .baits:
                        shopBaitsList
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .animation(.spring(response: 0.28, dampingFraction: 0.80), value: selectedCategory)
            } else {
                VStack(spacing: 8) {
                    switch selectedCategory {
                    case .rods:
                        shopRodsList
                    case .coils:
                        shopCoilsList
                    case .lines:
                        shopLinesList
                    case .hooks:
                        shopHooksList
                    case .baits:
                        shopBaitsList
                    }
                }
                .padding(10)
            }
        }
    }

    private var shopRodsList: some View {
        let currentRodKg = coordinator.assembledTackle.userRod?.rod.weight ?? 0
        return ForEach(coordinator.catalogRods.filter { !onlyAffordable || coordinator.profile.balance >= $0.price }, id: \.id) { rod in
            let diffKg = rod.weight - currentRodKg
            let diffSuffix = (coordinator.isRemasterModeEnabled && currentRodKg > 0 && diffKg > 0)
                ? "  •  🔼 +\(diffKg) кг к текущей"
                : ""
            ShopItemRowView(
                drawableName: "fishing_rods",
                title: rod.name,
                subtitle: "Макс. вес: \(rod.weight) кг  •  Прочность: 100%\(diffSuffix)",
                priceCoins: rod.price,
                canAfford: coordinator.profile.balance >= rod.price
            ) {
                coordinator.buyRod(baseRodId: rod.id)
            }
        }
    }

    private var shopCoilsList: some View {
        ForEach(coordinator.catalogCoils.filter { !onlyAffordable || coordinator.profile.balance >= $0.price }, id: \.id) { coil in
            let durabilityUnits = coordinator.balanceTables.coilInitialStrengthOrHookBonus(at: max(0, coil.id - 1))
            ShopItemRowView(
                drawableName: "coil",
                title: coil.name,
                subtitle: "Подшипников: \(coil.bearingCount)  •  Ресурс: \(durabilityUnits) ед.",
                priceCoins: coil.price,
                canAfford: coordinator.profile.balance >= coil.price
            ) {
                coordinator.buyCoil(baseCoilId: coil.id)
            }
        }
    }

    private var shopLinesList: some View {
        ForEach(coordinator.catalogLines.filter { !onlyAffordable || coordinator.profile.balance >= $0.price }, id: \.id) { line in
            ShopItemRowView(
                drawableName: "fishing_line",
                title: line.name,
                subtitle: "Тест: \(line.weight) кг  •  Длина: \(line.stockLength) м",
                priceCoins: line.price,
                canAfford: coordinator.profile.balance >= line.price
            ) {
                coordinator.buyLine(baseLineId: line.id)
            }
        }
    }

    private var shopHooksList: some View {
        ForEach(coordinator.catalogHooks.filter { !onlyAffordable || coordinator.profile.balance >= $0.spec.price }) { hookItem in
            ShopItemRowView(
                drawableName: "hooks",
                title: hookItem.spec.name,
                subtitle: "Упаковка: \(hookItem.stockAmount) шт.",
                priceCoins: hookItem.spec.price,
                canAfford: coordinator.profile.balance >= hookItem.spec.price
            ) {
                coordinator.buyHook(baseHookId: hookItem.id)
            }
        }
    }

    private var shopBaitsList: some View {
        ForEach(coordinator.catalogBaits.filter { !onlyAffordable || (coordinator.profile.category >= $0.spec.rank && coordinator.profile.balance >= $0.spec.price) }) { baitItem in
            let unlocked = coordinator.profile.category >= baitItem.spec.rank
            ShopItemRowView(
                drawableName: "bait_\(baitItem.id)",
                title: baitItem.spec.name.capitalized,
                subtitle: "Упаковка: \(baitItem.stockAmount) шт.  •  Разряд: \(baitItem.spec.rank)",
                priceCoins: baitItem.spec.price,
                canAfford: unlocked && coordinator.profile.balance >= baitItem.spec.price
            ) {
                coordinator.buyBait(baseBaitId: baitItem.id)
            }
        }
    }
}

private struct ShopCategoryStripView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    @Binding var selectedCategory: ShopView.ShopCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isRemasterMode ? 8 : 12) {
                ForEach(ShopView.ShopCategory.allCases) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button {
                        selectedCategory = cat
                    } label: {
                        if isRemasterMode {
                            HStack(spacing: 7) {
                                OriginalSpriteOrFallbackIcon(
                                    drawableName: cat.drawableName,
                                    fallbackSystemName: "shippingbox.fill",
                                    width: 26,
                                    height: 22
                                )
                                Text(cat.rawValue.capitalized)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? RemasterHubPalette.textPrimary : RemasterHubPalette.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? RemasterHubPalette.cardElevated : RemasterHubPalette.cardBg.opacity(0.85),
                                in: Capsule()
                            )

                        } else {
                            VStack(spacing: 3) {
                                OriginalSpriteOrFallbackIcon(
                                    drawableName: cat.drawableName,
                                    fallbackSystemName: "shippingbox.fill",
                                    width: 48,
                                    height: 36
                                )
                                Text(cat.rawValue.capitalized)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isSelected ? .white : OriginalGameTheme.goldText)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? Color.white.opacity(0.22) : Color.black.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }
}

private struct ShopItemRowView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let drawableName: String
    let title: String
    let subtitle: String
    let priceCoins: Int
    let canAfford: Bool
    let onBuy: () -> Void

    var body: some View {
        if isRemasterMode {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.30))
                            .frame(width: 48, height: 48)
                        OriginalSpriteOrFallbackIcon(
                            drawableName: drawableName,
                            fallbackSystemName: "shippingbox.fill",
                            width: 36,
                            height: 36
                        )
                    }
                    Spacer()
                    Text("\(priceCoins) ₽")
                        .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(canAfford ? RemasterHubPalette.brass : RemasterHubPalette.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.28), in: Capsule())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textSecondary)
                        .lineLimit(2)
                        .frame(minHeight: 28, alignment: .topLeading)
                }

                Button(action: onBuy) {
                    HStack(spacing: 5) {
                        Image(systemName: canAfford ? "plus.circle.fill" : "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(canAfford ? "Купить" : "Недоступно")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(canAfford ? .white : RemasterHubPalette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        canAfford ? RemasterHubPalette.sage : RemasterHubPalette.cardElevated,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
            .padding(12)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            HStack(spacing: 12) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: drawableName,
                    fallbackSystemName: "shippingbox.fill",
                    width: 48,
                    height: 48
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Цена: \(priceCoins) руб")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(canAfford ? .green : .red)
                }

                Spacer()

                Button(action: onBuy) {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: canAfford ? "sbuy_on" : "sbuy_off",
                        fallbackSystemName: "cart.badge.plus",
                        width: 44,
                        height: 44
                    )
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
            .padding(10)
            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - 3. Authentic `BackpackActivity` (`res/layout/backpack.xml` `res/X1.xml`)

public struct InventoryView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public enum BackpackCategory: String, CaseIterable, Identifiable {
        case rods = "удочки"
        case coils = "катушки"
        case lines = "лески"
        case hooks = "крючки"
        case baits = "наживки"

        public var id: String { rawValue }

        var drawableName: String {
            switch self {
            case .rods: return "fishing_rods"
            case .coils: return "coil"
            case .lines: return "fishing_line"
            case .hooks: return "hooks"
            case .baits: return "baits"
            }
        }
    }

    @State private var selectedCategory: BackpackCategory = .rods

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    private var tackleBalanceAdvisory: (text: String, color: Color) {
        guard let rod = coordinator.assembledTackle.userRod,
              let line = coordinator.assembledTackle.userLine else {
            return ("Выберите все 5 элементов снасти для выхода на водоём", RemasterHubPalette.brass)
        }
        if line.line.weight > rod.rod.weight {
            return ("⚠️ Леска (\(line.line.weight) кг) крепче удилища (\(rod.rod.weight) кг) — риск поломки удочки!", Color(red: 0.95, green: 0.45, blue: 0.38))
        } else {
            return ("✓ Безопасный баланс: леска (\(line.line.weight) кг) защищает удилище (\(rod.rod.weight) кг)", RemasterHubPalette.sage)
        }
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: coordinator.isRemasterModeEnabled ? "Мастерская снасти" : "Рюкзак",
                    subtitle: coordinator.assembledTackle.isComplete ? "Готова к лову" : "Не собрана"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                if coordinator.isRemasterModeEnabled {
                    remasterInteractiveRigBlueprintCard
                } else {
                    BackpackCategoryStripView(selectedCategory: $selectedCategory)
                }
                backpackItemsScrollView
            }
        }
        .environment(\.isRemasterMode, coordinator.isRemasterModeEnabled)
    }

    private var remasterInteractiveRigBlueprintCard: some View {
        let advisory = tackleBalanceAdvisory
        let rod = coordinator.assembledTackle.userRod
        let coil = coordinator.assembledTackle.userCoil
        let line = coordinator.assembledTackle.userLine
        let hook = coordinator.assembledTackle.userHook
        let bait = coordinator.assembledTackle.userBait

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("СХЕМА ОСНАСТКИ (НАЖМИТЕ НА СЛОТ)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.brass)
                    Text(advisory.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(advisory.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 6)
                Button {
                    coordinator.equipBestOwnedTackle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11, weight: .bold))
                        Text("Авто-сборка")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RemasterHubPalette.brass, in: Capsule())
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }

            HStack(spacing: 6) {
                blueprintSlotTile(
                    category: .rods,
                    icon: "fishing_rods",
                    title: "Удочка",
                    spec: rod.map { "\($0.rod.weight) кг" } ?? "Пусто",
                    subSpec: rod.map { "Прочн. \($0.strength)%" } ?? "Выбрать",
                    healthFraction: Double(rod?.strength ?? 0) / 100.0
                )
                blueprintSlotTile(
                    category: .coils,
                    icon: "coil",
                    title: "Катушка",
                    spec: coil.map { "\($0.coil.bearingCount) подш." } ?? "Пусто",
                    subSpec: coil.map { "Ресурс \($0.strength)%" } ?? "Выбрать",
                    healthFraction: Double(coil?.strength ?? 0) / 100.0
                )
                blueprintSlotTile(
                    category: .lines,
                    icon: "fishing_line",
                    title: "Леска",
                    spec: line.map { "\($0.line.weight) кг" } ?? "Пусто",
                    subSpec: line.map { "\($0.length) м" } ?? "Выбрать",
                    healthFraction: line != nil ? 1.0 : 0.0
                )
                blueprintSlotTile(
                    category: .hooks,
                    icon: "hooks",
                    title: "Крючок",
                    spec: hook.map { "\($0.amount) шт." } ?? "Пусто",
                    subSpec: hook?.hook.name ?? "Выбрать",
                    healthFraction: hook != nil ? 1.0 : 0.0
                )
                blueprintSlotTile(
                    category: .baits,
                    icon: bait.map { "bait_\($0.bait.id)" } ?? "baits",
                    title: "Наживка",
                    spec: bait.map { "\($0.amount) шт." } ?? "Пусто",
                    subSpec: bait?.bait.name.capitalized ?? "Выбрать",
                    healthFraction: bait != nil ? 1.0 : 0.0
                )
            }
        }
        .padding(12)
        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func blueprintSlotTile(
        category: BackpackCategory,
        icon: String,
        title: String,
        spec: String,
        subSpec: String,
        healthFraction: Double
    ) -> some View {
        let isSelected = (selectedCategory == category)
        return Button {
            selectedCategory = category
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .black : RemasterHubPalette.textSecondary)
                    .lineLimit(1)

                OriginalSpriteOrFallbackIcon(
                    drawableName: icon,
                    fallbackSystemName: "circle.fill",
                    width: 28,
                    height: 24
                )

                Text(spec)
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isSelected ? .black : RemasterHubPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(subSpec)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .black.opacity(0.75) : RemasterHubPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Capsule()
                    .fill(isSelected ? Color.black.opacity(0.35) : (healthFraction > 0 ? RemasterHubPalette.sage : Color.white.opacity(0.10)))
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                isSelected ? RemasterHubPalette.brass : RemasterHubPalette.cardElevated,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }

    private let remasterBackpackGridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var backpackItemsScrollView: some View {
        ScrollView(showsIndicators: false) {
            if coordinator.isRemasterModeEnabled {
                LazyVGrid(columns: remasterBackpackGridColumns, spacing: 10) {
                    switch selectedCategory {
                    case .rods:
                        backpackRodsList
                    case .coils:
                        backpackCoilsList
                    case .lines:
                        backpackLinesList
                    case .hooks:
                        backpackHooksList
                    case .baits:
                        backpackBaitsList
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
                .animation(.spring(response: 0.28, dampingFraction: 0.80), value: selectedCategory)
            } else {
                VStack(spacing: 8) {
                    switch selectedCategory {
                    case .rods:
                        backpackRodsList
                    case .coils:
                        backpackCoilsList
                    case .lines:
                        backpackLinesList
                    case .hooks:
                        backpackHooksList
                    case .baits:
                        backpackBaitsList
                    }
                }
                .padding(10)
            }
        }
    }

    private var backpackRodsList: some View {
        ForEach(coordinator.ownedRods) { rodItem in
            BackpackItemRowView(
                drawableName: "fishing_rods",
                title: rodItem.rod.name,
                subtitle: "Мощность: \(rodItem.rod.weight) кг  •  Прочность: \(rodItem.strength)%",
                isEquipped: coordinator.tackleSlots.fishingRodId == rodItem.id
            ) {
                coordinator.equipRod(rowId: rodItem.id)
            }
        }
    }

    private var backpackCoilsList: some View {
        ForEach(coordinator.ownedCoils) { coilItem in
            BackpackItemRowView(
                drawableName: "coil",
                title: coilItem.coil.name,
                subtitle: "Подшипников: \(coilItem.coil.bearingCount)  •  Прочность: \(coilItem.strength)%",
                isEquipped: coordinator.tackleSlots.coilId == coilItem.id
            ) {
                coordinator.equipCoil(rowId: coilItem.id)
            }
        }
    }

    private var backpackLinesList: some View {
        ForEach(coordinator.ownedLines) { lineItem in
            BackpackItemRowView(
                drawableName: "fishing_line",
                title: lineItem.line.name,
                subtitle: "Тест: \(lineItem.line.weight) кг  •  Длина: \(lineItem.length) м",
                isEquipped: coordinator.tackleSlots.fishingLineId == lineItem.id
            ) {
                coordinator.equipLine(rowId: lineItem.id)
            }
        }
    }

    private var backpackHooksList: some View {
        ForEach(coordinator.ownedHooks) { hookItem in
            BackpackItemRowView(
                drawableName: "hooks",
                title: hookItem.hook.name,
                subtitle: "В наличии: \(hookItem.amount) шт.",
                isEquipped: coordinator.tackleSlots.hookId == hookItem.id
            ) {
                coordinator.equipHook(rowId: hookItem.id)
            }
        }
    }

    private var backpackBaitsList: some View {
        ForEach(coordinator.ownedBaits) { baitItem in
            BackpackItemRowView(
                drawableName: "bait_\(baitItem.bait.id)",
                title: baitItem.bait.name.capitalized,
                subtitle: "В наличии: \(baitItem.amount) шт.",
                isEquipped: coordinator.tackleSlots.baitId == baitItem.id
            ) {
                coordinator.equipBait(rowId: baitItem.id)
            }
        }
    }
}

private struct BackpackCategoryStripView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    @Binding var selectedCategory: InventoryView.BackpackCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isRemasterMode ? 8 : 12) {
                ForEach(InventoryView.BackpackCategory.allCases) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button {
                        selectedCategory = cat
                    } label: {
                        if isRemasterMode {
                            HStack(spacing: 7) {
                                OriginalSpriteOrFallbackIcon(
                                    drawableName: cat.drawableName,
                                    fallbackSystemName: "backpack.fill",
                                    width: 26,
                                    height: 22
                                )
                                Text(cat.rawValue.capitalized)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? RemasterHubPalette.textPrimary : RemasterHubPalette.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? RemasterHubPalette.cardElevated : RemasterHubPalette.cardBg.opacity(0.85),
                                in: Capsule()
                            )

                        } else {
                            VStack(spacing: 3) {
                                OriginalSpriteOrFallbackIcon(
                                    drawableName: cat.drawableName,
                                    fallbackSystemName: "backpack.fill",
                                    width: 48,
                                    height: 36
                                )
                                Text(cat.rawValue.capitalized)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isSelected ? .white : OriginalGameTheme.goldText)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? Color.white.opacity(0.22) : Color.black.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }
}

private struct BackpackItemRowView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let drawableName: String
    let title: String
    let subtitle: String
    let isEquipped: Bool
    let onEquip: () -> Void

    var body: some View {
        Button(action: onEquip) {
            if isRemasterMode {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.30))
                                .frame(width: 46, height: 46)
                            OriginalSpriteOrFallbackIcon(
                                drawableName: drawableName,
                                fallbackSystemName: "circle.fill",
                                width: 34,
                                height: 34
                            )
                        }
                        Spacer()
                        if isEquipped {
                            Text("АКТИВНО")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RemasterHubPalette.sage, in: Capsule())
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textSecondary)
                            .lineLimit(2)
                            .frame(minHeight: 28, alignment: .topLeading)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: isEquipped ? "checkmark.circle.fill" : "hand.tap.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(isEquipped ? "Надето" : "Надеть")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(isEquipped ? .white : RemasterHubPalette.brass)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        isEquipped ? RemasterHubPalette.sage : Color.black.opacity(0.28),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .padding(12)
                .background(
                    isEquipped ? RemasterHubPalette.cardElevated : RemasterHubPalette.cardBg,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            } else {
                HStack(spacing: 12) {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: drawableName,
                        fallbackSystemName: "circle.fill",
                        width: 46,
                        height: 46
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(OriginalGameTheme.goldText)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    OriginalSpriteOrFallbackIcon(
                        drawableName: isEquipped ? "tick" : "tick_empty",
                        fallbackSystemName: isEquipped ? "checkmark.circle.fill" : "circle",
                        width: 32,
                        height: 32
                    )
                }
                .padding(10)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .buttonStyle(RemasterSpringButtonStyle())
    }
}

// MARK: - 4. Authentic `FishpondActivity` (`Садок`, `res/layout/fishpond.xml` `res/1o.xml`)

public struct FishnetView: View {
    public enum CatchSortOrder: String, CaseIterable, Identifiable {
        case value = "По ценности"
        case weight = "По весу"
        case species = "По виду"

        public var id: String { rawValue }
    }

    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var sortOrder: CatchSortOrder = .value

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    private var totalWeightGrams: Int {
        var total = 0
        for entry in coordinator.fishnetEntries {
            total += entry.caughtFish.weightGrams
        }
        return total
    }

    private var totalValueCoins: Int {
        var total = 0
        for entry in coordinator.fishnetEntries {
            total += entry.caughtFish.sellingPriceCoins
        }
        return total
    }

    private var sortedFishnetEntries: [FishnetEntryRecord] {
        switch sortOrder {
        case .value:
            return coordinator.fishnetEntries.sorted { $0.caughtFish.sellingPriceCoins > $1.caughtFish.sellingPriceCoins }
        case .weight:
            return coordinator.fishnetEntries.sorted { $0.caughtFish.weightGrams > $1.caughtFish.weightGrams }
        case .species:
            return coordinator.fishnetEntries.sorted { $0.caughtFish.fish.name < $1.caughtFish.fish.name }
        }
    }

    private var heaviestEntry: FishnetEntryRecord? {
        coordinator.fishnetEntries.max(by: { $0.caughtFish.weightGrams < $1.caughtFish.weightGrams })
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: coordinator.isRemasterModeEnabled ? "Садок и оценка улова" : "Садок",
                    subtitle: "\(coordinator.fishnetEntries.count) / \(PlayerStateRepository.maxFishnetCapacity)"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                if coordinator.isRemasterModeEnabled {
                    remasterFishnetDashboardBody
                } else {
                    FishnetSummaryPlaqueView(
                        totalWeightGrams: totalWeightGrams,
                        fishCount: coordinator.fishnetEntries.count,
                        totalValueCoins: totalValueCoins
                    )

                    if !coordinator.fishnetEntries.isEmpty {
                        Button {
                            coordinator.sellAllFishInFishnet()
                        } label: {
                            OriginalStyledActionButtonLabel(
                                title: "Продать весь улов (+\(totalValueCoins) руб)",
                                minWidth: 240
                            )
                        }
                        .buttonStyle(RemasterSpringButtonStyle())
                    }

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(coordinator.fishnetEntries) { entry in
                                FishnetEntryRowView(entry: entry)
                            }
                        }
                        .padding(10)
                    }
                }
            }
        }
        .environment(\.isRemasterMode, coordinator.isRemasterModeEnabled)
    }

    private var remasterFishnetDashboardBody: some View {
        let capFrac = Double(coordinator.fishnetEntries.count) / Double(max(1, PlayerStateRepository.maxFishnetCapacity))

        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Capacity Ring & Sell Haul Hero Card
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.black.opacity(0.38), lineWidth: 6)
                            .frame(width: 64, height: 64)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(1.0, capFrac)))
                            .stroke(
                                capFrac >= 0.9 ? Color.orange : RemasterHubPalette.sage,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 64, height: 64)
                        VStack(spacing: 0) {
                            Text("\(coordinator.fishnetEntries.count)")
                                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Text("из \(PlayerStateRepository.maxFishnetCapacity)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Общий вес: \(PlayerStateRepository.formatGramsAsKgOrGrams(totalWeightGrams))")
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                        Text("Оценка улова: +\(totalValueCoins) ₽")
                            .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(RemasterHubPalette.sage)

                        if !coordinator.fishnetEntries.isEmpty {
                            Button {
                                coordinator.sellAllFishInFishnet()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "rublesign.circle.fill")
                                    Text("Продать весь улов (+\(totalValueCoins) ₽)")
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(RemasterHubPalette.brass, in: Capsule())
                            }
                            .buttonStyle(RemasterSpringButtonStyle())
                            .padding(.top, 2)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                // 2. Largest Trophy Spotlight Card
                if let best = heaviestEntry {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.28))
                                .frame(width: 78, height: 54)
                            OriginalSpriteOrFallbackIcon(
                                drawableName: "fish_\(best.caughtFish.fish.id)",
                                fallbackSystemName: "fish.fill",
                                width: 68,
                                height: 44
                            )
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("🏆 ГЛАВНЫЙ ТРОФЕЙ В САДКЕ")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.brass)
                            Text(best.caughtFish.fish.name)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Text("Вес: \(PlayerStateRepository.formatGramsAsKgOrGrams(best.caughtFish.weightGrams))  •  +\(best.caughtFish.sellingPriceCoins) ₽")
                                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.sage)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // 3. Sort Bar + Catch List
                if !coordinator.fishnetEntries.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(CatchSortOrder.allCases) { order in
                            let isSel = (sortOrder == order)
                            Button {
                                sortOrder = order
                            } label: {
                                Text(order.rawValue)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSel ? .black : RemasterHubPalette.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(isSel ? RemasterHubPalette.brass : RemasterHubPalette.cardBg, in: Capsule())
                            }
                            .buttonStyle(RemasterSpringButtonStyle())
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(sortedFishnetEntries) { entry in
                            FishnetEntryRowView(entry: entry)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "basket")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(RemasterHubPalette.textSecondary)
                        Text("Ваш садок пока пуст")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                        Text("Отправляйтесь на водоём и поймайте свою первую рыбу!")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }
}

private struct FishnetSummaryPlaqueView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let totalWeightGrams: Int
    let fishCount: Int
    let totalValueCoins: Int

    var body: some View {
        if isRemasterMode {
            HStack(spacing: 10) {
                summaryMetricTile(
                    icon: "basket.fill",
                    label: "Рыб в садке",
                    value: "\(fishCount) шт.",
                    accent: RemasterHubPalette.brass
                )
                summaryMetricTile(
                    icon: "scalemass.fill",
                    label: "Общий вес",
                    value: PlayerStateRepository.formatGramsAsKgOrGrams(totalWeightGrams),
                    accent: RemasterHubPalette.textPrimary
                )
                summaryMetricTile(
                    icon: "rublesign.circle.fill",
                    label: "Оценка улова",
                    value: "\(totalValueCoins) ₽",
                    accent: RemasterHubPalette.sage
                )
            }
            .padding(.horizontal, 12)
        } else {
            ZStack {
                if let timeBg = OriginalGameAssetsLoader.image(named: "time_background") {
                    timeBg.resizable().frame(height: 76)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 76)
                }
                VStack(spacing: 3) {
                    Text("Общий вес: \(totalWeightGrams) г")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text("Количество рыб: \(fishCount) шт.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text("Стоимость улова: \(totalValueCoins) руб")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func summaryMetricTile(icon: String, label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(RemasterHubPalette.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

    }
}

private struct FishnetEntryRowView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let entry: FishnetEntryRecord

    var body: some View {
        if isRemasterMode {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 72, height: 50)
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "fish_\(entry.caughtFish.fish.id)",
                        fallbackSystemName: "fish.fill",
                        width: 64,
                        height: 42
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.caughtFish.fish.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                    Text("Вес: \(PlayerStateRepository.formatGramsAsKgOrGrams(entry.caughtFish.weightGrams))")
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(RemasterHubPalette.textSecondary)
                }
                Spacer()
                Text("+\(entry.caughtFish.sellingPriceCoins) ₽")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(RemasterHubPalette.sage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RemasterHubPalette.sage.opacity(0.14), in: Capsule())
            }
            .padding(11)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        } else {
            HStack(spacing: 12) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "fish_\(entry.caughtFish.fish.id)",
                    fallbackSystemName: "fish.fill",
                    width: 72,
                    height: 48
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.caughtFish.fish.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text("Вес: \(entry.caughtFish.weightGrams) г  •  Цена: \(entry.caughtFish.sellingPriceCoins) руб")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(10)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - 5. Authentic `Records`, `Achievements` (`md_achiv_1..14`), `QuestActivity` (`res/zY.xml` + `Ly0/h`) & `TaskActivity` (`res/e7.xml`)

public struct ProgressAndRecordsView: View {
    public enum RecordsFilter: String, CaseIterable, Identifiable {
        case all = "Все (141)"
        case caught = "Пойманные"
        case uncaught = "Не открытые"

        public var id: String { rawValue }
    }

    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var showAllQuestsCatalog: Bool = false
    @State private var recordsSearchText: String = ""
    @State private var recordsFilter: RecordsFilter = .all

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    private var baitNamesById: [Int: String] {
        var map: [Int: String] = [:]
        for item in coordinator.catalogBaits {
            map[item.id] = item.spec.name
        }
        return map
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: coordinator.selectedProgressSection.rawValue,
                    subtitle: "Разряд: \(coordinator.profile.category)"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                sectionTabPicker

                ScrollView {
                    VStack(spacing: 10) {
                        switch coordinator.selectedProgressSection {
                        case .achievements:
                            achievementsList
                        case .quests:
                            questsSectionView
                        case .tasks:
                            tasksSectionView
                        case .records:
                            recordsList
                        }
                    }
                    .padding(10)
                }
            }
        }
        .environment(\.isRemasterMode, coordinator.isRemasterModeEnabled)
    }

    private var sectionTabPicker: some View {
        HStack(spacing: 6) {
            ForEach(ProgressSectionTab.allCases) { tab in
                let isSel = (coordinator.selectedProgressSection == tab)
                Button {
                    coordinator.selectedProgressSection = tab
                    if tab == .tasks && coordinator.activeContract == nil {
                        _ = coordinator.generateOrEnsureUserTask()
                    }
                } label: {
                    if coordinator.isRemasterModeEnabled {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(isSel ? .black : RemasterHubPalette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSel ? RemasterHubPalette.brass : RemasterHubPalette.cardBg, in: Capsule())
                    } else {
                        OriginalStyledActionButtonLabel(title: tab.rawValue, minWidth: 78)
                            .opacity(isSel ? 1.0 : 0.65)
                    }
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
        }
        .padding(.horizontal, 12)
    }

    private var achievementsList: some View {
        ForEach(coordinator.achievements) { ach in
            AchievementRowView(
                achievement: ach,
                title: coordinator.localeManager.achievementTitle(id1Based: ach.id),
                descriptionText: coordinator.localeManager.achievementDescription(id1Based: ach.id)
            )
        }
    }

    // MARK: - 5.1 Authentic `QuestActivity` (`res/layout/quest.xml` `res/zY.xml` + `Ly0/h`)

    private var questsSectionView: some View {
        VStack(spacing: 12) {
            if let activeQuest = coordinator.activeQuestForPlayer {
                ActiveQuestDetailCardView(
                    quest: activeQuest,
                    title: coordinator.localeManager.questTitle(id1Based: activeQuest.id),
                    descriptionText: coordinator.localeManager.questDescription(id1Based: activeQuest.id),
                    baitDescription: PlayerStateRepository.formatQuestBaitsDescription(
                        baitCsv: activeQuest.baitCsv,
                        baitNamesById: baitNamesById
                    ),
                    rewards: PlayerStateRepository.parseQuestRewards(activeQuest.rewardCsv),
                    targetSlots: PlayerStateRepository.buildQuestTargetSlots(
                        for: activeQuest,
                        fishCatalogById: coordinator.fishCatalogById
                    ),
                    onClaimReward: {
                        _ = coordinator.claimQuestReward(questId: activeQuest.id)
                    }
                )
            } else {
                let completedCount = coordinator.quests.filter { $0.made >= 2 }.count
                let nextLocked = coordinator.quests.first(where: { $0.made <= 1 })
                VStack(spacing: 8) {
                    Text(completedCount >= coordinator.quests.count ? "Поздравляем! Все 44 квеста пройдены!" : "Больше доступных квестов пока нет")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    if let nextLocked {
                        Text("Следующий квест (#\(nextLocked.id) «\(coordinator.localeManager.questTitle(id1Based: nextLocked.id))») откроется на \(nextLocked.requiredCategory)-м разряде (ваш разряд: \(coordinator.profile.category)).")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    Text("Повышайте разряд и выполняйте поручения во вкладке «Задание».")
                        .font(.system(size: 12))
                        .foregroundStyle(.cyan)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                showAllQuestsCatalog.toggle()
            } label: {
                OriginalStyledActionButtonLabel(
                    title: showAllQuestsCatalog
                        ? "Скрыть полный список квестов (44)"
                        : "Показать все 44 сюжетных квеста",
                    minWidth: 260
                )
            }
            .buttonStyle(RemasterSpringButtonStyle())

            if showAllQuestsCatalog {
                ForEach(coordinator.quests) { quest in
                    QuestRowView(
                        quest: quest,
                        title: coordinator.localeManager.questTitle(id1Based: quest.id),
                        descriptionText: coordinator.localeManager.questDescription(id1Based: quest.id),
                        targetSlots: PlayerStateRepository.buildQuestTargetSlots(
                            for: quest,
                            fishCatalogById: coordinator.fishCatalogById
                        ),
                        rewards: PlayerStateRepository.parseQuestRewards(quest.rewardCsv),
                        playerCategory: coordinator.profile.category,
                        onClaimReward: {
                            _ = coordinator.claimQuestReward(questId: quest.id)
                        }
                    )
                }
            }
        }
    }

    // MARK: - 5.2 Authentic `TaskActivity` (`res/layout/task.xml` `res/e7.xml` + `TaskActivity$f` / `TaskActivity$b`)

    private var tasksSectionView: some View {
        let rerollCost = PlayerStateRepository.taskRerollCostCoins(forCategoryRank: coordinator.profile.category)
        return VStack(spacing: 12) {
            if let contract = coordinator.activeContract {
                let fishName = coordinator.fishCatalogById[contract.targetFishId]?.name ?? "Рыба #\(contract.targetFishId)"
                let baitName: String = {
                    if contract.targetBaitId <= 0 { return "любая" }
                    return baitNamesById[contract.targetBaitId] ?? "наживка #\(contract.targetBaitId)"
                }()
                let bonusXp = contract.resolvedBonusExperience(balanceTables: coordinator.balanceTables)

                // Top progress plaque (`TaskActivity.onCreate` `0x7f0a02b3` & `0x7f0a03c1`)
                if coordinator.isRemasterModeEnabled {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Поймано по поручению")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                            Text("\(contract.currentCount) шт.")
                                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.brass)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))


                        VStack(alignment: .leading, spacing: 3) {
                            Text("Суммарный вес")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                            Text(String(format: "%.3f кг (\(contract.currentWeightGrams) г)", Double(contract.currentWeightGrams) / 1000.0))
                                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.sage)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    }
                } else {
                    ZStack {
                        if let timeBg = OriginalGameAssetsLoader.image(named: "time_background") {
                            timeBg.resizable().frame(height: 68)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.6))
                                .frame(height: 68)
                        }
                        VStack(spacing: 4) {
                            Text("Количество: \(contract.currentCount) шт.")
                                .font(.system(size: 15, weight: .bold).monospacedDigit())
                                .foregroundStyle(OriginalGameTheme.goldText)
                            Text(String(format: "Общий вес: %.3f кг (\(contract.currentWeightGrams) г)", Double(contract.currentWeightGrams) / 1000.0))
                                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.cyan)
                        }
                    }
                }

                // Active Task Card (`TaskActivity.O`)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(contract.made >= 1 ? "Задание выполнено!" : "Текущее поручение рыбака")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(contract.made >= 1 ? .green : OriginalGameTheme.goldText)
                        Spacer()
                        if coordinator.isRemasterModeEnabled {
                            Image(systemName: contract.made >= 1 ? "checkmark.circle.fill" : "circle.dashed")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(contract.made >= 1 ? RemasterHubPalette.sage : RemasterHubPalette.brass)
                        } else {
                            OriginalSpriteOrFallbackIcon(
                                drawableName: contract.made >= 1 ? "tick" : "tick_empty",
                                fallbackSystemName: contract.made >= 1 ? "checkmark.circle.fill" : "circle",
                                width: 28,
                                height: 28
                            )
                        }
                    }

                    HStack(spacing: 14) {
                        OriginalSpriteOrFallbackIcon(
                            drawableName: "fish_\(contract.targetFishId)",
                            fallbackSystemName: "fish.fill",
                            width: 96,
                            height: 64
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fishName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(OriginalGameTheme.goldText)
                            HStack(spacing: 6) {
                                if contract.targetBaitId > 0 {
                                    OriginalSpriteOrFallbackIcon(
                                        drawableName: "bait_\(contract.targetBaitId)",
                                        fallbackSystemName: "leaf.fill",
                                        width: 20,
                                        height: 20
                                    )
                                }
                                Text("Наживка: \(baitName)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("Вес рыбы: \(contract.perFishWeightConditionDescriptionRu)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Цель задания: \(contract.goalSummaryDescriptionRu)")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(.cyan)
                        Text("Награда за выполнение: +\(bonusXp) опыта")
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(.green)
                    }

                    HStack(spacing: 10) {
                        if contract.made >= 1 {
                            Button {
                                _ = coordinator.generateOrEnsureUserTask()
                            } label: {
                                OriginalStyledActionButtonLabel(title: "Новое задание (Бесплатно)", minWidth: 220)
                            }
                            .buttonStyle(RemasterSpringButtonStyle())
                        } else {
                            Button {
                                coordinator.selectedTab = .fishingPond
                            } label: {
                                OriginalStyledActionButtonLabel(title: "Выполняю → На водоём", minWidth: 165)
                            }
                            .buttonStyle(RemasterSpringButtonStyle())

                            Button {
                                _ = coordinator.rerollActiveUserTask()
                            } label: {
                                OriginalStyledActionButtonLabel(title: "Сменить (\(rerollCost) руб)", minWidth: 155)
                            }
                            .buttonStyle(RemasterSpringButtonStyle())
                        }
                    }
                }
                .padding(12)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Text("У вас пока нет активного задания")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text("Нажмите кнопку ниже, чтобы получить поручение под ваш текущий разряд и открытые водоёмы.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                    Button {
                        _ = coordinator.generateOrEnsureUserTask()
                    } label: {
                        OriginalStyledActionButtonLabel(title: "Получить задание", minWidth: 220)
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .onAppear {
            if coordinator.activeContract == nil {
                _ = coordinator.generateOrEnsureUserTask()
            }
        }
    }

    private var filteredPersonalRecords: [PersonalSpeciesRecord] {
        let q = recordsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return coordinator.personalRecords.filter { rec in
            switch recordsFilter {
            case .all: break
            case .caught: if rec.weightGrams <= 0 { return false }
            case .uncaught: if rec.weightGrams > 0 { return false }
            }
            if q.isEmpty { return true }
            return rec.fishName.lowercased().contains(q) || "\(rec.id)".contains(q)
        }
    }

    @ViewBuilder
    private var recordsList: some View {
        if coordinator.isRemasterModeEnabled {
            let caughtCount = coordinator.personalRecords.filter { $0.weightGrams > 0 }.count
            let totalCount = max(1, coordinator.personalRecords.count)
            let masteryFrac = Double(caughtCount) / Double(totalCount)

            VStack(alignment: .leading, spacing: 10) {
                // Collection Mastery Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("КОЛЛЕКЦИЯ ТРОФЕЕВ ВОДОЁМОВ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.brass)
                        Spacer()
                        Text("\(Int((masteryFrac * 100).rounded()))% открыто")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(RemasterHubPalette.sage)
                    }
                    Text("Поймано \(caughtCount) из \(coordinator.personalRecords.count) видов рыб")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.38))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [RemasterHubPalette.sage, RemasterHubPalette.brass],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(6, geo.size.width * masteryFrac))
                        }
                    }
                    .frame(height: 7)
                }
                .padding(14)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Search & Filter Bar
                TextField("Поиск вида рыбы по названию или номеру...", text: $recordsSearchText)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 6) {
                    ForEach(RecordsFilter.allCases) { filter in
                        let isSel = (recordsFilter == filter)
                        Button {
                            recordsFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(isSel ? .black : RemasterHubPalette.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(isSel ? RemasterHubPalette.brass : RemasterHubPalette.cardBg, in: Capsule())
                        }
                        .buttonStyle(RemasterSpringButtonStyle())
                    }
                }

                ForEach(filteredPersonalRecords) { rec in
                    PersonalRecordRowView(record: rec)
                }
            }
        } else {
            ForEach(coordinator.personalRecords) { rec in
                PersonalRecordRowView(record: rec)
            }
        }
    }
}

private struct ActiveQuestDetailCardView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let quest: QuestRecord
    let title: String
    let descriptionText: String
    let baitDescription: String
    let rewards: (coins: Int, experience: Int)
    let targetSlots: [QuestTargetSlotProgress]
    let onClaimReward: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Квест #\(quest.id): \(title)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text("Требуемый разряд: \(quest.requiredCategory)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                Spacer()
                if quest.made == 1 {
                    Text("Выполнен!")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green, in: Capsule())
                        .foregroundStyle(.black)
                }
            }

            Text(descriptionText)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.95))

            HStack {
                Text("Наживка: \(baitDescription)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Spacer()
                Text("Награда: \(rewards.coins) руб • +\(rewards.experience) XP")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.green)
            }

            Divider().background(Color.white.opacity(0.2))

            // Per-fish target rows (`Ly0/h` adapter in `QuestActivity`)
            VStack(spacing: 6) {
                ForEach(targetSlots) { slot in
                    HStack(spacing: 10) {
                        OriginalSpriteOrFallbackIcon(
                            drawableName: slot.fishId == 0 ? "no_fish" : "fish_\(slot.fishId)",
                            fallbackSystemName: "fish.fill",
                            width: 56,
                            height: 38
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.fishName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(OriginalGameTheme.goldText)
                            Text("Условие: \(slot.conditionText)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        Text(slot.progressText)
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(slot.isSlotCompleted ? .green : .cyan)
                        if isRemasterMode {
                            Image(systemName: slot.isSlotCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(slot.isSlotCompleted ? RemasterHubPalette.sage : RemasterHubPalette.textSecondary)
                        } else {
                            OriginalSpriteOrFallbackIcon(
                                drawableName: slot.isSlotCompleted ? "tick" : "tick_empty",
                                fallbackSystemName: slot.isSlotCompleted ? "checkmark.circle.fill" : "circle",
                                width: 24,
                                height: 24
                            )
                        }
                    }
                    .padding(8)
                    .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }

            if quest.made == 1 {
                Button(action: onClaimReward) {
                    OriginalStyledActionButtonLabel(
                        title: "Получить награду (+\(rewards.coins) руб, +\(rewards.experience) XP)",
                        minWidth: 260
                    )
                }
                .buttonStyle(RemasterSpringButtonStyle())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

    }
}

private struct AchievementRowView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let achievement: AchievementRecord
    let title: String
    let descriptionText: String

    private var cupDrawableName: String {
        switch achievement.level {
        case 3: return "gold"
        case 2: return "silver"
        case 1: return "bronz"
        default: return "no_achiv"
        }
    }

    var body: some View {
        if isRemasterMode {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 54, height: 54)
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "md_achiv_\(achievement.id)",
                        fallbackSystemName: "medal.fill",
                        width: 42,
                        height: 42
                    )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                    Text(descriptionText)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textSecondary)
                    HStack(spacing: 8) {
                        Text("Прогресс: \(achievement.score)")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(RemasterHubPalette.brass)
                        Text("Ранг \(achievement.level)/3")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(achievement.level > 0 ? RemasterHubPalette.sage : RemasterHubPalette.textSecondary)
                    }
                }
                Spacer(minLength: 4)
                OriginalSpriteOrFallbackIcon(
                    drawableName: cupDrawableName,
                    fallbackSystemName: "trophy.fill",
                    width: 36,
                    height: 36
                )
            }
            .padding(12)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

        } else {
            HStack(spacing: 12) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "md_achiv_\(achievement.id)",
                    fallbackSystemName: "medal.fill",
                    width: 48,
                    height: 48
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text(descriptionText)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Счёт: \(achievement.score)  •  Уровень: \(achievement.level)/3")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.cyan)
                }
                Spacer()
                OriginalSpriteOrFallbackIcon(
                    drawableName: cupDrawableName,
                    fallbackSystemName: "trophy.fill",
                    width: 36,
                    height: 36
                )
            }
            .padding(10)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct QuestRowView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let quest: QuestRecord
    let title: String
    let descriptionText: String
    let targetSlots: [QuestTargetSlotProgress]
    let rewards: (coins: Int, experience: Int)
    let playerCategory: Int
    let onClaimReward: () -> Void

    private var statusText: String {
        if quest.made >= 2 { return "Сдан" }
        if quest.made == 1 { return "Готов к сдаче!" }
        if playerCategory < quest.requiredCategory { return "Разряд \(quest.requiredCategory)" }
        return "В процессе"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(quest.id). \(title)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Spacer()
                Text(statusText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(quest.made >= 1 ? .green : .cyan)
                if isRemasterMode {
                    Image(systemName: quest.made >= 2 ? "checkmark.circle.fill" : (quest.made == 1 ? "seal.fill" : "circle"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(quest.made >= 1 ? RemasterHubPalette.sage : RemasterHubPalette.textSecondary)
                } else {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: quest.made >= 2 ? "tick" : "tick_empty",
                        fallbackSystemName: quest.made >= 2 ? "checkmark.circle.fill" : "circle",
                        width: 24,
                        height: 24
                    )
                }
            }
            Text(descriptionText)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
            Text("Награда: \(rewards.coins) руб • +\(rewards.experience) XP  •  Мин. разряд: \(quest.requiredCategory)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.green)

            ForEach(targetSlots) { slot in
                HStack {
                    Text("• \(slot.fishName) (\(slot.conditionText))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(slot.progressText)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(slot.isSlotCompleted ? .green : .cyan)
                }
            }

            if quest.made == 1 {
                Button(action: onClaimReward) {
                    OriginalStyledActionButtonLabel(
                        title: "Получить награду (+\(rewards.coins) руб, +\(rewards.experience) XP)",
                        minWidth: 230
                    )
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
        }
        .padding(10)
        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PersonalRecordRowView: View {
    @Environment(\.isRemasterMode) private var isRemasterMode
    let record: PersonalSpeciesRecord

    var body: some View {
        let isCaught = record.weightGrams > 0
        if isRemasterMode {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 68, height: 48)
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "fish_\(record.id)",
                        fallbackSystemName: "fish.fill",
                        width: 60,
                        height: 40
                    )
                    .opacity(isCaught ? 1.0 : 0.35)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("#\(record.id) \(record.fishName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isCaught ? RemasterHubPalette.textPrimary : RemasterHubPalette.textSecondary)
                    Text(isCaught ? "Личный рекорд: \(PlayerStateRepository.formatGramsAsKgOrGrams(record.weightGrams))" : "Ещё не поймана")
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(isCaught ? RemasterHubPalette.sage : RemasterHubPalette.textSecondary.opacity(0.75))
                }
                Spacer()
                if isCaught {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RemasterHubPalette.brass)
                }
            }
            .padding(10)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

        } else {
            HStack(spacing: 12) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "fish_\(record.id)",
                    fallbackSystemName: "fish.fill",
                    width: 64,
                    height: 44
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.fishName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Text(isCaught ? "Рекорд: \(record.weightGrams) г" : "Ещё не поймана")
                        .font(.system(size: 13))
                        .foregroundStyle(isCaught ? .green : .white.opacity(0.6))
                }
                Spacer()
            }
            .padding(8)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - 6. Authentic `OnlineGameActivity` (`res/layout/online_game.xml` `res/74.xml`) & Modern Remaster Esports/Social Hub

public struct OnlineAndChatView: View {
    public enum OnlineSection: String, CaseIterable, Identifiable {
        case profile = "Облако"
        case chat = "Чат"
        case ratings = "Рейтинг"
        case tours = "Турниры"

        public var id: String { rawValue }

        var iconName: String {
            switch self {
            case .profile: return "icloud.and.arrow.up.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .ratings: return "medal.fill"
            case .tours: return "flag.2.crossed.fill"
            }
        }
    }

    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var selectedSection: OnlineSection = .profile
    @State private var chatDraft: String = ""

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: coordinator.isRemasterModeEnabled ? "Онлайн-центр и Турниры" : "Онлайн-игра и Чат",
                    subtitle: coordinator.chatConnectionState == .connected ? "В сети" : "Офлайн / HTTP"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                onlineSectionPicker

                if !coordinator.lastOnlineStatusMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RemasterHubPalette.sage)
                        Text(coordinator.lastOnlineStatusMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 14)
                }

                if coordinator.isRemasterModeEnabled {
                    remasterOnlineContentBody
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            switch selectedSection {
                            case .profile:
                                classicOnlineAuthSectionCard
                            case .chat:
                                classicOnlineChatSectionCard
                            case .ratings:
                                classicOnlineRatingsSectionCard
                            case .tours:
                                classicOnlineToursSectionCard
                            }
                        }
                        .padding(10)
                    }
                }
            }
        }
        .environment(\.isRemasterMode, coordinator.isRemasterModeEnabled)
    }

    private var onlineSectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(OnlineSection.allCases) { sec in
                let isSel = (selectedSection == sec)
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                        selectedSection = sec
                    }
                    switch sec {
                    case .ratings:
                        if coordinator.topPlayersRating.isEmpty && coordinator.worldSpeciesRecords.isEmpty {
                            coordinator.refreshOnlineRatingsAndRecordsLive(login: coordinator.savedOnlineLogin)
                        }
                    case .tours:
                        if coordinator.httpActiveTournaments.isEmpty
                            && coordinator.httpCompletedTournaments.isEmpty
                            && coordinator.tournamentTimetableLines.isEmpty {
                            coordinator.refreshOnlineTournamentsLive(login: coordinator.savedOnlineLogin)
                        }
                    case .chat:
                        if coordinator.chatConnectionState == .disconnected {
                            coordinator.connectLiveTCPChat(login: coordinator.savedOnlineLogin)
                        }
                    case .profile:
                        break
                    }
                } label: {
                    if coordinator.isRemasterModeEnabled {
                        HStack(spacing: 5) {
                            Image(systemName: sec.iconName)
                                .font(.system(size: 11, weight: .bold))
                            Text(sec.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(isSel ? .black : RemasterHubPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isSel ? RemasterHubPalette.brass : RemasterHubPalette.cardBg, in: Capsule())
                    } else {
                        OriginalStyledActionButtonLabel(title: sec.rawValue, minWidth: 78)
                            .opacity(isSel ? 1.0 : 0.65)
                    }
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Remaster 4.0 Modern Online Sections

    @ViewBuilder
    private var remasterOnlineContentBody: some View {
        switch selectedSection {
        case .profile:
            remasterOnlineProfileView
        case .chat:
            remasterOnlineChatMessengerView
        case .ratings:
            remasterOnlineRatingsLeaderboardView
        case .tours:
            remasterOnlineTournamentsHubView
        }
    }

    private var remasterOnlineProfileView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // 1. Cloud Account Card with Custom Dark Input Fields
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(RemasterHubPalette.brass.opacity(0.18))
                                .frame(width: 48, height: 48)
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(RemasterHubPalette.brass)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Облачный аккаунт рыболова")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Text("Сервер: \(FishingIOSAppConfiguration.chatServerHost):\(FishingIOSAppConfiguration.chatServerPort)")
                                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                        }
                        Spacer()
                    }

                    // Custom dark-glass Login field (no ugly white roundedBorder!)
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RemasterHubPalette.brass)
                            .frame(width: 20)
                        TextField("Логин или e-mail", text: $coordinator.savedOnlineLogin)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Custom dark-glass Password field
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RemasterHubPalette.brass)
                            .frame(width: 20)
                        SecureField("Пароль от аккаунта", text: $coordinator.savedOnlinePassword)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Side-by-side Primary Login & Register Buttons
                    HStack(spacing: 10) {
                        Button {
                            coordinator.authenticateOnlineProfileLive(
                                login: coordinator.savedOnlineLogin,
                                password: coordinator.savedOnlinePassword
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Войти")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RemasterHubPalette.brass, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(RemasterSpringButtonStyle())

                        Button {
                            coordinator.registerOnlineAccountLive(
                                loginOrEmail: coordinator.savedOnlineLogin,
                                password: coordinator.savedOnlinePassword
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.plus")
                                Text("Регистрация")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(RemasterSpringButtonStyle())
                    }
                }
                .padding(14)
                .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                // 2. 2-Column Cloud Sync & Server Rewards Cards
                HStack(spacing: 10) {
                    Button {
                        coordinator.syncAchievementsAndQuestsLive(
                            login: coordinator.savedOnlineLogin,
                            password: coordinator.savedOnlinePassword,
                            includeQuests: false,
                            silent: false
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(RemasterHubPalette.sage)
                            Text("Синхронизация")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Text("Сохранить разряд, квесты и медали на сервер")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(RemasterSpringButtonStyle())

                    Button {
                        coordinator.claimServerRewardsLive(
                            login: coordinator.savedOnlineLogin,
                            password: coordinator.savedOnlinePassword
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(RemasterHubPalette.brass)
                            Text("Награды сервера")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Text("Забрать призы за турниры и жемчуг")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                }

                if coordinator.isDebugOverlayEnabled {
                    Button(action: performSampleAuthRestore) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                            Text("Демо-восстановление профиля (офлайн-тест)")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.brass)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    private var remasterOnlineChatMessengerView: some View {
        VStack(spacing: 10) {
            // Room Header Bar
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(coordinator.chatConnectionState == .connected ? RemasterHubPalette.sage : Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Канал водоёма #\(coordinator.selectedPondIndex + 1)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                }
                Spacer()
                Button {
                    coordinator.connectLiveTCPChat(login: coordinator.savedOnlineLogin)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                        Text(coordinator.chatConnectionState == .connected ? "Переподключить" : "Подключиться")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RemasterHubPalette.brass, in: Capsule())
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 14)

            // Message Feed
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    if coordinator.chatMessages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                            Text("В чате водоёма пока тихо")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Text("Напишите сообщение ниже, чтобы поприветствовать рыболовов на локации.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        ForEach(coordinator.chatMessages) { msg in
                            RemasterChatBubbleRow(
                                message: msg,
                                isSelf: (msg.from ?? "") == coordinator.savedOnlineLogin && !coordinator.savedOnlineLogin.isEmpty
                            )
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            // Pinned Dark-Glass Composer Bar
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(RemasterHubPalette.textSecondary)
                    TextField("Написать в чат водоёма...", text: $chatDraft)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RemasterHubPalette.cardBg, in: Capsule())

                Button(action: sendDraftChatMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(RemasterHubPalette.brass, in: Circle())
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    private var remasterOnlineRatingsLeaderboardView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("МИРОВОЙ ЗАЛ СЛАВЫ")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.brass)
                    Spacer()
                    Button {
                        coordinator.refreshOnlineRatingsAndRecordsLive(login: coordinator.savedOnlineLogin)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Обновить")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(RemasterHubPalette.brass, in: Capsule())
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                }

                // Top-3 Podium Cards if available
                if coordinator.topPlayersRating.count >= 3 {
                    HStack(alignment: .bottom, spacing: 8) {
                        podiumCard(entry: coordinator.topPlayersRating[1], medal: "🥈", height: 96)
                        podiumCard(entry: coordinator.topPlayersRating[0], medal: "🥇", height: 112)
                        podiumCard(entry: coordinator.topPlayersRating[2], medal: "🥉", height: 88)
                    }
                }

                // Ranked Players List
                if !coordinator.topPlayersRating.isEmpty {
                    Text("Топ рыболовов по опыту")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)

                    ForEach(coordinator.topPlayersRating) { entry in
                        HStack(spacing: 12) {
                            Text("#\(entry.rankPosition)")
                                .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(entry.rankPosition <= 3 ? RemasterHubPalette.brass : RemasterHubPalette.textSecondary)
                                .frame(width: 34, alignment: .leading)

                            Text(entry.login)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)

                            Spacer()

                            Text("Разр. \(entry.categoryRank)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.sage)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.28), in: Capsule())

                            Text("\(entry.experience) XP")
                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(RemasterHubPalette.brass)
                        }
                        .padding(11)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }

                // World Species Records
                if !coordinator.worldSpeciesRecords.isEmpty {
                    Text("Мировые рекорды по видам рыб")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)
                        .padding(.top, 4)

                    ForEach(coordinator.worldSpeciesRecords) { rec in
                        HStack(spacing: 10) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(RemasterHubPalette.brass)
                            Text(rec.fishName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(PlayerStateRepository.formatGramsAsKgOrGrams(rec.weightGrams))
                                    .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                                    .foregroundStyle(RemasterHubPalette.sage)
                                Text(rec.holderLogin)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.textSecondary)
                            }
                        }
                        .padding(11)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    private func podiumCard(entry: OnlinePlayerRatingEntry, medal: String, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(medal)
                .font(.system(size: 22))
            Text(entry.login)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(RemasterHubPalette.textPrimary)
                .lineLimit(1)
            Text("Разр. \(entry.categoryRank)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(RemasterHubPalette.brass)
            Text("\(entry.experience) XP")
                .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(RemasterHubPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, 6)
        .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var remasterOnlineTournamentsHubView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ОФИЦИАЛЬНЫЕ ТУРНИРЫ")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.brass)
                    Spacer()
                    Button {
                        coordinator.refreshOnlineTournamentsLive(login: coordinator.savedOnlineLogin)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Обновить")
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(RemasterHubPalette.brass, in: Capsule())
                    }
                    .buttonStyle(RemasterSpringButtonStyle())
                }

                if !coordinator.httpActiveTournaments.isEmpty {
                    ForEach(coordinator.httpActiveTournaments) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("🟢 АКТИВНЫЙ ТУРНИР")
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RemasterHubPalette.sage, in: Capsule())
                                Spacer()
                                if !entry.dateInfo.isEmpty {
                                    Text(entry.dateInfo)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(RemasterHubPalette.brass)
                                }
                            }
                            Text(entry.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                            if !entry.details.isEmpty {
                                Text(entry.details)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.textSecondary)
                            }
                            HStack(spacing: 8) {
                                Button {
                                    coordinator.registerInOnlineTournamentLive(tournamentId: entry.id, actionType: "1")
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "flag.checkered")
                                        Text("Участвовать")
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(RemasterHubPalette.sage, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                }
                                .buttonStyle(RemasterSpringButtonStyle())

                                Button {
                                    coordinator.fetchTournamentResultsLive(tournamentId: entry.id, isCompleted: false)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "list.number")
                                        Text("Таблица")
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(RemasterHubPalette.brass, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                }
                                .buttonStyle(RemasterSpringButtonStyle())
                            }
                        }
                        .padding(14)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                if let results = coordinator.activeTournamentResults {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ТАБЛИЦА ТУРНИРА #\(results.tournamentId) • УЧАСТНИКОВ: \(results.participantsCount)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.brass)
                        if results.leaderboardLines.isEmpty {
                            Text("Пока нет пойманных рыб в зачёте этого турнира.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textSecondary)
                        } else {
                            ForEach(Array(results.leaderboardLines.prefix(20).enumerated()), id: \.offset) { _, row in
                                Text(row)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(RemasterHubPalette.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RemasterHubPalette.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if !coordinator.httpCompletedTournaments.isEmpty {
                    Text("Завершённые турниры")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.textPrimary)

                    ForEach(coordinator.httpCompletedTournaments.prefix(12)) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.textPrimary)
                                if !entry.dateInfo.isEmpty {
                                    Text(entry.dateInfo)
                                        .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                                        .foregroundStyle(RemasterHubPalette.textSecondary)
                                }
                            }
                            Spacer()
                            Button {
                                coordinator.fetchTournamentResultsLive(tournamentId: entry.id, isCompleted: true)
                            } label: {
                                Text("Итоги")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(RemasterHubPalette.brass)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.28), in: Capsule())
                            }
                            .buttonStyle(RemasterSpringButtonStyle())
                        }
                        .padding(12)
                        .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                if !coordinator.tournamentTimetableLines.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📅 РАСПИСАНИЕ ТУРНИРОВ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.brass)
                        ForEach(Array(coordinator.tournamentTimetableLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(RemasterHubPalette.textPrimary)
                                .padding(.vertical, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if coordinator.httpActiveTournaments.isEmpty
                    && coordinator.httpCompletedTournaments.isEmpty
                    && coordinator.onlineTours.isEmpty
                    && coordinator.tournamentTimetableLines.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "trophy.circle")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(RemasterHubPalette.brass)
                        Text("Список турниров не загружен")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textPrimary)
                        Text("Нажмите «Обновить» справа вверху, чтобы получить актуальные турниры и расписание с сервера.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(RemasterHubPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(RemasterHubPalette.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Classic v1.81 Online Sections (Preserved when Remaster is OFF)

    private var classicOnlineAuthSectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Профиль и синхронизация")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(OriginalGameTheme.goldText)
            TextField("Логин", text: $coordinator.savedOnlineLogin)
                .textFieldStyle(.roundedBorder)
            SecureField("Пароль", text: $coordinator.savedOnlinePassword)
                .textFieldStyle(.roundedBorder)

            Button {
                coordinator.authenticateOnlineProfileLive(
                    login: coordinator.savedOnlineLogin,
                    password: coordinator.savedOnlinePassword
                )
            } label: {
                OriginalStyledActionButtonLabel(title: "Войти в аккаунт", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                coordinator.registerOnlineAccountLive(
                    loginOrEmail: coordinator.savedOnlineLogin,
                    password: coordinator.savedOnlinePassword
                )
            } label: {
                OriginalStyledActionButtonLabel(title: "Регистрация / Восстановление пароля", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                coordinator.syncAchievementsAndQuestsLive(
                    login: coordinator.savedOnlineLogin,
                    password: coordinator.savedOnlinePassword,
                    includeQuests: false,
                    silent: false
                )
            } label: {
                OriginalStyledActionButtonLabel(title: "Синхронизировать прогресс", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())

            Button {
                coordinator.claimServerRewardsLive(
                    login: coordinator.savedOnlineLogin,
                    password: coordinator.savedOnlinePassword
                )
            } label: {
                OriginalStyledActionButtonLabel(title: "Получить награды", minWidth: 240)
            }
            .buttonStyle(RemasterSpringButtonStyle())
        }
        .padding(12)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var classicOnlineChatSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Чат водоёма #\(coordinator.selectedPondIndex + 1)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Spacer()
                Button {
                    coordinator.connectLiveTCPChat(login: coordinator.savedOnlineLogin)
                } label: {
                    Text("Подключиться")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(OriginalGameTheme.goldText, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }

            ForEach(coordinator.chatMessages) { msg in
                ChatMessageRowView(message: msg)
            }

            HStack {
                TextField("Сообщение в чат...", text: $chatDraft)
                    .textFieldStyle(.roundedBorder)
                Button(action: sendDraftChatMessage) {
                    OriginalSpriteOrFallbackIcon(
                        drawableName: "on_ok",
                        fallbackSystemName: "paperplane.fill",
                        width: 38,
                        height: 38
                    )
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var classicOnlineRatingsSectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Лучшие игроки и рекорды рыб")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Spacer()
                Button {
                    coordinator.refreshOnlineRatingsAndRecordsLive(login: coordinator.savedOnlineLogin)
                } label: {
                    Text("Обновить")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(OriginalGameTheme.goldText, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }

            ForEach(coordinator.topPlayersRating) { entry in
                HStack {
                    Text("#\(entry.rankPosition) \(entry.login)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)
                    Spacer()
                    Text("Разр. \(entry.categoryRank) • \(entry.experience) XP")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 3)
            }

            ForEach(coordinator.worldSpeciesRecords) { rec in
                HStack {
                    Text(rec.fishName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(rec.weightGrams) г (\(rec.holderLogin))")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var classicOnlineToursSectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Онлайн-турниры")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Spacer()
                Button {
                    coordinator.refreshOnlineTournamentsLive(login: coordinator.savedOnlineLogin)
                } label: {
                    Text("Обновить")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(OriginalGameTheme.goldText, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(RemasterSpringButtonStyle())
            }

            ForEach(coordinator.httpActiveTournaments) { entry in
                Text(entry.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private func performSampleAuthRestore() {
        let sampleAuth = "15000;8500;Pantera:24:98|not|not|not|not;Kobra:3:95|not|not|not|not;Aligator:15:100|not|not|not|not;1:5:1|2:25:1;2|2|0"
        _ = try? coordinator.restoreFromOnlineAuthResponse(
            sampleAuth,
            login: coordinator.savedOnlineLogin,
            password: coordinator.savedOnlinePassword
        )
    }

    private func sendDraftChatMessage() {
        let text = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let mess = ChatMess(
            fromID: coordinator.authenticatedChatUserId,
            prem: coordinator.chatServerUserData.prem,
            room: Int32(coordinator.selectedPondIndex),
            from: coordinator.savedOnlineLogin,
            object: nil,
            text: text,
            timeEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
            to: "all"
        )
        if coordinator.chatConnectionState == .connected {
            coordinator.tcpChatSession.sendMess(mess)
        }
        let packet = JavaObjectStreamCodec.encodeMess(mess)
        _ = try? coordinator.receiveChatStreamPacket(packet, currentUserId: coordinator.authenticatedChatUserId)
        chatDraft = ""
    }
}

private struct RemasterChatBubbleRow: View {
    let message: ChatMess
    let isSelf: Bool

    var body: some View {
        let author = (message.from ?? "").isEmpty ? "Рыболов" : (message.from ?? "Рыболов")
        let initial = String(author.prefix(1)).uppercased()

        HStack(alignment: .bottom, spacing: 8) {
            if !isSelf {
                ZStack {
                    Circle()
                        .fill(RemasterHubPalette.cardElevated)
                        .frame(width: 30, height: 30)
                    Text(initial)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(RemasterHubPalette.brass)
                }
            } else {
                Spacer(minLength: 36)
            }

            VStack(alignment: isSelf ? .trailing : .leading, spacing: 3) {
                Text(author)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelf ? RemasterHubPalette.sage : RemasterHubPalette.brass)

                Text(message.text ?? "")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(RemasterHubPalette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isSelf ? RemasterHubPalette.sage.opacity(0.28) : RemasterHubPalette.cardBg,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }

            if !isSelf {
                Spacer(minLength: 36)
            }
        }
    }
}

private struct ChatMessageRowView: View {
    let message: ChatMess

    var body: some View {
        HStack(alignment: .top) {
            Text("\(message.from ?? "Игрок"):")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(OriginalGameTheme.goldText)
            Text(message.text ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.white)
        }
    }
}
