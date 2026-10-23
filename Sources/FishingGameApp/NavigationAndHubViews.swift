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

/// Root container view replacing the generic iOS `TabView` with the authentic full-screen
/// screen switching of «Рыбалка для друзей» v1.81 (`SplashScreenActivity`, `MainActivity`, `PondListActivity`,
/// `GameActivity`, `ShopActivity`, `BackpackActivity`, `FishpondActivity`, `MyRecordsActivity`, `OnlineGameActivity`)
/// and the original `CatchDialog` (`C0.d`, `res/layout/catch_dialog.xml` `res/-w.xml`) overlay.
public struct FishingRootView: View {
    @StateObject private var coordinator: FishingAppCoordinator
    @State private var isShowingSplash: Bool
    private let gameClockTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

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
                activeScreenView
            }

            if let alert = coordinator.activeAlert {
                OriginalGameModalOverlay(alert: alert) {
                    coordinator.activeAlert = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowingSplash)
        .animation(.easeInOut(duration: 0.15), value: coordinator.activeAlert?.id)
        .onReceive(gameClockTimer) { _ in
            if !isShowingSplash {
                coordinator.stepGameClockMinute()
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

            VStack(spacing: 8) {
                ProgressView()
                    .tint(OriginalGameTheme.goldText)
                Text("Загрузка... (v\(versionString))")
                    .font(.system(size: 16, weight: .bold))
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
            }

            Button(action: onDismiss) {
                OriginalStyledActionButtonLabel(title: "ОК", minWidth: 120)
            }
            .buttonStyle(.plain)
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
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(OriginalModalCardBackground())
        .shadow(color: .black.opacity(0.8), radius: 14, x: 0, y: 6)
    }
}

private struct OriginalModalCardBackground: View {
    var body: some View {
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

// MARK: - Shared Original Screen Header (`@drawable/sback_r` + `@drawable/info_background`)

private struct OriginalScreenTopBar: View {
    let title: String
    let subtitle: String?
    let onBack: () -> Void

    init(title: String, subtitle: String? = nil, onBack: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                OriginalSpriteOrFallbackIcon(
                    drawableName: "sback_r",
                    fallbackSystemName: "chevron.backward.square.fill",
                    width: 34,
                    height: 40
                )
            }
            .buttonStyle(.plain)

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

private struct OriginalStyledActionButtonLabel: View {
    let title: String
    var minWidth: CGFloat = 100

    var body: some View {
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

private struct OriginalSecondBackgroundView: View {
    var body: some View {
        if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
            bg.resizable().ignoresSafeArea()
        } else {
            Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
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
}

public struct BaseHubView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var subScreen: BaseSubScreen = .mainDashboard

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
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
        }
    }
}

// MARK: - 1.1 `MainActivity` (`res/Yj.xml`)

private struct BaseDashboardSubView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen

    var body: some View {
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
                .buttonStyle(.plain)
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
                coordinator.activeAlert = .operationError(
                    message: "Рыбалка для Друзей — мобильный рыболовный симулятор! (версия 1.81)"
                )
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
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(OriginalGameTheme.goldText)
                }
                Spacer()
                Button {
                    coordinator.selectedTab = .fishingPond
                } label: {
                    OriginalStyledActionButtonLabel(title: "Ловить →", minWidth: 96)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
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
        .buttonStyle(.plain)
    }
}

// MARK: - 1.2 `PondListActivity` (`res/layout/gridview.xml` `res/Pa.xml` + `cellgrid.xml` `res/iy.xml`)

private struct PondListGridSubView: View {
    @ObservedObject var coordinator: FishingAppCoordinator
    @Binding var subScreen: BaseSubScreen

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 0) {
                OriginalScreenTopBar(
                    title: "Выбор водоёма (Локации)",
                    subtitle: "Ваш разряд: \(coordinator.profile.category)"
                ) {
                    subScreen = .mainDashboard
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(coordinator.availablePonds, id: \.id) { pond in
                            PondGridCellView(
                                pond: pond,
                                localizedName: coordinator.localeManager.pondName(for: pond).capitalized,
                                isSelected: coordinator.selectedPondIndex == pond.id,
                                isUnlocked: coordinator.profile.category >= pond.requiredRank
                                    && (!pond.requiresCoupon || coordinator.activeCoupon != nil)
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

private struct PondGridCellView: View {
    let pond: PondCatalogItem
    let localizedName: String
    let isSelected: Bool
    let isUnlocked: Bool
    let onSelect: () -> Void

    var body: some View {
        let pondNumber = max(1, min(15, pond.id + 1))
        let badgeText = pond.requiresCoupon ? "Разр. \(pond.requiredRank) • Купон" : "Разр. \(pond.requiredRank)"
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
        .buttonStyle(.plain)
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

    var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 12) {
                OriginalScreenTopBar(title: "О себе") {
                    subScreen = .mainDashboard
                }

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
            .buttonStyle(.plain)

            Button {
                subScreen = .mainDashboard
                coordinator.selectedTab = .progress
            } label: {
                OriginalStyledActionButtonLabel(title: "Энциклопедия и Рекорды (141 вид)", minWidth: 240)
            }
            .buttonStyle(.plain)

            Button {
                subScreen = .mainDashboard
                coordinator.selectedTab = .progress
            } label: {
                OriginalStyledActionButtonLabel(title: "Задания и Квесты (44)", minWidth: 240)
            }
            .buttonStyle(.plain)

            Button {
                subScreen = .mainDashboard
                coordinator.selectedTab = .progress
            } label: {
                OriginalStyledActionButtonLabel(title: "Достижения (14)", minWidth: 240)
            }
            .buttonStyle(.plain)
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
                        Button(action: syncDemoCatalog) {
                            OriginalStyledActionButtonLabel(title: "Обновить каталог (online.php)", minWidth: 260)
                        }
                        .buttonStyle(.plain)

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

                ScrollView {
                    VStack(spacing: 12) {
                        Toggle("Шейдер воды (WATER_SHADER)", isOn: $coordinator.isWaterShaderEnabled)
                            .foregroundStyle(OriginalGameTheme.goldText)
                        Toggle("Квесты и задания (TASKS)", isOn: $coordinator.tasksEnabled)
                            .foregroundStyle(OriginalGameTheme.goldText)
                        Toggle("Звуки (SOUND)", isOn: $coordinator.audioHaptics.soundEnabled)
                            .foregroundStyle(OriginalGameTheme.goldText)
                        Toggle("Вибрация (VIBRATION)", isOn: $coordinator.audioHaptics.vibrationEnabled)
                            .foregroundStyle(OriginalGameTheme.goldText)
                        Toggle("Панель отладки на водоёме (DEV)", isOn: $coordinator.isDebugOverlayEnabled)
                            .foregroundStyle(OriginalGameTheme.goldText)

                        HStack {
                            Text("Язык игры:")
                                .foregroundStyle(OriginalGameTheme.goldText)
                            Spacer()
                            Picker("Язык", selection: $coordinator.languageCode) {
                                ForEach(FishingLanguage.allCases, id: \.rawValue) { lang in
                                    Text(lang.displayName).tag(lang.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .padding(16)
                    .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 14)
                }
            }
        }
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

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 6) {
                OriginalScreenTopBar(
                    title: "Магазин",
                    subtitle: "Деньги: \(coordinator.profile.balance) руб"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                ShopCategoryStripView(selectedCategory: $selectedCategory)
                shopItemsScrollView
            }
        }
    }

    private var shopItemsScrollView: some View {
        ScrollView {
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

    private var shopRodsList: some View {
        ForEach(coordinator.catalogRods, id: \.id) { rod in
            ShopItemRowView(
                drawableName: "fishing_rods",
                title: rod.name,
                subtitle: "Макс. вес: \(rod.weight) кг  •  Прочность: 100%",
                priceCoins: rod.price,
                canAfford: coordinator.profile.balance >= rod.price
            ) {
                coordinator.buyRod(baseRodId: rod.id)
            }
        }
    }

    private var shopCoilsList: some View {
        ForEach(coordinator.catalogCoils, id: \.id) { coil in
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
        ForEach(coordinator.catalogLines, id: \.id) { line in
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
        ForEach(coordinator.catalogHooks) { hookItem in
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
        ForEach(coordinator.catalogBaits) { baitItem in
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
    @Binding var selectedCategory: ShopView.ShopCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ShopView.ShopCategory.allCases) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button {
                        selectedCategory = cat
                    } label: {
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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
        }
    }
}

private struct ShopItemRowView: View {
    let drawableName: String
    let title: String
    let subtitle: String
    let priceCoins: Int
    let canAfford: Bool
    let onBuy: () -> Void

    var body: some View {
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
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
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

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 6) {
                OriginalScreenTopBar(
                    title: "Рюкзак",
                    subtitle: coordinator.assembledTackle.isComplete ? "Снасть собрана" : "Не собрана"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                BackpackCategoryStripView(selectedCategory: $selectedCategory)
                backpackItemsScrollView
            }
        }
    }

    private var backpackItemsScrollView: some View {
        ScrollView {
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
    @Binding var selectedCategory: InventoryView.BackpackCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(InventoryView.BackpackCategory.allCases) { cat in
                    let isSelected = (selectedCategory == cat)
                    Button {
                        selectedCategory = cat
                    } label: {
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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
        }
    }
}

private struct BackpackItemRowView: View {
    let drawableName: String
    let title: String
    let subtitle: String
    let isEquipped: Bool
    let onEquip: () -> Void

    var body: some View {
        Button(action: onEquip) {
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
        .buttonStyle(.plain)
    }
}

// MARK: - 4. Authentic `FishpondActivity` (`Садок`, `res/layout/fishpond.xml` `res/1o.xml`)

public struct FishnetView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

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

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: "Садок",
                    subtitle: "\(coordinator.fishnetEntries.count) / \(PlayerStateRepository.maxFishnetCapacity)"
                ) {
                    coordinator.selectedTab = .baseHub
                }

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
                    .buttonStyle(.plain)
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
}

private struct FishnetSummaryPlaqueView: View {
    let totalWeightGrams: Int
    let fishCount: Int
    let totalValueCoins: Int

    var body: some View {
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

private struct FishnetEntryRowView: View {
    let entry: FishnetEntryRecord

    var body: some View {
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
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 5. Authentic `Records`, `Achievements` (`md_achiv_1..14`) & `Quests` (`res/JT.xml`, `res/zY.xml`, `res/DL.xml`)

public struct ProgressAndRecordsView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public enum SectionTab: String, CaseIterable, Identifiable {
        case achievements = "Достижения"
        case quests = "Квесты"
        case records = "Рекорды"

        public var id: String { rawValue }
    }

    @State private var selectedSection: SectionTab = .achievements

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(title: selectedSection.rawValue) {
                    coordinator.selectedTab = .baseHub
                }

                sectionTabPicker

                ScrollView {
                    VStack(spacing: 8) {
                        switch selectedSection {
                        case .achievements:
                            achievementsList
                        case .quests:
                            questsList
                        case .records:
                            recordsList
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var sectionTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(SectionTab.allCases) { tab in
                Button {
                    selectedSection = tab
                } label: {
                    OriginalStyledActionButtonLabel(title: tab.rawValue, minWidth: 96)
                        .opacity(selectedSection == tab ? 1.0 : 0.65)
                }
                .buttonStyle(.plain)
            }
        }
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

    private var questsList: some View {
        ForEach(coordinator.quests) { quest in
            QuestRowView(
                quest: quest,
                title: coordinator.localeManager.questTitle(id1Based: quest.id),
                descriptionText: coordinator.localeManager.questDescription(id1Based: quest.id)
            )
        }
    }

    private var recordsList: some View {
        ForEach(coordinator.personalRecords) { rec in
            PersonalRecordRowView(record: rec)
        }
    }
}

private struct AchievementRowView: View {
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
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct QuestRowView: View {
    let quest: QuestRecord
    let title: String
    let descriptionText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(quest.id). \(title)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OriginalGameTheme.goldText)
                Spacer()
                OriginalSpriteOrFallbackIcon(
                    drawableName: quest.made >= 2 ? "tick" : "tick_empty",
                    fallbackSystemName: quest.made >= 2 ? "checkmark.circle.fill" : "circle",
                    width: 24,
                    height: 24
                )
            }
            Text(descriptionText)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
            Text("Прогресс: [\(quest.progressRes)] / Цель: [\(quest.numCsv)]")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.cyan)
        }
        .padding(10)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PersonalRecordRowView: View {
    let record: PersonalSpeciesRecord

    var body: some View {
        let isCaught = record.weightGrams > 0
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
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 6. Authentic `OnlineGameActivity` (`res/layout/online_game.xml` `res/74.xml`) & TCP Chat (`res/QM.xml`)

public struct OnlineAndChatView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator
    @State private var loginInput: String = "angler_ios"
    @State private var passwordInput: String = "secret123"
    @State private var chatDraft: String = ""

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        ZStack {
            OriginalSecondBackgroundView()

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: "Онлайн-игра и Чат",
                    subtitle: "\(FishingIOSAppConfiguration.chatServerHost):\(FishingIOSAppConfiguration.chatServerPort)"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                ScrollView {
                    VStack(spacing: 12) {
                        onlineAuthSectionCard
                        onlineChatSectionCard
                    }
                    .padding(10)
                }
            }
        }
    }

    private var onlineAuthSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Авторизация профиля (auth.php)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(OriginalGameTheme.goldText)
            TextField("Логин", text: $loginInput)
                .textFieldStyle(.roundedBorder)
            SecureField("Пароль", text: $passwordInput)
                .textFieldStyle(.roundedBorder)
            Button(action: performSampleAuthRestore) {
                OriginalStyledActionButtonLabel(title: "Войти и синхронизировать профиль", minWidth: 240)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var onlineChatSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Чат водоёма #\(coordinator.selectedPondIndex + 1)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(OriginalGameTheme.goldText)

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
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private func performSampleAuthRestore() {
        let sampleAuth = "15000;8500;Pantera:24:98|not|not|not|not;Kobra:3:95|not|not|not|not;Aligator:15:100|not|not|not|not;1:5:1|2:25:1;2|2|0"
        _ = try? coordinator.restoreFromOnlineAuthResponse(
            sampleAuth,
            login: loginInput,
            password: passwordInput
        )
    }

    private func sendDraftChatMessage() {
        let text = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let packet = JavaObjectStreamCodec.encodeMess(
            ChatMess(
                fromID: 1,
                prem: 0,
                room: Int32(coordinator.selectedPondIndex),
                from: loginInput,
                object: nil,
                text: text,
                timeEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
                to: ""
            )
        )
        _ = try? coordinator.receiveChatStreamPacket(packet)
        chatDraft = ""
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