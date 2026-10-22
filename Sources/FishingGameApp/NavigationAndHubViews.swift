import SwiftUI
import FishingCore
import FishingDatabase

/// Root container view providing tab navigation between the Fishing Pond (`GameActivity`),
/// Base Hub (`MainActivity` / `PondListActivity`), Shop (`ShopActivity`),
/// Inventory/Backpack (`BackpackActivity`), and Fishnet (`Fishnet` / `MyRecordsActivity`).
public struct FishingRootView: View {
    @StateObject private var coordinator: FishingAppCoordinator

    public init(coordinator: FishingAppCoordinator? = nil) {
        if let coordinator {
            _coordinator = StateObject(wrappedValue: coordinator)
        } else {
            let resolved = try! FishingAppCoordinator()
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
