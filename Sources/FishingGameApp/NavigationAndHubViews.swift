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
/// screen switching of «Рыбалка для друзей» v1.81 (`MainActivity`, `PondListActivity`, `GameActivity`,
/// `ShopActivity`, `BackpackActivity`, `FishpondActivity`, `MyRecordsActivity`, `OnlineGameActivity`)
/// and the original `CatchDialog` (`C0.d`, `res/layout/catch_dialog.xml` `res/-w.xml`) overlay.
public struct FishingRootView: View {
    @StateObject private var coordinator: FishingAppCoordinator

    public init(coordinator: FishingAppCoordinator? = nil) {
        if let coordinator {
            _coordinator = StateObject(wrappedValue: coordinator)
        } else {
            let resolved = (try? AppBundleDatabaseBootstrapper.bootstrapAppCoordinator()) ?? (try! FishingAppCoordinator())
            _coordinator = StateObject(wrappedValue: resolved)
        }
    }

    public var body: some View {
        ZStack {
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

            if let alert = coordinator.activeAlert {
                OriginalGameModalOverlay(alert: alert) {
                    coordinator.activeAlert = nil
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: coordinator.activeAlert?.id)
    }
}

// MARK: - 0. Authentic `CatchDialog` (`C0.d`, `res/-w.xml`) & Game Alert Modal Overlay

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
                catchDialogCard(
                    fish: fish,
                    result: result,
                    isLucky25: isLucky25,
                    isRepdigit: isRepdigit,
                    isCleanerTrash: isCleanerTrash
                )
            default:
                standardGameDialogCard
            }
        }
    }

    /// Reconstructs `res/layout/catch_dialog.xml` (`res/-w.xml`, `C0.d`):
    /// - `catch_dialog_image`: caught fish photo `@drawable/fish_<id>`;
    /// - `catch_dialog_fish_name`: red (`#FF0000`) when `result.isNewPersonalRecord == true`;
    /// - `catch_dialog_fish_weight` + `@drawable/op25` badge when digit sum == 25;
    /// - `catch_dialog_fish_exp` + `"ОК"` button.
    private func catchDialogCard(
        fish: CaughtUserFish,
        result: CatchTransactionResult,
        isLucky25: Bool,
        isRepdigit: Bool,
        isCleanerTrash: Bool
    ) -> some View {
        VStack(spacing: 10) {
            // `catch_dialog_image` (`@drawable/fish_<id>`)
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

            // `catch_dialog_fish_name`
            Text(result.isNewPersonalRecord ? "\(fish.fish.name) (Рекорд!)" : fish.fish.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(result.isNewPersonalRecord ? OriginalGameTheme.recordRed : OriginalGameTheme.goldText)
                .multilineTextAlignment(.center)

            // `catch_dialog_fish_weight` + `@drawable/op25` (`res/-w.xml`)
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

            // `catch_dialog_fish_exp`
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

            // `catch_dialog_ok`
            Button(action: onDismiss) {
                OriginalStyledActionButtonLabel(title: "ОК", minWidth: 120)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(
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
        )
        .shadow(color: .black.opacity(0.8), radius: 14, x: 0, y: 6)
    }

    private var standardGameDialogCard: some View {
        VStack(spacing: 12) {
            Text(alert.titleRu)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OriginalGameTheme.goldText)
                .multilineTextAlignment(.center)

            Text(alert.messageRu)
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
        .background(
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
        )
        .shadow(color: .black.opacity(0.8), radius: 14, x: 0, y: 6)
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
            // `@id/back` (`@drawable/sback` -> `sback_r.png`)
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
            mainDashboardLayout
        case .pondListGrid:
            pondListGridScreen
        case .aboutMe:
            aboutMeScreen
        case .onlineShop:
            onlineShopScreen
        case .settings:
            settingsScreen
        }
    }

    // MARK: 1.1 `MainActivity` (`res/Yj.xml`: `@drawable/background`, `dashboard_time`, 4x3 `TableLayout` of 12 buttons, `info_background`)

    private var mainDashboardLayout: some View {
        ZStack {
            if let mainBg = OriginalGameAssetsLoader.image(named: "background") {
                mainBg
                    .resizable()
                    .ignoresSafeArea()
            } else {
                Color(red: 0.10, green: 0.18, blue: 0.14)
                    .ignoresSafeArea()
            }

            VStack(spacing: 8) {
                // `layout1`: Centered `dashboard_time` (`@drawable/time_background`) + right `top_chat_butt` (`@drawable/tchat`)
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

                // `view1` -> `layout4`: 4 rows x 3 columns `TableLayout` of 12 original dashboard buttons (`res/Yj.xml`)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Row 1: Магазин (`shop`), Рюкзак (`backpack`), Локации (`pond`)
                        HStack(spacing: 12) {
                            dashboardTile(drawable: "shop", fallbackIcon: "cart.fill", title: "Магазин") {
                                coordinator.selectedTab = .shop
                            }
                            dashboardTile(drawable: "backpack", fallbackIcon: "backpack.fill", title: "Рюкзак") {
                                coordinator.selectedTab = .inventory
                            }
                            dashboardTile(drawable: "pond", fallbackIcon: "water.waves", title: "Локации") {
                                subScreen = .pondListGrid
                            }
                        }

                        // Row 2: Продать рыбу (`evaluation`), Садок (`fishpond`), Рекорды (`records`)
                        HStack(spacing: 12) {
                            dashboardTile(drawable: "evaluation", fallbackIcon: "rublesign.circle.fill", title: "Продать рыбу") {
                                if coordinator.fishnetEntries.isEmpty {
                                    coordinator.activeAlert = .operationError(message: "Садок пуст")
                                } else {
                                    coordinator.sellAllFishInFishnet()
                                }
                            }
                            dashboardTile(drawable: "fishpond", fallbackIcon: "basket.fill", title: "Садок (\(coordinator.fishnetEntries.count))") {
                                coordinator.selectedTab = .fishnet
                            }
                            dashboardTile(drawable: "records", fallbackIcon: "trophy.fill", title: "Рекорды") {
                                coordinator.selectedTab = .progress
                            }
                        }

                        // Row 3: Онлайн-игра (`online`), О себе (`about_me`), Онлайн-магазин (`on_shop`)
                        HStack(spacing: 12) {
                            dashboardTile(drawable: "online", fallbackIcon: "globe", title: "Онлайн-игра") {
                                coordinator.selectedTab = .online
                            }
                            dashboardTile(drawable: "about_me", fallbackIcon: "person.crop.rectangle.fill", title: "О себе") {
                                subScreen = .aboutMe
                            }
                            dashboardTile(drawable: "on_shop", fallbackIcon: "sparkles", title: "Онлайн-магазин") {
                                subScreen = .onlineShop
                            }
                        }

                        // Row 4: Настройки (`settings`), Об игре (`about_game`), На водоём (`exit`)
                        HStack(spacing: 12) {
                            dashboardTile(drawable: "settings", fallbackIcon: "gearshape.fill", title: "Настройки") {
                                subScreen = .settings
                            }
                            dashboardTile(drawable: "about_game", fallbackIcon: "info.circle.fill", title: "Об игре") {
                                coordinator.activeAlert = .operationError(
                                    message: "Рыбалка для Друзей — мобильный рыболовный симулятор! (версия 1.81)"
                                )
                            }
                            dashboardTile(drawable: "exit", fallbackIcon: "play.circle.fill", title: "На водоём") {
                                coordinator.selectedTab = .fishingPond
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                // `layout3`: Bottom `@drawable/info_background` plaque (`dashboard_balance` & `dashboard_category`, `res/Yj.xml`)
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
                        if !coordinator.assembledTackle.isComplete {
                            Button {
                                coordinator.buyAndEquipStarterKit()
                            } label: {
                                OriginalStyledActionButtonLabel(title: "Стартовый набор", minWidth: 110)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                coordinator.selectedTab = .fishingPond
                            } label: {
                                OriginalStyledActionButtonLabel(title: "Ловить →", minWidth: 96)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
    }

    private func dashboardTile(
        drawable: String,
        fallbackIcon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
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

    // MARK: 1.2 `PondListActivity` (`res/layout/gridview.xml` `res/Pa.xml` + `cellgrid.xml` `res/iy.xml`)

    private var pondListGridScreen: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]

        return ZStack {
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

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
                            let pondNumber = max(1, min(15, pond.id + 1))
                            let isUnlocked = coordinator.profile.category >= pond.requiredRank
                                && (!pond.requiresCoupon || coordinator.activeCoupon != nil)
                            let localizedName = coordinator.localeManager
                                .localizedPondName(for: pond, fallbackIndex: pond.id)
                                .capitalized

                            Button {
                                coordinator.selectPond(pondIndex: pond.id)
                                if coordinator.selectedPondIndex == pond.id {
                                    subScreen = .mainDashboard
                                    coordinator.selectedTab = .fishingPond
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
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

                                        Text("Разр. \(pond.requiredRank)\(pond.requiresCoupon ? " • Купон" : "")")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                (isUnlocked ? Color.black.opacity(0.7) : Color.red.opacity(0.85)),
                                                in: RoundedRectangle(cornerRadius: 4)
                                            )
                                            .foregroundStyle(.white)
                                            .padding(4)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                coordinator.selectedPondIndex == pond.id
                                                    ? Color.green
                                                    : OriginalGameTheme.goldText.opacity(0.8),
                                                lineWidth: coordinator.selectedPondIndex == pond.id ? 2.5 : 1.5
                                            )
                                    )

                                    Text(localizedName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(OriginalGameTheme.goldText)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    // MARK: 1.3 `AboutMeActivity` (`res/layout/about_me.xml` `res/MT.xml`)

    private var aboutMeScreen: some View {
        let exp = coordinator.profile.experience
        let rank = coordinator.profile.category
        let thresholds = coordinator.balanceTables.categoryThresholds
        let nextThreshold: Int = (rank < thresholds.count) ? thresholds[rank] : exp
        let expToNext = max(0, nextThreshold - exp)

        return ZStack {
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

            VStack(spacing: 12) {
                OriginalScreenTopBar(title: "О себе") {
                    subScreen = .mainDashboard
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Group {
                            Text("Имя: \(coordinator.profile.login.isEmpty ? "Рыболов" : coordinator.profile.login)")
                            Text("Деньги: \(coordinator.profile.balance) руб")
                            Text("Разряд: \(rank)")
                            Text("Опыт: \(exp)")
                            Text("До следующего разряда: \(expToNext)")
                            Text("Купон: \(coordinator.activeCoupon != nil ? "\(coordinator.activeCoupon!.remainingTimeUnits) мин" : "нет")")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OriginalGameTheme.goldText)

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
                    .padding(18)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 14)
                }
            }
        }
    }

    // MARK: 1.4 `OnlineShopActivity` (`res/layout/online_shop.xml` `res/73.xml`)

    private var onlineShopScreen: some View {
        ZStack {
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

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
                            let sampleCSV = (0..<37).map { idx -> String in
                                switch idx {
                                case 0: return "250"
                                case 1, 2, 3: return "\(525 + (idx - 1) * 600)"
                                case 4, 5, 6: return "\(45 + (idx - 4) * 35)"
                                case 7, 8, 9: return "\(10 + (idx - 7) * 2)"
                                case 10, 11, 12: return "\(30 + (idx - 10) * 20)"
                                case 13, 14, 15: return "\(600 + (idx - 13) * 700)"
                                case 16, 17, 18: return "250"
                                case 19, 20, 21: return "\(25 + (idx - 19) * 15)"
                                case 30...36: return "\((idx - 29) * 10)"
                                default: return "0"
                                }
                            }.joined(separator: ",") + ",note=1"
                            _ = try? coordinator.syncOnlineShopFromCSV(sampleCSV)
                        } label: {
                            OriginalStyledActionButtonLabel(title: "Обновить каталог (online.php)", minWidth: 260)
                        }
                        .buttonStyle(.plain)

                        if let snap = coordinator.onlineShopSnapshot {
                            ForEach(0..<3, id: \.self) { idx in
                                HStack {
                                    OriginalSpriteOrFallbackIcon(
                                        drawableName: "fishing_rods",
                                        fallbackSystemName: "wand.and.rays",
                                        width: 42,
                                        height: 42
                                    )
                                    VStack(alignment: .leading) {
                                        Text("Онлайн-удилище #\(idx + 11)")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(OriginalGameTheme.goldText)
                                        Text("Мощность: \(snap.onlineRodWeights[idx]) кг")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    Text("\(snap.onlineRodPearlPrices[idx]) жемч.")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.cyan)
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: 1.5 `SettingsActivity` (`res/layout/settings.xml` `res/yp.xml`)

    private var settingsScreen: some View {
        ZStack {
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

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
                        Toggle("Звуки (SOUND)", isOn: $coordinator.audioHaptics.isSoundEnabled)
                            .foregroundStyle(OriginalGameTheme.goldText)
                        Toggle("Вибрация (VIBRATION)", isOn: $coordinator.audioHaptics.isVibrationEnabled)
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
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

            VStack(spacing: 6) {
                OriginalScreenTopBar(
                    title: "Магазин",
                    subtitle: "Деньги: \(coordinator.profile.balance) руб"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                // `shop_gallery` (`@drawable/info_background` horizontal category strip, `res/Kz.xml`)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ShopCategory.allCases) { cat in
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
                                        .foregroundStyle(selectedCategory == cat ? .white : OriginalGameTheme.goldText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == cat
                                        ? Color.white.opacity(0.22)
                                        : Color.black.opacity(0.35),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                }

                // `shop_list` (`ListView` with original sprites & `@drawable/sbuy_on` / `@drawable/sbuy_off`)
                ScrollView {
                    VStack(spacing: 8) {
                        switch selectedCategory {
                        case .rods:
                            ForEach(coordinator.catalogRods, id: \.id) { rod in
                                shopItemRow(
                                    drawableName: "fishing_rods",
                                    title: rod.name,
                                    subtitle: "Макс. вес: \(rod.weight) кг  •  Прочность: 100%",
                                    priceCoins: rod.price,
                                    canAfford: coordinator.profile.balance >= rod.price
                                ) {
                                    coordinator.buyRod(baseRodId: rod.id)
                                }
                            }
                        case .coils:
                            ForEach(coordinator.catalogCoils, id: \.id) { coil in
                                shopItemRow(
                                    drawableName: "coil",
                                    title: coil.name,
                                    subtitle: "Подшипников: \(coil.bearingCount)  •  Ресурс: \(coil.durabilityUnits) ед.",
                                    priceCoins: coil.price,
                                    canAfford: coordinator.profile.balance >= coil.price
                                ) {
                                    coordinator.buyCoil(baseCoilId: coil.id)
                                }
                            }
                        case .lines:
                            ForEach(coordinator.catalogLines, id: \.id) { line in
                                shopItemRow(
                                    drawableName: "fishing_line",
                                    title: line.name,
                                    subtitle: "Тест: \(line.weight) кг  •  Длина: \(line.stockLength) м",
                                    priceCoins: line.price,
                                    canAfford: coordinator.profile.balance >= line.price
                                ) {
                                    coordinator.buyLine(baseLineId: line.id)
                                }
                            }
                        case .hooks:
                            ForEach(coordinator.catalogHooks) { hook in
                                shopItemRow(
                                    drawableName: "hooks",
                                    title: hook.name,
                                    subtitle: "Упаковка: \(hook.stockAmount) шт.",
                                    priceCoins: hook.price,
                                    canAfford: coordinator.profile.balance >= hook.price
                                ) {
                                    coordinator.buyHook(baseHookId: hook.id)
                                }
                            }
                        case .baits:
                            ForEach(coordinator.catalogBaits) { bait in
                                let unlocked = coordinator.profile.category >= bait.requiredCategoryRank
                                shopItemRow(
                                    drawableName: "bait_\(bait.id)",
                                    title: bait.name.capitalized,
                                    subtitle: "Упаковка: \(bait.stockAmount) шт.  •  Разряд: \(bait.requiredCategoryRank)",
                                    priceCoins: bait.price,
                                    canAfford: unlocked && coordinator.profile.balance >= bait.price
                                ) {
                                    coordinator.buyBait(baseBaitId: bait.id)
                                }
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private func shopItemRow(
        drawableName: String,
        title: String,
        subtitle: String,
        priceCoins: Int,
        canAfford: Bool,
        onBuy: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            OriginalSpriteOrFallbackIcon(
                drawableName: drawableName,
                fallbackSystemName: "Takeoutbag.and.cup.and.straw.fill",
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
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

            VStack(spacing: 6) {
                OriginalScreenTopBar(
                    title: "Рюкзак",
                    subtitle: coordinator.assembledTackle.isComplete ? "Снасть собрана" : "Не собрана"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                // `backpack_gallery` (`@drawable/info_background`, `res/X1.xml`)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BackpackCategory.allCases) { cat in
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
                                        .foregroundStyle(selectedCategory == cat ? .white : OriginalGameTheme.goldText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedCategory == cat
                                        ? Color.white.opacity(0.22)
                                        : Color.black.opacity(0.35),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                }

                // `backpack_list`
                ScrollView {
                    VStack(spacing: 8) {
                        switch selectedCategory {
                        case .rods:
                            ForEach(coordinator.ownedRods) { rod in
                                backpackItemRow(
                                    drawableName: "fishing_rods",
                                    title: rod.name,
                                    subtitle: "Мощность: \(rod.maxWeightKg) кг  •  Прочность: \(rod.strength)%",
                                    isEquipped: coordinator.tackleSlots.fishingRodId == rod.id
                                ) {
                                    coordinator.equipRod(rowId: rod.id)
                                }
                            }
                        case .coils:
                            ForEach(coordinator.ownedCoils) { coil in
                                backpackItemRow(
                                    drawableName: "coil",
                                    title: coil.name,
                                    subtitle: "Подшипников: \(coil.bearingCount)  •  Прочность: \(coil.strength)%",
                                    isEquipped: coordinator.tackleSlots.coilId == coil.id
                                ) {
                                    coordinator.equipCoil(rowId: coil.id)
                                }
                            }
                        case .lines:
                            ForEach(coordinator.ownedLines) { line in
                                backpackItemRow(
                                    drawableName: "fishing_line",
                                    title: line.name,
                                    subtitle: "Тест: \(line.maxWeightKg) кг  •  Длина: \(line.lengthMeters) м",
                                    isEquipped: coordinator.tackleSlots.fishingLineId == line.id
                                ) {
                                    coordinator.equipLine(rowId: line.id)
                                }
                            }
                        case .hooks:
                            ForEach(coordinator.ownedHooks) { hook in
                                backpackItemRow(
                                    drawableName: "hooks",
                                    title: hook.name,
                                    subtitle: "В наличии: \(hook.count) шт.",
                                    isEquipped: coordinator.tackleSlots.hookId == hook.id
                                ) {
                                    coordinator.equipHook(rowId: hook.id)
                                }
                            }
                        case .baits:
                            ForEach(coordinator.ownedBaits) { bait in
                                backpackItemRow(
                                    drawableName: "bait_\(bait.baitId)",
                                    title: bait.name.capitalized,
                                    subtitle: "В наличии: \(bait.count) шт.",
                                    isEquipped: coordinator.tackleSlots.baitId == bait.id
                                ) {
                                    coordinator.equipBait(rowId: bait.id)
                                }
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private func backpackItemRow(
        drawableName: String,
        title: String,
        subtitle: String,
        isEquipped: Bool,
        onEquip: @escaping () -> Void
    ) -> some View {
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

    public var body: some View {
        let totalWeightGrams = coordinator.fishnetEntries.reduce(0) { $0 + $1.weightGrams }
        let totalValueCoins = coordinator.fishnetEntries.reduce(0) { $0 + $1.sellingPriceCoins }

        return ZStack {
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: "Садок",
                    subtitle: "\(coordinator.fishnetEntries.count) / \(PlayerStateRepository.maxFishnetCapacity)"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                // `linearLayout2` (`@drawable/time_background`, `fishpond_total_weight`, `fishpond_amount`, `res/1o.xml`)
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
                        Text("Количество рыб: \(coordinator.fishnetEntries.count) шт.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OriginalGameTheme.goldText)
                        Text("Стоимость улова: \(totalValueCoins) руб")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 10)

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

                // `fishpond_gallery` (`res/1o.xml` + `fishpond_gallery_item` `res/TE.xml`)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(coordinator.fishnetEntries) { entry in
                            HStack(spacing: 12) {
                                OriginalSpriteOrFallbackIcon(
                                    drawableName: "fish_\(entry.fishId)",
                                    fallbackSystemName: "fish.fill",
                                    width: 72,
                                    height: 48
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.fishName)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(OriginalGameTheme.goldText)
                                    Text("Вес: \(entry.weightGrams) г  •  Цена: \(entry.sellingPriceCoins) руб")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(10)
                }
            }
        }
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
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

            VStack(spacing: 8) {
                OriginalScreenTopBar(title: selectedSection.rawValue) {
                    coordinator.selectedTab = .baseHub
                }

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

                ScrollView {
                    VStack(spacing: 8) {
                        switch selectedSection {
                        case .achievements:
                            ForEach(coordinator.achievements) { ach in
                                HStack(spacing: 12) {
                                    OriginalSpriteOrFallbackIcon(
                                        drawableName: "md_achiv_\(ach.id)",
                                        fallbackSystemName: "medal.fill",
                                        width: 48,
                                        height: 48
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ach.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(OriginalGameTheme.goldText)
                                        Text("Счёт: \(ach.score)  •  Уровень: \(ach.level)/3")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    let cupName: String = {
                                        switch ach.level {
                                        case 3: return "gold"
                                        case 2: return "silver"
                                        case 1: return "bronz"
                                        default: return "no_achiv"
                                        }
                                    }()
                                    OriginalSpriteOrFallbackIcon(
                                        drawableName: cupName,
                                        fallbackSystemName: "trophy.fill",
                                        width: 36,
                                        height: 36
                                    )
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            }

                        case .quests:
                            ForEach(coordinator.quests) { quest in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("#\(quest.id). \(quest.name)")
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
                                    Text(quest.descriptionText)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.9))
                                    Text("Прогресс: [\(quest.progressCSV)] / Цель: [\(quest.requiredCountCSV)]")
                                        .font(.system(size: 11).monospacedDigit())
                                        .foregroundStyle(.cyan)
                                }
                                .padding(10)
                                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            }

                        case .records:
                            ForEach(coordinator.personalRecords) { rec in
                                HStack(spacing: 12) {
                                    OriginalSpriteOrFallbackIcon(
                                        drawableName: "fish_\(rec.id)",
                                        fallbackSystemName: "fish.fill",
                                        width: 64,
                                        height: 44
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rec.fishName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(OriginalGameTheme.goldText)
                                        Text(rec.maxWeightGrams > 0 ? "Рекорд: \(rec.maxWeightGrams) г" : "Ещё не поймана")
                                            .font(.system(size: 13))
                                            .foregroundStyle(rec.maxWeightGrams > 0 ? .green : .white.opacity(0.6))
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(10)
                }
            }
        }
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
            if let bg = OriginalGameAssetsLoader.image(named: "second_background") {
                bg.resizable().ignoresSafeArea()
            } else {
                Color(red: 0.08, green: 0.12, blue: 0.16).ignoresSafeArea()
            }

            VStack(spacing: 8) {
                OriginalScreenTopBar(
                    title: "Онлайн-игра и Чат",
                    subtitle: "\(FishingIOSAppConfiguration.chatServerHost):\(FishingIOSAppConfiguration.chatServerPort)"
                ) {
                    coordinator.selectedTab = .baseHub
                }

                ScrollView {
                    VStack(spacing: 12) {
                        // Auth & Profile Restore (`auth.php`)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Авторизация профиля (auth.php)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(OriginalGameTheme.goldText)
                            TextField("Логин", text: $loginInput)
                                .textFieldStyle(.roundedBorder)
                            SecureField("Пароль", text: $passwordInput)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                let sampleAuth = "15000;8500;Pantera:24:98|not|not|not|not;Kobra:3:95|not|not|not|not;Aligator:15:100|not|not|not|not;1:5:1|2:25:1;2|2|0"
                                _ = try? coordinator.restoreFromOnlineAuthResponse(
                                    sampleAuth,
                                    login: loginInput,
                                    password: passwordInput
                                )
                            } label: {
                                OriginalStyledActionButtonLabel(title: "Войти и синхронизировать профиль", minWidth: 240)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))

                        // Chat Room (`chat.fish-mob.ru:15701`)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Чат водоёма #\(coordinator.selectedPondIndex + 1)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(OriginalGameTheme.goldText)

                            ForEach(Array(coordinator.chatMessages.enumerated()), id: \.offset) { _, msg in
                                HStack(alignment: .top) {
                                    Text("\(msg.from):")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(OriginalGameTheme.goldText)
                                    Text(msg.text)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white)
                                }
                            }

                            HStack {
                                TextField("Сообщение в чат...", text: $chatDraft)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    let text = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !text.isEmpty else { return }
                                    let packet = JavaObjectStreamCodec.encodeMess(
                                        ChatMess(
                                            fromID: 1,
                                            prem: 0,
                                            room: Int32(coordinator.selectedPondIndex),
                                            from: loginInput,
                                            object: .null,
                                            text: text,
                                            timeMs: Int64(Date().timeIntervalSince1970 * 1000),
                                            to: ""
                                        )
                                    )
                                    _ = try? coordinator.receiveChatStreamPacket(packet)
                                    chatDraft = ""
                                } label: {
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
                    .padding(10)
                }
            }
        }
    }
}