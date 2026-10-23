import SwiftUI
import FishingCore
import FishingDatabase

/// Root container view providing tab navigation between the Fishing Pond (`GameActivity`),
/// Base Hub (`MainActivity` / `PondListActivity`), Shop (`ShopActivity`),
/// Inventory/Backpack (`BackpackActivity`), Fishnet (`Fishnet`), and Progress (`Achievements` / `Quests` / `MyRecordsActivity`).
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
        TabView(selection: $coordinator.selectedTab) {
            FishingPondView(coordinator: coordinator)
                .tabItem {
                    Label(AppNavigationTab.fishingPond.titleRu, systemImage: AppNavigationTab.fishingPond.systemIconName)
                }
                .tag(AppNavigationTab.fishingPond)

            NavigationStack {
                BaseHubView(coordinator: coordinator)
            }
            .tabItem {
                Label(AppNavigationTab.baseHub.titleRu, systemImage: AppNavigationTab.baseHub.systemIconName)
            }
            .tag(AppNavigationTab.baseHub)

            NavigationStack {
                ShopView(coordinator: coordinator)
            }
            .tabItem {
                Label(AppNavigationTab.shop.titleRu, systemImage: AppNavigationTab.shop.systemIconName)
            }
            .tag(AppNavigationTab.shop)

            NavigationStack {
                InventoryView(coordinator: coordinator)
            }
            .tabItem {
                Label(AppNavigationTab.inventory.titleRu, systemImage: AppNavigationTab.inventory.systemIconName)
            }
            .tag(AppNavigationTab.inventory)

            NavigationStack {
                FishnetView(coordinator: coordinator)
            }
            .tabItem {
                Label(AppNavigationTab.fishnet.titleRu, systemImage: AppNavigationTab.fishnet.systemIconName)
            }
            .tag(AppNavigationTab.fishnet)

            NavigationStack {
                ProgressAndRecordsView(coordinator: coordinator)
            }
            .tabItem {
                Label(AppNavigationTab.progress.titleRu, systemImage: AppNavigationTab.progress.systemIconName)
            }
            .tag(AppNavigationTab.progress)

            NavigationStack {
                OnlineAndChatView(coordinator: coordinator)
            }
            .tabItem {
                Label(AppNavigationTab.online.titleRu, systemImage: AppNavigationTab.online.systemIconName)
            }
            .tag(AppNavigationTab.online)
        }
        .alert(item: $coordinator.activeAlert) { alert in
            Alert(
                title: Text(alert.titleRu),
                message: Text(alert.messageRu),
                dismissButton: .default(Text("ОК"))
            )
        }
    }
}

// MARK: - 1. Base Hub & Pond Selection Screen (`MainActivity` + `PondListActivity`)

public struct BaseHubView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        List {
            Section("Профиль рыболова") {
                LabeledContent("Баланс монет", value: "\(coordinator.profile.balance)")
                LabeledContent("Опыт (XP)", value: "\(coordinator.profile.experience)")
                LabeledContent("Разряд", value: "\(coordinator.profile.category)")
                LabeledContent("Рыб в садке", value: "\(coordinator.fishnetEntries.count) / \(PlayerStateRepository.maxFishnetCapacity)")
            }

            Section("Графика и шейдер воды (Metal)") {
                Toggle("Анимация воды (WATER_SHADER)", isOn: $coordinator.isWaterShaderEnabled)
                LabeledContent(
                    "Статус 3-проходного шейдера F0.n",
                    value: coordinator.isWaterShaderActive ? "Активен (256×512 FBO)" : "Выключен (2D Canvas)"
                )
            }

            Section("Быстрые действия") {
                Button {
                    coordinator.buyAndEquipStarterKit()
                } label: {
                    Label("Купить и собрать стартовый набор снастей", systemImage: "wand.and.stars")
                }

                Button {
                    coordinator.sellAllFishInFishnet()
                } label: {
                    Label("Продать всю рыбу из садка", systemImage: "dollarsign.circle.fill")
                }
                .disabled(coordinator.fishnetEntries.isEmpty)
            }

            Section("Водоёмы (\(coordinator.availablePonds.count))") {
                ForEach(coordinator.availablePonds) { pond in
                    Button {
                        coordinator.selectPond(pondIndex: pond.id)
                        if coordinator.selectedPondIndex == pond.id {
                            coordinator.selectedTab = .fishingPond
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pond.nameRu.capitalized)
                                    .font(.headline)
                                Text("Разряд: \(pond.requiredRank)\(pond.requiresCoupon ? " • Нужен купон" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if coordinator.selectedPondIndex == pond.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("База рыболова")
    }
}

// MARK: - 2. Offline Coin Shop Screen (`ShopActivity`)

public struct ShopView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        List {
            Section {
                HStack {
                    Text("Ваш баланс:")
                    Spacer()
                    Text("\(coordinator.profile.balance) монет")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                Button {
                    coordinator.buyAndEquipStarterKit()
                } label: {
                    Label("Быстрый старт: купить и надеть комплект новичка", systemImage: "bag.badge.plus")
                }
            }

            Section("Удилища (слотов \(coordinator.ownedRods.count)/5)") {
                ForEach(coordinator.catalogRods) { rod in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(rod.name)
                                .font(.headline)
                            Text("Макс. вес: \(rod.weight) кг")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("\(rod.price) мон.") {
                            coordinator.buyRod(baseRodId: rod.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Катушки (слотов \(coordinator.ownedCoils.count)/5)") {
                ForEach(coordinator.catalogCoils) { coil in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(coil.name)
                                .font(.headline)
                            Text("Подшипников: \(coil.bearingCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("\(coil.price) мон.") {
                            coordinator.buyCoil(baseCoilId: coil.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Лески (слотов \(coordinator.ownedLines.count)/5)") {
                ForEach(coordinator.catalogLines) { line in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(line.name)
                                .font(.headline)
                            Text("Прочность: \(line.weight) кг • Длина: \(line.stockLength) м")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("\(line.price) мон.") {
                            coordinator.buyLine(baseLineId: line.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Крючки (слотов \(coordinator.ownedHooks.count)/5)") {
                ForEach(coordinator.catalogHooks) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.spec.name)
                                .font(.headline)
                            Text("В пачке: \(item.stockAmount) шт.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("\(item.spec.price) мон.") {
                            coordinator.buyHook(baseHookId: item.spec.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section("Наживки (видов \(coordinator.ownedBaits.count)/10)") {
                ForEach(coordinator.catalogBaits) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.spec.name.capitalized)
                                .font(.headline)
                            Text("Запас: +\(item.stockAmount) шт.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("\(item.spec.price) мон.") {
                            coordinator.buyBait(baseBaitId: item.spec.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("Магазин снастей")
    }
}

// MARK: - 3. Inventory / Backpack Screen (`BackpackActivity`)

public struct InventoryView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        List {
            Section("Статус собранной удочки") {
                LabeledContent("Снасть готова к забросу", value: coordinator.assembledTackle.isComplete ? "Да ✅" : "Нет ⚠️")
                if !coordinator.assembledTackle.isComplete {
                    Text("Не хватает: \(coordinator.assembledTackle.missingComponentNames().joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Удилища (\(coordinator.ownedRods.count)/5)") {
                ForEach(coordinator.ownedRods) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(item.rod.name) (\(item.rod.weight) кг)")
                            Text("Износ: \(item.strength)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if coordinator.tackleSlots.fishingRodId == item.id {
                            Button("Снять") { coordinator.equipRod(rowId: nil) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Надеть") { coordinator.equipRod(rowId: item.id) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            Section("Катушки (\(coordinator.ownedCoils.count)/5)") {
                ForEach(coordinator.ownedCoils) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(item.coil.name) (подш. \(item.coil.bearingCount))")
                            Text("Прочность: \(item.strength)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if coordinator.tackleSlots.coilId == item.id {
                            Button("Снять") { coordinator.equipCoil(rowId: nil) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Надеть") { coordinator.equipCoil(rowId: item.id) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            Section("Лески (\(coordinator.ownedLines.count)/5)") {
                ForEach(coordinator.ownedLines) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(item.line.name) (\(item.line.weight) кг)")
                            Text("Остаток длины: \(item.length) м")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if coordinator.tackleSlots.fishingLineId == item.id {
                            Button("Снять") { coordinator.equipLine(rowId: nil) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Надеть") { coordinator.equipLine(rowId: item.id) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            Section("Крючки (\(coordinator.ownedHooks.count)/5)") {
                ForEach(coordinator.ownedHooks) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.hook.name)
                            Text("Осталось: \(item.amount) шт.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if coordinator.tackleSlots.hookId == item.id {
                            Button("Снять") { coordinator.equipHook(rowId: nil) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Надеть") { coordinator.equipHook(rowId: item.id) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            Section("Наживки (\(coordinator.ownedBaits.count)/10)") {
                ForEach(coordinator.ownedBaits) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.bait.name.capitalized)
                            Text("Осталось: \(item.amount) шт.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if coordinator.tackleSlots.baitId == item.id {
                            Button("Снять") { coordinator.equipBait(rowId: nil) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("Надеть") { coordinator.equipBait(rowId: item.id) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Рюкзак")
    }
}

// MARK: - 4. Fishnet & Sale Screen (`Fishnet` + `MainActivity$e`)

public struct FishnetView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    private var totalFishnetValue: Int {
        coordinator.fishnetEntries.reduce(0) { $0 + $1.caughtFish.sellingPriceCoins }
    }

    public var body: some View {
        List {
            Section("Сводка садка") {
                LabeledContent("Заполнено", value: "\(coordinator.fishnetEntries.count) / \(PlayerStateRepository.maxFishnetCapacity)")
                LabeledContent("Общая стоимость улова", value: "\(totalFishnetValue) монет")
                Button {
                    coordinator.sellAllFishInFishnet()
                } label: {
                    Label("Продать весь улов (+\(totalFishnetValue) монет)", systemImage: "banknote.fill")
                }
                .disabled(coordinator.fishnetEntries.isEmpty)
            }

            Section("Пойманная рыба") {
                if coordinator.fishnetEntries.isEmpty {
                    Text("Садок пуст. Перейдите на вкладку «Водоём», чтобы забросить удочку.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(coordinator.fishnetEntries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.caughtFish.fish.name)
                                    .font(.headline)
                                Text("Вес: \(entry.caughtFish.weightGrams) г")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(entry.caughtFish.sellingPriceCoins) мон.")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Садок")
    }
}

// MARK: - 5. Progress, Personal Species Records, Quests & Achievements Screen (`MyRecordsActivity` + `F0.o`)

public struct ProgressAndRecordsView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    private static let achievementTitlesRu: [Int: (String, String)] = [
        1: ("Завсегдатай", "Заходи порыбачить каждый день"),
        2: ("Большой улов", "Поймай много рыб"),
        3: ("Хулиган", "Ломает много удилищ"),
        4: ("Любитель заданий", "Выполняй задания"),
        5: ("Временщик", "Участвуй в турнирах с регистрацией"),
        6: ("Инди-рыбак", "Создавай индивидуальные турниры"),
        7: ("Люблю 25", "Лови рыб со знаком 25 (сумма цифр веса = 25)"),
        8: ("Красавчик", "Одинаковые цифры — красивый вес (1111+, 2222+)"),
        9: ("Максималист", "Поймай крупную рыбу (рекорд веса)"),
        10: ("Богач", "Заработай кучу денег"),
        11: ("Транжира", "Выбрасывай снасти"),
        12: ("Редкий улов", "Поймай покрышку, ботинок, крокодила или клад"),
        13: ("Купонщик", "Купи много купонов"),
        14: ("Путешественник", "Открой все водоёмы")
    ]

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    private var caughtRecords: [PersonalSpeciesRecord] {
        coordinator.personalRecords.filter { $0.weightGrams > 0 }
    }

    public var body: some View {
        List {
            Section("Личные рекорды по видам рыб (\(caughtRecords.count))") {
                if caughtRecords.isEmpty {
                    Text("Пока нет пойманных рыб. Забросьте удочку на вкладке «Водоём»!")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(caughtRecords) { rec in
                        HStack {
                            Text(rec.fishName)
                                .font(.headline)
                            Spacer()
                            Text("\(rec.weightGrams) г")
                                .font(.subheadline.monospacedDigit().bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section("Квесты (\(coordinator.quests.filter { $0.made > 0 }.count)/\(coordinator.quests.count))") {
                ForEach(coordinator.quests) { quest in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Квест #\(quest.id) (тип \(quest.type), разряд \(quest.requiredCategory)+)")
                                .font(.headline)
                            Text("Цель (вес/кол-во): \(quest.weightCsv) / \(quest.numCsv) • Прогресс: \(quest.progressRes)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(quest.made > 0 ? "Выполнен ✅" : "В процессе")
                            .font(.caption.bold())
                            .foregroundStyle(quest.made > 0 ? .green : .blue)
                    }
                }
            }

            Section("Достижения (\(coordinator.achievements.count)/14)") {
                ForEach(coordinator.achievements) { ach in
                    let meta = Self.achievementTitlesRu[ach.id] ?? ("Достижение #\(ach.id)", "")
                    let thresholds = (ach.id >= 1 && ach.id <= BalanceTables.achievementThresholds.count)
                        ? BalanceTables.achievementThresholds[ach.id - 1]
                        : [0, 0, 0]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(ach.id). \(meta.0)")
                                .font(.headline)
                            Text("\(meta.1) • Пороги: \(thresholds.map(String.init).joined(separator: " / "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Ур. \(ach.level)/3")
                                .font(.caption.bold())
                                .foregroundStyle(ach.level > 0 ? .green : .secondary)
                            Text("Счёт: \(ach.score)")
                                .font(.caption2.monospacedDigit())
                        }
                    }
                }
            }
        }
        .navigationTitle("Рекорды и Квесты")
    }
}


// MARK: - 6. Online Profile, Pearl Shop, Tournaments & TCP Chat Screen (`OnlineGameActivity` + `Chat`)

public struct OnlineAndChatView: View {
    @ObservedObject public var coordinator: FishingAppCoordinator

    public init(coordinator: FishingAppCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        List {
            Section("Сетевой статус (fish-mob.ru / chat.fish-mob.ru:15701)") {
                LabeledContent("Логин", value: coordinator.profile.login.isEmpty ? "Офлайн-профиль" : coordinator.profile.login)
                LabeledContent("X-Fish-AppSign", value: String(FishingNetworkCrypto.appSignConstant.prefix(12)) + "…")
                LabeledContent("Жемчуг (POINTS)", value: "\(coordinator.onlineShopSnapshot?.pearlsBalance ?? 0)")
                LabeledContent("Уведомления (NOTES)", value: "\(coordinator.onlineShopSnapshot?.unreadNotesCount ?? 0)")
            }

            Section("Онлайн-турниры (Tours: \(coordinator.onlineTours.count))") {
                if coordinator.onlineTours.isEmpty {
                    Text("Нет активных онлайн-турниров в кэше.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(coordinator.onlineTours) { tour in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(tour.title) (ID #\(tour.id))")
                                .font(.headline)
                            Text("\(tour.desc) • Фонд: \(tour.fond)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Игроки онлайн (\(coordinator.onlineUsers.count))") {
                if coordinator.onlineUsers.isEmpty {
                    Text("Список игроков пуст.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(coordinator.onlineUsers) { user in
                        HStack {
                            Text("\(user.login) (разряд \(user.lv))")
                            Spacer()
                            Text("Водоём #\(user.pond + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Сообщения чата (\(coordinator.chatMessages.count))") {
                if coordinator.chatMessages.isEmpty {
                    Text("Сообщений пока нет.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(coordinator.chatMessages) { msg in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.from ?? "Игрок")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                            Text(msg.text ?? "")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Онлайн и Чат")
    }
}

#if FISHING_APP_EXECUTABLE
@main
public struct FishingForFriendsApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            FishingRootView()
        }
    }
}
#endif