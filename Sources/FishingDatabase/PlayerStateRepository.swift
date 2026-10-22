import Foundation
import FishingCore

public enum PlayerPersistenceError: Error, Sendable, Equatable {
    case itemNotFoundInCatalog(String, id: Int)
    case inventorySlotLimitReached(maxSlots: Int)
    case insufficientBalance(required: Int, available: Int)
    case insufficientCategoryRank(required: Int, current: Int)
    case onlineShopItemOnly(String, id: Int)
    case activeCouponAlreadyExists
    case integrityCheckFailed(String)
    case invalidInventoryItem(String)
}

public struct CatchTransactionResult: Sendable, Equatable {
    public let storedInFishnet: Bool
    public let fishnetCountAfter: Int
    public let overflowFcountAfter: Int
    public let experienceAwarded: Int
    public let totalExperienceAfter: Int
    public let categoryRankAfter: Int
    public let isNewPersonalRecord: Bool
}

public struct FishSaleTransactionResult: Sendable, Equatable {
    public let soldFishCount: Int
    public let coinsEarned: Int
    public let newBalance: Int
}

/// Manages mutable player state (`user_data`, `user_tackles`, `user_*` inventory, `user_fishes`,
/// `records`, `achievements`, `quests`, `data_signs`) with atomic SQLite transactions.
public final class PlayerStateRepository: Sendable {
    public static let initialNewPlayerBalance: Int = 500
    public static let initialNewPlayerExperience: Int = 0
    public static let initialNewPlayerCategory: Int = 0
    public static let maxEquipmentSlots: Int = 5
    public static let maxBaitSpeciesSlots: Int = 10
    public static let maxFishnetCapacity: Int = 50
    public static let minCategoryForCoupon: Int = 12

    public let connection: SQLiteConnection
    public let catalog: ReferenceCatalogStore
    public let installationUuid: String
    public let balanceTables: BalanceTables

    public init(
        connection: SQLiteConnection,
        catalog: ReferenceCatalogStore,
        installationUuid: String = "00000000-0000-0000-0000-000000000000",
        balanceTables: BalanceTables = BalanceTables()
    ) {
        self.connection = connection
        self.catalog = catalog
        self.installationUuid = installationUuid
        self.balanceTables = balanceTables
    }

    // MARK: - 1. Idempotent New Player Initialization (DatabaseHelper.onCreate)

    /// Initializes the singleton `user_data` (`id = 1`), `user_tackles` (`id = 1`), and `data_signs` (`id = 8`)
    /// if and only if they do not already exist. Calling this repeatedly is a safe no-op.
    public func initializeNewPlayerIfNeeded(nowMs: Int64 = 0) throws {
        try connection.transaction {
            let userCount = try connection.scalarInt("SELECT COUNT(*) FROM user_data WHERE id = 1;")
            if userCount == 0 {
                let md5 = FishingChecksum.userDataMd5(
                    balance: Self.initialNewPlayerBalance,
                    experience: Self.initialNewPlayerExperience,
                    category: Self.initialNewPlayerCategory,
                    date: nowMs,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT INTO user_data (id, login, password, balance, experience, category, date, md5)
                VALUES (1, '', '', ?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(Self.initialNewPlayerBalance)),
                    .integer(Int64(Self.initialNewPlayerExperience)),
                    .integer(Int64(Self.initialNewPlayerCategory)),
                    .integer(nowMs),
                    .text(md5)
                ])
            }

            let tackleCount = try connection.scalarInt("SELECT COUNT(*) FROM user_tackles WHERE id = 1;")
            if tackleCount == 0 {
                let sentinel = Int64(UserTackleSlotRecord.unequippedSentinel)
                try connection.run("""
                INSERT INTO user_tackles (id, fishing_rod_id, fishing_line_id, coil_id, hook_id, bait_id)
                VALUES (1, ?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(sentinel),
                    .integer(sentinel),
                    .integer(sentinel),
                    .integer(sentinel),
                    .integer(sentinel)
                ])
            }

            let sign8Count = try connection.scalarInt("SELECT COUNT(*) FROM data_signs WHERE id = 8;")
            if sign8Count == 0 {
                try updateUserFishesDataSign(nowMs: nowMs)
            }

            try connection.run("""
            INSERT OR IGNORE INTO player_runtime_counters (counter_key, counter_value)
            VALUES ('fcount', 0);
            """)
        }
    }

    // MARK: - 2. Loading & Saving Player State

    public func loadPlayerProfile() throws -> PlayerProfileRecord {
        let rows = try connection.query("""
        SELECT id, login, password, balance, experience, category, date, md5
        FROM user_data WHERE id = 1;
        """)
        guard let row = rows.first else {
            throw PlayerPersistenceError.invalidInventoryItem("user_data row id=1 is missing")
        }
        return PlayerProfileRecord(
            id: row.int("id"),
            login: row.string("login"),
            password: row.string("password"),
            balance: row.int("balance"),
            experience: row.int("experience"),
            category: row.int("category"),
            date: row.int64("date"),
            md5: row.string("md5")
        )
    }

    /// Verifies `user_data` MD5 (`MainActivity.Y`).
    public func verifyPlayerProfileIntegrity() throws -> Bool {
        let profile = try loadPlayerProfile()
        let expected = FishingChecksum.userDataMd5(
            balance: profile.balance,
            experience: profile.experience,
            category: profile.category,
            date: profile.date,
            installationUuid: installationUuid
        )
        return profile.md5 == expected
    }

    public func loadTackleSlots() throws -> UserTackleSlotRecord {
        let rows = try connection.query("""
        SELECT id, fishing_rod_id, fishing_line_id, coil_id, hook_id, bait_id
        FROM user_tackles WHERE id = 1;
        """)
        guard let row = rows.first else {
            return UserTackleSlotRecord()
        }
        return UserTackleSlotRecord(
            id: row.int("id"),
            fishingRodId: row.int("fishing_rod_id"),
            fishingLineId: row.int("fishing_line_id"),
            coilId: row.int("coil_id"),
            hookId: row.int("hook_id"),
            baitId: row.int("bait_id")
        )
    }

    public func saveTackleSlots(_ slots: UserTackleSlotRecord) throws {
        try connection.run("""
        UPDATE user_tackles SET
            fishing_rod_id = ?,
            fishing_line_id = ?,
            coil_id = ?,
            hook_id = ?,
            bait_id = ?
        WHERE id = 1;
        """, bindings: [
            .integer(Int64(slots.fishingRodId)),
            .integer(Int64(slots.fishingLineId)),
            .integer(Int64(slots.coilId)),
            .integer(Int64(slots.hookId)),
            .integer(Int64(slots.baitId))
        ])
    }

    /// Resolves `user_tackles` (`id = 1`) into a `FishingCore.AssembledTackle`.
    /// Exactly as in `GameView.q()` (`pc=0000..0075`), if an equipped ID points to a deleted row
    /// (e.g. broken rod/coil/line or exhausted bait/hook), the corresponding slot resolves to `nil`.
    public func loadAssembledTackle() throws -> AssembledTackle {
        let slots = try loadTackleSlots()
        let userRod = try loadUserRod(rowId: slots.fishingRodId)
        let userLine = try loadUserLine(rowId: slots.fishingLineId)
        let userCoil = try loadUserCoil(rowId: slots.coilId)
        let userHook = try loadUserHook(rowId: slots.hookId)
        let userBait = try loadUserBait(rowId: slots.baitId)

        return AssembledTackle(
            userRod: userRod,
            userLine: userLine,
            userCoil: userCoil,
            userHook: userHook,
            userBait: userBait
        )
    }

    public func loadUserRod(rowId: Int) throws -> UserRodItem? {
        guard rowId > 0 else { return nil }
        let rows = try connection.query(
            "SELECT id, fishing_rod, strength FROM user_fishing_rods WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first,
              let spec = try catalog.loadFishingRodSpec(id: row.int("fishing_rod")) else {
            return nil
        }
        return UserRodItem(id: row.int("id"), rod: spec, strength: row.int("strength"))
    }

    public func loadUserCoil(rowId: Int) throws -> UserCoilItem? {
        guard rowId > 0 else { return nil }
        let rows = try connection.query(
            "SELECT id, coil, strength FROM user_coils WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first,
              let spec = try catalog.loadCoilSpec(id: row.int("coil")) else {
            return nil
        }
        return UserCoilItem(id: row.int("id"), coil: spec, strength: row.int("strength"))
    }

    public func loadUserLine(rowId: Int) throws -> UserLineItem? {
        guard rowId > 0 else { return nil }
        let rows = try connection.query(
            "SELECT id, fishing_line, length FROM user_fishing_lines WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first,
              let spec = try catalog.loadFishingLineSpec(id: row.int("fishing_line")) else {
            return nil
        }
        return UserLineItem(id: row.int("id"), line: spec, length: row.int("length"))
    }

    public func loadUserHook(rowId: Int) throws -> UserHookItem? {
        guard rowId > 0 else { return nil }
        let rows = try connection.query(
            "SELECT id, hook, amount FROM user_hooks WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first,
              let spec = try catalog.loadHookSpec(id: row.int("hook")) else {
            return nil
        }
        return UserHookItem(id: row.int("id"), hook: spec, amount: row.int("amount"))
    }

    public func loadUserBait(rowId: Int) throws -> UserBaitItem? {
        guard rowId > 0 else { return nil }
        let rows = try connection.query(
            "SELECT id, bait, amount FROM user_baits WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first,
              let baitInfo = try catalog.loadBaitSpec(id: row.int("bait")) else {
            return nil
        }
        return UserBaitItem(id: row.int("id"), bait: baitInfo.spec, amount: row.int("amount"))
    }

    public func listUserRods() throws -> [UserRodItem] {
        let rows = try connection.query("SELECT id FROM user_fishing_rods ORDER BY id ASC;")
        return try rows.compactMap { try loadUserRod(rowId: $0.int("id")) }
    }

    public func listUserCoils() throws -> [UserCoilItem] {
        let rows = try connection.query("SELECT id FROM user_coils ORDER BY id ASC;")
        return try rows.compactMap { try loadUserCoil(rowId: $0.int("id")) }
    }

    public func listUserLines() throws -> [UserLineItem] {
        let rows = try connection.query("SELECT id FROM user_fishing_lines ORDER BY id ASC;")
        return try rows.compactMap { try loadUserLine(rowId: $0.int("id")) }
    }

    public func listUserHooks() throws -> [UserHookItem] {
        let rows = try connection.query("SELECT id FROM user_hooks ORDER BY id ASC;")
        return try rows.compactMap { try loadUserHook(rowId: $0.int("id")) }
    }

    public func listUserBaits() throws -> [UserBaitItem] {
        let rows = try connection.query("SELECT id FROM user_baits ORDER BY id ASC;")
        return try rows.compactMap { try loadUserBait(rowId: $0.int("id")) }
    }

    public func loadActiveCoupon() throws -> UserCouponItem? {
        let rows = try connection.query("SELECT id, coupon, time, date, md5 FROM user_coupon ORDER BY id ASC LIMIT 1;")
        guard let row = rows.first,
              let spec = try catalog.loadCouponSpec(id: row.int("coupon")) else {
            return nil
        }
        return UserCouponItem(
            id: row.int("id"),
            coupon: spec,
            remainingTimeUnits: row.int("time"),
            date: row.int64("date"),
            md5: row.string("md5")
        )
    }

    public func listFishnetEntries() throws -> [FishnetEntryRecord] {
        let fishCatalog = try catalog.loadFishCatalogById()
        let rows = try connection.query("""
        SELECT id, fish, weight, bait_index, pond_index, rod_weight, catch_time
        FROM user_fishes ORDER BY id ASC;
        """)
        return rows.compactMap { row in
            let fishId = row.int("fish")
            guard let species = fishCatalog[fishId] else { return nil }
            let caught = CaughtUserFish(
                fish: species,
                weightGrams: row.int("weight"),
                pondIndex: row.int("pond_index"),
                baitIndex: row.int("bait_index"),
                rodWeightKg: row.int("rod_weight"),
                catchTimeMs: row.int64("catch_time")
            )
            return FishnetEntryRecord(id: row.int("id"), caughtFish: caught)
        }
    }

    public func loadOverflowFcount() throws -> Int {
        try connection.scalarInt("SELECT COALESCE(counter_value, 0) FROM player_runtime_counters WHERE counter_key = 'fcount';")
    }

    public func loadPersonalRecord(fishId1Based: Int) throws -> PersonalSpeciesRecord? {
        let rows = try connection.query(
            "SELECT id, fish_name, weight, bait_id FROM records WHERE id = ?;",
            bindings: [.integer(Int64(fishId1Based))]
        )
        guard let row = rows.first else { return nil }
        return PersonalSpeciesRecord(
            id: row.int("id"),
            fishName: row.string("fish_name"),
            weightGrams: row.int("weight"),
            baitId1Based: row.int("bait_id")
        )
    }

    // MARK: - 3. Atomic Shop Purchase Transactions (LB0/a, c, d, e, f, g)

    /// Buys a fishing rod in the coin shop (`LB0/f.b`).
    /// Enforces `< 5` owned rods, `rod.price > 0 && rod.weight <= 179`, and `balance >= rod.price`.
    @discardableResult
    public func buyFishingRod(baseRodId: Int, nowMs: Int64) throws -> UserRodItem {
        try connection.transaction {
            guard let spec = try catalog.loadFishingRodSpec(id: baseRodId) else {
                throw PlayerPersistenceError.itemNotFoundInCatalog("fishing_rods", id: baseRodId)
            }
            let ownedCount = try connection.scalarInt("SELECT COUNT(*) FROM user_fishing_rods;")
            guard ownedCount < Self.maxEquipmentSlots else {
                throw PlayerPersistenceError.inventorySlotLimitReached(maxSlots: Self.maxEquipmentSlots)
            }
            guard spec.price > 0 && spec.weight <= 179 else {
                throw PlayerPersistenceError.onlineShopItemOnly("fishing_rods", id: baseRodId)
            }

            var profile = try loadPlayerProfile()
            guard profile.balance >= spec.price else {
                throw PlayerPersistenceError.insufficientBalance(required: spec.price, available: profile.balance)
            }

            let initialStrength = 100
            let rowId = Int(try connection.run("""
            INSERT INTO user_fishing_rods (fishing_rod, strength, date, md5)
            VALUES (?, ?, ?, '');
            """, bindings: [
                .integer(Int64(spec.id)),
                .integer(Int64(initialStrength)),
                .integer(nowMs)
            ]))

            let invMd5 = FishingChecksum.userInvMd5(
                rowId: rowId,
                baseItemId: spec.id,
                date: nowMs,
                attributeValue: initialStrength,
                installationUuid: installationUuid
            )
            try connection.run(
                "UPDATE user_fishing_rods SET md5 = ? WHERE id = ?;",
                bindings: [.text(invMd5), .integer(Int64(rowId))]
            )

            profile.balance -= spec.price
            try updateProfileBalanceAndExperience(profile)

            return UserRodItem(id: rowId, rod: spec, strength: initialStrength)
        }
    }

    /// Buys a reel/coil in the coin shop (`LB0/c.b`).
    /// Enforces `< 5` owned coils, `coil.price > 0 && coil.bearingCount <= 7`, and `balance >= coil.price`.
    @discardableResult
    public func buyCoil(baseCoilId: Int, nowMs: Int64) throws -> UserCoilItem {
        try connection.transaction {
            guard let spec = try catalog.loadCoilSpec(id: baseCoilId) else {
                throw PlayerPersistenceError.itemNotFoundInCatalog("coils", id: baseCoilId)
            }
            let ownedCount = try connection.scalarInt("SELECT COUNT(*) FROM user_coils;")
            guard ownedCount < Self.maxEquipmentSlots else {
                throw PlayerPersistenceError.inventorySlotLimitReached(maxSlots: Self.maxEquipmentSlots)
            }
            guard spec.price > 0 && spec.bearingCount <= 7 else {
                throw PlayerPersistenceError.onlineShopItemOnly("coils", id: baseCoilId)
            }

            var profile = try loadPlayerProfile()
            guard profile.balance >= spec.price else {
                throw PlayerPersistenceError.insufficientBalance(required: spec.price, available: profile.balance)
            }

            let initialStrength = 100
            let rowId = Int(try connection.run("""
            INSERT INTO user_coils (coil, strength, date, md5)
            VALUES (?, ?, ?, '');
            """, bindings: [
                .integer(Int64(spec.id)),
                .integer(Int64(initialStrength)),
                .integer(nowMs)
            ]))

            let invMd5 = FishingChecksum.userInvMd5(
                rowId: rowId,
                baseItemId: spec.id,
                date: nowMs,
                attributeValue: initialStrength,
                installationUuid: installationUuid
            )
            try connection.run(
                "UPDATE user_coils SET md5 = ? WHERE id = ?;",
                bindings: [.text(invMd5), .integer(Int64(rowId))]
            )

            profile.balance -= spec.price
            try updateProfileBalanceAndExperience(profile)

            return UserCoilItem(id: rowId, coil: spec, strength: initialStrength)
        }
    }

    /// Buys a fishing line in the coin shop (`LB0/e.b`).
    /// Enforces `< 5` owned lines, `line.price > 0 && line.stockLength <= 100 && line.weight <= 376`, and `balance >= line.price`.
    @discardableResult
    public func buyFishingLine(baseLineId: Int, nowMs: Int64) throws -> UserLineItem {
        try connection.transaction {
            guard let spec = try catalog.loadFishingLineSpec(id: baseLineId) else {
                throw PlayerPersistenceError.itemNotFoundInCatalog("fishing_lines", id: baseLineId)
            }
            let ownedCount = try connection.scalarInt("SELECT COUNT(*) FROM user_fishing_lines;")
            guard ownedCount < Self.maxEquipmentSlots else {
                throw PlayerPersistenceError.inventorySlotLimitReached(maxSlots: Self.maxEquipmentSlots)
            }
            guard spec.price > 0 && spec.stockLength <= 100 && spec.weight <= 376 else {
                throw PlayerPersistenceError.onlineShopItemOnly("fishing_lines", id: baseLineId)
            }

            var profile = try loadPlayerProfile()
            guard profile.balance >= spec.price else {
                throw PlayerPersistenceError.insufficientBalance(required: spec.price, available: profile.balance)
            }

            let rowId = Int(try connection.run("""
            INSERT INTO user_fishing_lines (fishing_line, length, date, md5)
            VALUES (?, ?, ?, '');
            """, bindings: [
                .integer(Int64(spec.id)),
                .integer(Int64(spec.stockLength)),
                .integer(nowMs)
            ]))

            let invMd5 = FishingChecksum.userInvMd5(
                rowId: rowId,
                baseItemId: spec.id,
                date: nowMs,
                attributeValue: spec.stockLength,
                installationUuid: installationUuid
            )
            try connection.run(
                "UPDATE user_fishing_lines SET md5 = ? WHERE id = ?;",
                bindings: [.text(invMd5), .integer(Int64(rowId))]
            )

            profile.balance -= spec.price
            try updateProfileBalanceAndExperience(profile)

            return UserLineItem(id: rowId, line: spec, length: spec.stockLength)
        }
    }

    /// Buys a pack of hooks in the coin shop (`LB0/g.b`).
    /// Note: in original bytecode `LB0/g.b`, hooks do NOT stack — each purchase creates a separate row
    /// in `user_hooks` with `amount = stockAmount` (5) up to `< 5` rows.
    @discardableResult
    public func buyHook(baseHookId: Int) throws -> UserHookItem {
        try connection.transaction {
            guard let spec = try catalog.loadHookSpec(id: baseHookId) else {
                throw PlayerPersistenceError.itemNotFoundInCatalog("hooks", id: baseHookId)
            }
            let stockAmount = try catalog.loadHookStockAmount(id: baseHookId)
            let ownedCount = try connection.scalarInt("SELECT COUNT(*) FROM user_hooks;")
            guard ownedCount < Self.maxEquipmentSlots else {
                throw PlayerPersistenceError.inventorySlotLimitReached(maxSlots: Self.maxEquipmentSlots)
            }
            guard stockAmount <= 5 else {
                throw PlayerPersistenceError.onlineShopItemOnly("hooks", id: baseHookId)
            }

            var profile = try loadPlayerProfile()
            guard profile.balance >= spec.price else {
                throw PlayerPersistenceError.insufficientBalance(required: spec.price, available: profile.balance)
            }

            let rowId = Int(try connection.run("""
            INSERT INTO user_hooks (hook, amount)
            VALUES (?, ?);
            """, bindings: [
                .integer(Int64(spec.id)),
                .integer(Int64(stockAmount))
            ]))

            profile.balance -= spec.price
            try updateProfileBalanceAndExperience(profile)

            return UserHookItem(id: rowId, hook: spec, amount: stockAmount)
        }
    }

    /// Buys bait in the coin shop (`LB0/a.b`).
    /// Enforces `COUNT(user_baits) < 10` before purchase (`pc=001d..0021`), stacks `amount += stockAmount`
    /// if the player already owns this bait species, or inserts a new row otherwise.
    @discardableResult
    public func buyBait(baseBaitId: Int) throws -> UserBaitItem {
        try connection.transaction {
            guard let baitInfo = try catalog.loadBaitSpec(id: baseBaitId) else {
                throw PlayerPersistenceError.itemNotFoundInCatalog("baits", id: baseBaitId)
            }
            let ownedCount = try connection.scalarInt("SELECT COUNT(*) FROM user_baits;")
            guard ownedCount < Self.maxBaitSpeciesSlots else {
                throw PlayerPersistenceError.inventorySlotLimitReached(maxSlots: Self.maxBaitSpeciesSlots)
            }

            var profile = try loadPlayerProfile()
            guard profile.balance >= baitInfo.spec.price else {
                throw PlayerPersistenceError.insufficientBalance(required: baitInfo.spec.price, available: profile.balance)
            }

            let existingRows = try connection.query(
                "SELECT id, amount FROM user_baits WHERE bait = ? LIMIT 1;",
                bindings: [.integer(Int64(baseBaitId))]
            )

            let finalRowId: Int
            let finalAmount: Int
            if let existing = existingRows.first {
                finalRowId = existing.int("id")
                finalAmount = existing.int("amount") + baitInfo.stockAmount
                try connection.run(
                    "UPDATE user_baits SET amount = ? WHERE id = ?;",
                    bindings: [.integer(Int64(finalAmount)), .integer(Int64(finalRowId))]
                )
            } else {
                finalAmount = baitInfo.stockAmount
                finalRowId = Int(try connection.run(
                    "INSERT INTO user_baits (bait, amount) VALUES (?, ?);",
                    bindings: [.integer(Int64(baseBaitId)), .integer(Int64(finalAmount))]
                ))
            }

            profile.balance -= baitInfo.spec.price
            try updateProfileBalanceAndExperience(profile)

            return UserBaitItem(id: finalRowId, bait: baitInfo.spec, amount: finalAmount)
        }
    }

    /// Buys a travel coupon (`LB0/d.b`).
    /// Enforces `COUNT(user_coupon) == 0`, `balance >= coupon.price`, `category >= 12`, and `time = dn * 10000`.
    @discardableResult
    public func buyCoupon(baseCouponId: Int, nowMs: Int64) throws -> UserCouponItem {
        try connection.transaction {
            guard let spec = try catalog.loadCouponSpec(id: baseCouponId) else {
                throw PlayerPersistenceError.itemNotFoundInCatalog("coupons", id: baseCouponId)
            }
            let existingCoupons = try connection.scalarInt("SELECT COUNT(*) FROM user_coupon;")
            guard existingCoupons == 0 else {
                throw PlayerPersistenceError.activeCouponAlreadyExists
            }

            var profile = try loadPlayerProfile()
            guard profile.balance >= spec.price else {
                throw PlayerPersistenceError.insufficientBalance(required: spec.price, available: profile.balance)
            }
            guard profile.category >= Self.minCategoryForCoupon else {
                throw PlayerPersistenceError.insufficientCategoryRank(
                    required: Self.minCategoryForCoupon,
                    current: profile.category
                )
            }
            guard spec.dn <= 2016 && spec.dayCount <= 7 else {
                throw PlayerPersistenceError.onlineShopItemOnly("coupons", id: baseCouponId)
            }

            let timeUnits = spec.dn * 10000
            let rowId = Int(try connection.run("""
            INSERT INTO user_coupon (coupon, time, date, md5)
            VALUES (?, ?, ?, '');
            """, bindings: [
                .integer(Int64(spec.id)),
                .integer(Int64(timeUnits)),
                .integer(nowMs)
            ]))

            let invMd5 = FishingChecksum.userInvMd5(
                rowId: rowId,
                baseItemId: spec.id,
                date: nowMs,
                attributeValue: timeUnits,
                installationUuid: installationUuid
            )
            try connection.run(
                "UPDATE user_coupon SET md5 = ? WHERE id = ?;",
                bindings: [.text(invMd5), .integer(Int64(rowId))]
            )

            profile.balance -= spec.price
            try updateProfileBalanceAndExperience(profile)

            return UserCouponItem(
                id: rowId,
                coupon: spec,
                remainingTimeUnits: timeUnits,
                date: nowMs,
                md5: invMd5
            )
        }
    }

    // MARK: - 4. Atomic Tackle Wear & Breakage Persistence (GameView$c.{j, k, l, m, n, v, y, z, A})

    /// Synchronizes the in-memory `AssembledTackle` after a cast/fight/catch/breakage back to SQLite
    /// inside an atomic transaction (`GameView$c.{j, k, l, m, n, v, y, z, A}`).
    /// If any item in `updatedTackle` became `nil` or its strength/length/amount dropped to `<= 0`,
    /// its row is deleted from `user_*` and its slot in `user_tackles` is reset to `-2147483648`.
    public func syncAssembledTackleAfterFight(_ updatedTackle: AssembledTackle) throws {
        try connection.transaction {
            var slots = try loadTackleSlots()

            // 1. Fishing Rod
            if slots.fishingRodId > 0 {
                if let rodItem = updatedTackle.userRod, rodItem.id == slots.fishingRodId, rodItem.strength > 0 {
                    try updateUserRodStrength(rowId: rodItem.id, newStrength: rodItem.strength)
                } else {
                    try connection.run("DELETE FROM user_fishing_rods WHERE id = ?;", bindings: [.integer(Int64(slots.fishingRodId))])
                    slots.fishingRodId = UserTackleSlotRecord.unequippedSentinel
                }
            }

            // 2. Fishing Line
            if slots.fishingLineId > 0 {
                if let lineItem = updatedTackle.userLine, lineItem.id == slots.fishingLineId, lineItem.length > 0 {
                    try updateUserLineLength(rowId: lineItem.id, newLength: lineItem.length)
                } else {
                    try connection.run("DELETE FROM user_fishing_lines WHERE id = ?;", bindings: [.integer(Int64(slots.fishingLineId))])
                    slots.fishingLineId = UserTackleSlotRecord.unequippedSentinel
                }
            }

            // 3. Coil
            if slots.coilId > 0 {
                if let coilItem = updatedTackle.userCoil, coilItem.id == slots.coilId, coilItem.strength > 0 {
                    try updateUserCoilStrength(rowId: coilItem.id, newStrength: coilItem.strength)
                } else {
                    try connection.run("DELETE FROM user_coils WHERE id = ?;", bindings: [.integer(Int64(slots.coilId))])
                    slots.coilId = UserTackleSlotRecord.unequippedSentinel
                }
            }

            // 4. Hook
            if slots.hookId > 0 {
                if let hookItem = updatedTackle.userHook, hookItem.id == slots.hookId, hookItem.amount > 0 {
                    try connection.run(
                        "UPDATE user_hooks SET amount = ? WHERE id = ?;",
                        bindings: [.integer(Int64(hookItem.amount)), .integer(Int64(hookItem.id))]
                    )
                } else {
                    try connection.run("DELETE FROM user_hooks WHERE id = ?;", bindings: [.integer(Int64(slots.hookId))])
                    slots.hookId = UserTackleSlotRecord.unequippedSentinel
                }
            }

            // 5. Bait
            if slots.baitId > 0 {
                if let baitItem = updatedTackle.userBait, baitItem.id == slots.baitId, baitItem.amount > 0 {
                    try connection.run(
                        "UPDATE user_baits SET amount = ? WHERE id = ?;",
                        bindings: [.integer(Int64(baitItem.amount)), .integer(Int64(baitItem.id))]
                    )
                } else {
                    try connection.run("DELETE FROM user_baits WHERE id = ?;", bindings: [.integer(Int64(slots.baitId))])
                    slots.baitId = UserTackleSlotRecord.unequippedSentinel
                }
            }

            try saveTackleSlots(slots)
        }
    }

    private func updateUserRodStrength(rowId: Int, newStrength: Int) throws {
        let rows = try connection.query(
            "SELECT fishing_rod, date FROM user_fishing_rods WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first else { return }
        let baseId = row.int("fishing_rod")
        let date = row.int64("date")
        let md5 = FishingChecksum.userInvMd5(
            rowId: rowId,
            baseItemId: baseId,
            date: date,
            attributeValue: newStrength,
            installationUuid: installationUuid
        )
        try connection.run(
            "UPDATE user_fishing_rods SET strength = ?, md5 = ? WHERE id = ?;",
            bindings: [.integer(Int64(newStrength)), .text(md5), .integer(Int64(rowId))]
        )
    }

    private func updateUserCoilStrength(rowId: Int, newStrength: Int) throws {
        let rows = try connection.query(
            "SELECT coil, date FROM user_coils WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first else { return }
        let baseId = row.int("coil")
        let date = row.int64("date")
        let md5 = FishingChecksum.userInvMd5(
            rowId: rowId,
            baseItemId: baseId,
            date: date,
            attributeValue: newStrength,
            installationUuid: installationUuid
        )
        try connection.run(
            "UPDATE user_coils SET strength = ?, md5 = ? WHERE id = ?;",
            bindings: [.integer(Int64(newStrength)), .text(md5), .integer(Int64(rowId))]
        )
    }

    private func updateUserLineLength(rowId: Int, newLength: Int) throws {
        let rows = try connection.query(
            "SELECT fishing_line, date FROM user_fishing_lines WHERE id = ?;",
            bindings: [.integer(Int64(rowId))]
        )
        guard let row = rows.first else { return }
        let baseId = row.int("fishing_line")
        let date = row.int64("date")
        let md5 = FishingChecksum.userInvMd5(
            rowId: rowId,
            baseItemId: baseId,
            date: date,
            attributeValue: newLength,
            installationUuid: installationUuid
        )
        try connection.run(
            "UPDATE user_fishing_lines SET length = ?, md5 = ? WHERE id = ?;",
            bindings: [.integer(Int64(newLength)), .text(md5), .integer(Int64(rowId))]
        )
    }

    // MARK: - 5. Atomic Fish Catch Transaction (LC0/d.l, LC0/d$a.onClick, LC0/d$e.a)

    /// Records a caught fish (`C0.d`):
    /// 1. Updates personal species record in `records` if `weightGrams > record.weight`;
    /// 2. Checks fishnet capacity (`< 50`): if `< 50`, verifies `DataSign` #8, inserts into `user_fishes`,
    ///    and updates `DataSign` #8; if `>= 50`, increments `fcount` without inserting into `user_fishes`;
    /// 3. Awards experience `(weightGrams / D0.d.a[fish.id - 1]) + 1`, updates `category` rank via `D0.d.h`,
    ///    and updates `user_data.md5`.
    @discardableResult
    public func recordCaughtFish(
        _ caught: CaughtUserFish,
        nowMs: Int64
    ) throws -> CatchTransactionResult {
        try connection.transaction {
            // 1. Personal record check (`LC0/d.l`, `pc=00e5..0128`)
            var isNewRecord = false
            if let existingRecord = try loadPersonalRecord(fishId1Based: caught.fish.id) {
                if caught.weightGrams > existingRecord.weightGrams {
                    isNewRecord = true
                    try connection.run("""
                    UPDATE records SET weight = ?, bait_id = ? WHERE id = ?;
                    """, bindings: [
                        .integer(Int64(caught.weightGrams)),
                        .integer(Int64(caught.baitIndex + 1)),
                        .integer(Int64(caught.fish.id))
                    ])
                }
            }

            // 2. Fishnet capacity check (`LC0/d$a.onClick`, `pc=000a..006c` & `LC0/d$e.a`)
            let currentFishnetCount = try connection.scalarInt("SELECT COUNT(*) FROM user_fishes;")
            var storedInFishnet = false
            var newFishnetCount = currentFishnetCount
            var overflowFcount = try loadOverflowFcount()

            if currentFishnetCount < Self.maxFishnetCapacity {
                if currentFishnetCount > 0 {
                    guard try catalog.verifyDataSign(.userFishes) else {
                        throw PlayerPersistenceError.integrityCheckFailed("DataSign #8 (user_fishes) mismatch before catch insert")
                    }
                }
                try connection.run("""
                INSERT INTO user_fishes (fish, weight, bait_index, pond_index, rod_weight, catch_time)
                VALUES (?, ?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(caught.fish.id)),
                    .integer(Int64(caught.weightGrams)),
                    .integer(Int64(caught.baitIndex)),
                    .integer(Int64(caught.pondIndex)),
                    .integer(Int64(caught.rodWeightKg)),
                    .integer(caught.catchTimeMs)
                ])
                storedInFishnet = true
                newFishnetCount = currentFishnetCount + 1
                try updateUserFishesDataSign(nowMs: nowMs)
            } else {
                overflowFcount += 1
                try connection.run("""
                INSERT INTO player_runtime_counters (counter_key, counter_value)
                VALUES ('fcount', ?)
                ON CONFLICT(counter_key) DO UPDATE SET counter_value = excluded.counter_value;
                """, bindings: [.integer(Int64(overflowFcount))])
            }

            // 3. Experience & rank promotion (`LC0/d$a.onClick`, `pc=0075..0101`)
            let xpGain = ProgressionCalculator.experienceGained(
                fishId1Based: caught.fish.id,
                weightGrams: caught.weightGrams,
                balanceTables: balanceTables
            )
            var profile = try loadPlayerProfile()
            profile.experience += xpGain
            profile.category = ProgressionCalculator.categoryForExperience(
                profile.experience,
                balanceTables: balanceTables
            )
            try updateProfileBalanceAndExperience(profile)

            return CatchTransactionResult(
                storedInFishnet: storedInFishnet,
                fishnetCountAfter: newFishnetCount,
                overflowFcountAfter: overflowFcount,
                experienceAwarded: xpGain,
                totalExperienceAfter: profile.experience,
                categoryRankAfter: profile.category,
                isNewPersonalRecord: isNewRecord
            )
        }
    }

    // MARK: - 6. Atomic Fishnet Sale Transaction (MainActivity$e.q & MainActivity$e.o)

    /// Sells all fish currently in `user_fishes` (`MainActivity$e.q()` + `MainActivity$e.o()`):
    /// 1. Verifies `DataSign` #1 (`fishes`) and `DataSign` #8 (`user_fishes`);
    /// 2. Computes each fish's price `Int((Double(weight) / Double(unitWeight)) * Double(unitPrice))`;
    /// 3. Deletes all rows from `user_fishes`, resets `fcount = 0`, updates `DataSign` #8,
    ///    and adds total revenue to `user_data.balance` with updated `UserDataMd5`.
    @discardableResult
    public func sellAllFish(nowMs: Int64) throws -> FishSaleTransactionResult {
        try connection.transaction {
            guard try catalog.verifyDataSign(.fishes) else {
                throw PlayerPersistenceError.integrityCheckFailed("DataSign #1 (fishes) mismatch during fish sale")
            }
            guard try catalog.verifyDataSign(.userFishes) else {
                throw PlayerPersistenceError.integrityCheckFailed("DataSign #8 (user_fishes) mismatch during fish sale")
            }

            let entries = try listFishnetEntries()
            var totalCoins = 0
            for entry in entries {
                totalCoins += entry.caughtFish.sellingPriceCoins
            }

            try connection.run("DELETE FROM user_fishes;")
            try connection.run("""
            INSERT INTO player_runtime_counters (counter_key, counter_value)
            VALUES ('fcount', 0)
            ON CONFLICT(counter_key) DO UPDATE SET counter_value = 0;
            """)
            try updateUserFishesDataSign(nowMs: nowMs)

            var profile = try loadPlayerProfile()
            profile.balance += totalCoins
            try updateProfileBalanceAndExperience(profile)

            return FishSaleTransactionResult(
                soldFishCount: entries.count,
                coinsEarned: totalCoins,
                newBalance: profile.balance
            )
        }
    }

    // MARK: - Internal Helpers

    private func updateProfileBalanceAndExperience(_ profile: PlayerProfileRecord) throws {
        let md5 = FishingChecksum.userDataMd5(
            balance: profile.balance,
            experience: profile.experience,
            category: profile.category,
            date: profile.date,
            installationUuid: installationUuid
        )
        try connection.run("""
        UPDATE user_data SET
            login = ?,
            password = ?,
            balance = ?,
            experience = ?,
            category = ?,
            date = ?,
            md5 = ?
        WHERE id = 1;
        """, bindings: [
            .text(profile.login),
            .text(profile.password),
            .integer(Int64(profile.balance)),
            .integer(Int64(profile.experience)),
            .integer(Int64(profile.category)),
            .integer(profile.date),
            .text(md5)
        ])
    }

    public func updateUserFishesDataSign(nowMs: Int64) throws {
        let count = try connection.scalarInt("SELECT COUNT(*) FROM user_fishes;")
        let md5: String
        if count > 0 {
            md5 = try catalog.computeReferenceDataSignMd5(for: .userFishes)
        } else {
            md5 = FishingChecksum.md5("\(nowMs)\(installationUuid)")
        }
        try connection.run("""
        INSERT INTO data_signs (id, date, md5)
        VALUES (8, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            date = excluded.date,
            md5 = excluded.md5;
        """, bindings: [
            .integer(nowMs),
            .text(md5)
        ])
    }
}
