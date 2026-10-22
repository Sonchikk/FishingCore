import Foundation
import FishingCore

// MARK: - Decodable DTOs for Extracted JSON Reference Files (data/*.json)

private struct FishesJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let name_ru: String
        let image_res_id: Int
        let unit_weight_grams: Int
        let unit_price_coins: Int
        let strength: Int
        let stamina: Int
        let intelligence: Int
        let aggression: Int
    }
    let items: [Item]
}

private struct BaitsJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let name_ru: String
        let image_res_id: Int
        let stock_amount: Int
        let price_coins: Int
    }
    let items: [Item]
}

private struct FishingRodsJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let name: String
        let max_weight_kg_db: Int
        let price_coins: Int
    }
    let items: [Item]
}

private struct FishingLinesJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let name: String
        let max_weight_kg_db: Int
        let price_coins: Int
        let stock_length_meters: Int
    }
    let items: [Item]
}

private struct CoilsJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let name: String
        let bearing_count: Int
        let price_coins: Int
    }
    let items: [Item]
}

private struct HooksJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let name: String
        let stock_amount: Int
        let price_coins: Int
    }
    let items: [Item]
}

private struct CouponsJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let name_ru: String
        let day_count: Int
        let price_coins: Int
        let dn_duration_units: Int
    }
    let items: [Item]
}

private struct AchievementsJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let image_res_id: Int
        let initial_score: Int
        let initial_level: Int
        let initial_nag: Int
        let nagsize_reward_param: Int
    }
    let items: [Item]
}

private struct QuestsJSONFile: Decodable {
    struct Item: Decodable {
        let id: Int
        let type: Int
        let fish_ids_raw: String
        let bait_ids_raw: String
        let target_counts_raw: String
        let target_weights_raw: String
        let required_category_rank: Int
        let rewards_raw: String
        let initial_res: String
        let initial_made: Int
    }
    let items: [Item]
}

private struct PondsJSONFile: Decodable {
    struct BaitSlotCatch: Decodable {
        let bait_slot_index: Int
        let bait_index_0based: Int
        let bait_db_id: Int
        let catchable_fishes: [CatchableFish]
    }
    struct CatchableFish: Decodable {
        let fish_index_0based: Int
        let fish_db_id: Int
    }
    struct SpeciesWeight: Decodable {
        let fish_index_0based: Int
        let fish_db_id: Int
        let min_weight_grams: Int
        let max_weight_grams: Int
    }
    struct TimeSlotFactor: Decodable {
        let bait_slot_index: Int
        let bait_index_0based: Int
        let fish_probabilities: [FishProb]
    }
    struct FishProb: Decodable {
        let fish_index_0based: Int
        let fish_db_id: Int
        let bite_probability_percent: Int
    }
    struct TimeFactors: Decodable {
        let morning: [TimeSlotFactor]
        let afternoon: [TimeSlotFactor]
        let evening: [TimeSlotFactor]
        let night: [TimeSlotFactor]
    }
    struct PondItem: Decodable {
        let pond_data_id: Int
        let ui_display_index: Int
        let chat_pond_id: Int
        let name_ru: String
        let name_en: String
        let name_de: String
        let name_es: String
        let name_pt: String
        let required_rank: Int
        let requires_coupon: Bool
        let pond_image_res_id: Int
        let pond_image_name: String
        let big_pond_image_res_id: Int
        let big_pond_image_name: String
        let bait_Slots_and_catches: [BaitSlotCatch]
        let species_weights: [SpeciesWeight]
        let time_of_day_bite_factors: TimeFactors
    }
    let ponds: [PondItem]
}

private struct ProgressionJSONFile: Decodable {
    struct RankEntry: Decodable {
        let rank_index_1based: Int
        let required_experience: Int
    }
    let rank_progression: [RankEntry]
}

public struct ReferenceImportSummary: Sendable, Equatable {
    public let fishesCount: Int
    public let baitsCount: Int
    public let rodsCount: Int
    public let linesCount: Int
    public let coilsCount: Int
    public let hooksCount: Int
    public let couponsCount: Int
    public let pondsCount: Int
    public let pondCatchRowsCount: Int
    public let pondWeightRowsCount: Int
    public let pondTimeFactorRowsCount: Int
    public let rankRowsCount: Int
}

/// Read-only store and idempotent JSON importer for all static game reference catalogs.
public final class ReferenceCatalogStore: Sendable {
    public let connection: SQLiteConnection
    public let installationUuid: String

    public init(connection: SQLiteConnection, installationUuid: String = "00000000-0000-0000-0000-000000000000") {
        self.connection = connection
        self.installationUuid = installationUuid
    }

    // MARK: - Idempotent JSON Import into Reference Tables (and non-destructive seed of records/achievements/quests)

    @discardableResult
    public func importFromJSONDirectory(
        _ directoryURL: URL,
        nowMs: Int64 = 0
    ) throws -> ReferenceImportSummary {
        let decoder = JSONDecoder()

        func loadJSON<T: Decodable>(_ filename: String, as type: T.Type) throws -> T {
            let fileURL = directoryURL.appendingPathComponent(filename)
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(T.self, from: data)
        }

        let fishesFile = try loadJSON("fishes.json", as: FishesJSONFile.self)
        let baitsFile = try loadJSON("baits.json", as: BaitsJSONFile.self)
        let rodsFile = try loadJSON("fishing_rods.json", as: FishingRodsJSONFile.self)
        let linesFile = try loadJSON("fishing_lines.json", as: FishingLinesJSONFile.self)
        let coilsFile = try loadJSON("coils.json", as: CoilsJSONFile.self)
        let hooksFile = try loadJSON("hooks.json", as: HooksJSONFile.self)
        let couponsFile = try loadJSON("coupons.json", as: CouponsJSONFile.self)
        let achievementsFile = try loadJSON("achievements.json", as: AchievementsJSONFile.self)
        let questsFile = try loadJSON("quests.json", as: QuestsJSONFile.self)
        let pondsFile = try loadJSON("ponds.json", as: PondsJSONFile.self)
        let progressionFile = try loadJSON("progression_and_balance.json", as: ProgressionJSONFile.self)

        return try connection.transaction {
            // 1. Fishes catalog (upsert static attributes & fishMd5)
            for item in fishesFile.items {
                let md5 = FishingChecksum.fishMd5(
                    id: item.id,
                    unitWeight: item.unit_weight_grams,
                    unitPrice: item.unit_price_coins,
                    strength: item.strength,
                    stamina: item.stamina,
                    intelligence: item.intelligence,
                    aggression: item.aggression,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT INTO fishes (id, name, image, unit_weight, unit_price, strength, stamina, intelligence, aggression, md5)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    image = excluded.image,
                    unit_weight = excluded.unit_weight,
                    unit_price = excluded.unit_price,
                    strength = excluded.strength,
                    stamina = excluded.stamina,
                    intelligence = excluded.intelligence,
                    aggression = excluded.aggression,
                    md5 = excluded.md5;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name_ru),
                    .integer(Int64(item.image_res_id)),
                    .integer(Int64(item.unit_weight_grams)),
                    .integer(Int64(item.unit_price_coins)),
                    .integer(Int64(item.strength)),
                    .integer(Int64(item.stamina)),
                    .integer(Int64(item.intelligence)),
                    .integer(Int64(item.aggression)),
                    .text(md5)
                ])

                // Also seed `records` row ONLY if missing (DatabaseHelper.fillUpdateRecordsTable — preserves player's personal records!)
                try connection.run("""
                INSERT OR IGNORE INTO records (id, fish_name, weight, bait_id)
                VALUES (?, ?, 0, 0);
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name_ru)
                ])
            }

            // 2. Baits catalog
            for item in baitsFile.items {
                try connection.run("""
                INSERT INTO baits (id, name, image, stock_amount, price)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    image = excluded.image,
                    stock_amount = excluded.stock_amount,
                    price = excluded.price;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name_ru),
                    .integer(Int64(item.image_res_id)),
                    .integer(Int64(item.stock_amount)),
                    .integer(Int64(item.price_coins))
                ])
            }

            // 3. Fishing rods catalog
            for item in rodsFile.items {
                try connection.run("""
                INSERT INTO fishing_rods (id, name, weight, price)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    weight = excluded.weight,
                    price = excluded.price;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name),
                    .integer(Int64(item.max_weight_kg_db)),
                    .integer(Int64(item.price_coins))
                ])
            }

            // 4. Fishing lines catalog
            for item in linesFile.items {
                try connection.run("""
                INSERT INTO fishing_lines (id, name, weight, price, stock_length)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    weight = excluded.weight,
                    price = excluded.price,
                    stock_length = excluded.stock_length;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name),
                    .integer(Int64(item.max_weight_kg_db)),
                    .integer(Int64(item.price_coins)),
                    .integer(Int64(item.stock_length_meters))
                ])
            }

            // 5. Coils catalog
            for item in coilsFile.items {
                try connection.run("""
                INSERT INTO coils (id, name, bearing_count, price)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    bearing_count = excluded.bearing_count,
                    price = excluded.price;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name),
                    .integer(Int64(item.bearing_count)),
                    .integer(Int64(item.price_coins))
                ])
            }

            // 6. Hooks catalog
            for item in hooksFile.items {
                try connection.run("""
                INSERT INTO hooks (id, name, stock_amount, price)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    stock_amount = excluded.stock_amount,
                    price = excluded.price;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name),
                    .integer(Int64(item.stock_amount)),
                    .integer(Int64(item.price_coins))
                ])
            }

            // 7. Coupons catalog
            for item in couponsFile.items {
                try connection.run("""
                INSERT INTO coupons (id, name, day_count, price, dn)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    day_count = excluded.day_count,
                    price = excluded.price,
                    dn = excluded.dn;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name_ru),
                    .integer(Int64(item.day_count)),
                    .integer(Int64(item.price_coins)),
                    .integer(Int64(item.dn_duration_units))
                ])
            }

            // 8. Seed `achievements` ONLY if missing (DatabaseHelper.fillUpdateAchievementsTable — never overwrites player score/level!)
            for item in achievementsFile.items {
                let achMd5 = FishingChecksum.achievementMd5(
                    id: item.id,
                    score: item.initial_score,
                    level: item.initial_level,
                    nag: item.initial_nag,
                    nagsize: item.nagsize_reward_param,
                    date: nowMs,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT OR IGNORE INTO achievements (id, image, score, level, nag, nagsize, date, md5)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(item.id)),
                    .integer(Int64(item.image_res_id)),
                    .integer(Int64(item.initial_score)),
                    .integer(Int64(item.initial_level)),
                    .integer(Int64(item.initial_nag)),
                    .integer(Int64(item.nagsize_reward_param)),
                    .integer(nowMs),
                    .text(achMd5)
                ])
            }

            // 9. Seed `quests` ONLY if missing, or update static quest definition while preserving player's `made` and `res`
            for item in questsFile.items {
                let existing = try connection.query(
                    "SELECT id, res, made, date, md5 FROM quests WHERE id = ?;",
                    bindings: [.integer(Int64(item.id))]
                )
                if existing.isEmpty {
                    let qMd5 = FishingChecksum.questMd5(
                        id: item.id,
                        type: item.type,
                        fish: item.fish_ids_raw,
                        bait: item.bait_ids_raw,
                        num: item.target_counts_raw,
                        weight: item.target_weights_raw,
                        cat: item.required_category_rank,
                        nag: item.rewards_raw,
                        res: item.initial_res,
                        made: item.initial_made,
                        date: nowMs,
                        installationUuid: installationUuid
                    )
                    try connection.run("""
                    INSERT INTO quests (id, type, fish, bait, num, weight, cat, nag, res, made, date, md5)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """, bindings: [
                        .integer(Int64(item.id)),
                        .integer(Int64(item.type)),
                        .text(item.fish_ids_raw),
                        .text(item.bait_ids_raw),
                        .text(item.target_counts_raw),
                        .text(item.target_weights_raw),
                        .integer(Int64(item.required_category_rank)),
                        .text(item.rewards_raw),
                        .text(item.initial_res),
                        .integer(Int64(item.initial_made)),
                        .integer(nowMs),
                        .text(qMd5)
                    ])
                }
            }

            // 10. Ponds & normalized catch/weight/time-factor tables
            var catchRowCount = 0
            var weightRowCount = 0
            var timeFactorRowCount = 0

            for pond in pondsFile.ponds {
                try connection.run("""
                INSERT INTO ref_ponds (
                    pond_data_id, ui_display_index, chat_pond_id,
                    name_ru, name_en, name_de, name_es, name_pt,
                    required_rank, requires_coupon,
                    pond_image_res_id, pond_image_name,
                    big_pond_image_res_id, big_pond_image_name
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(pond_data_id) DO UPDATE SET
                    ui_display_index = excluded.ui_display_index,
                    chat_pond_id = excluded.chat_pond_id,
                    name_ru = excluded.name_ru,
                    name_en = excluded.name_en,
                    name_de = excluded.name_de,
                    name_es = excluded.name_es,
                    name_pt = excluded.name_pt,
                    required_rank = excluded.required_rank,
                    requires_coupon = excluded.requires_coupon,
                    pond_image_res_id = excluded.pond_image_res_id,
                    pond_image_name = excluded.pond_image_name,
                    big_pond_image_res_id = excluded.big_pond_image_res_id,
                    big_pond_image_name = excluded.big_pond_image_name;
                """, bindings: [
                    .integer(Int64(pond.pond_data_id)),
                    .integer(Int64(pond.ui_display_index)),
                    .integer(Int64(pond.chat_pond_id)),
                    .text(pond.name_ru),
                    .text(pond.name_en),
                    .text(pond.name_de),
                    .text(pond.name_es),
                    .text(pond.name_pt),
                    .integer(Int64(pond.required_rank)),
                    .integer(pond.requires_coupon ? 1 : 0),
                    .integer(Int64(pond.pond_image_res_id)),
                    .text(pond.pond_image_name),
                    .integer(Int64(pond.big_pond_image_res_id)),
                    .text(pond.big_pond_image_name)
                ])

                for slot in pond.bait_Slots_and_catches {
                    for (orderIdx, cf) in slot.catchable_fishes.enumerated() {
                        try connection.run("""
                        INSERT INTO ref_pond_bait_catches (
                            pond_data_id, bait_slot_index, bait_index_0based, bait_db_id,
                            catch_order_index, fish_index_0based, fish_db_id
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT(pond_data_id, bait_slot_index, catch_order_index) DO UPDATE SET
                            bait_index_0based = excluded.bait_index_0based,
                            bait_db_id = excluded.bait_db_id,
                            fish_index_0based = excluded.fish_index_0based,
                            fish_db_id = excluded.fish_db_id;
                        """, bindings: [
                            .integer(Int64(pond.pond_data_id)),
                            .integer(Int64(slot.bait_slot_index)),
                            .integer(Int64(slot.bait_index_0based)),
                            .integer(Int64(slot.bait_db_id)),
                            .integer(Int64(orderIdx)),
                            .integer(Int64(cf.fish_index_0based)),
                            .integer(Int64(cf.fish_db_id))
                        ])
                        catchRowCount += 1
                    }
                }

                for sw in pond.species_weights {
                    try connection.run("""
                    INSERT INTO ref_pond_species_weights (
                        pond_data_id, fish_index_0based, fish_db_id,
                        min_weight_grams, max_weight_grams
                    ) VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(pond_data_id, fish_index_0based) DO UPDATE SET
                        fish_db_id = excluded.fish_db_id,
                        min_weight_grams = excluded.min_weight_grams,
                        max_weight_grams = excluded.max_weight_grams;
                    """, bindings: [
                        .integer(Int64(pond.pond_data_id)),
                        .integer(Int64(sw.fish_index_0based)),
                        .integer(Int64(sw.fish_db_id)),
                        .integer(Int64(sw.min_weight_grams)),
                        .integer(Int64(sw.max_weight_grams))
                    ])
                    weightRowCount += 1
                }

                let periods: [(String, [PondsJSONFile.TimeSlotFactor])] = [
                    ("morning", pond.time_of_day_bite_factors.morning),
                    ("afternoon", pond.time_of_day_bite_factors.afternoon),
                    ("evening", pond.time_of_day_bite_factors.evening),
                    ("night", pond.time_of_day_bite_factors.night)
                ]
                for (periodName, factors) in periods {
                    for slotFactor in factors {
                        for (entryIdx, fp) in slotFactor.fish_probabilities.enumerated() {
                            try connection.run("""
                            INSERT INTO ref_pond_time_factors (
                                pond_data_id, day_period, bait_slot_index, bait_index_0based,
                                entry_index, fish_index_0based, fish_db_id, probability_percent
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            ON CONFLICT(pond_data_id, day_period, bait_slot_index, entry_index) DO UPDATE SET
                                bait_index_0based = excluded.bait_index_0based,
                                fish_index_0based = excluded.fish_index_0based,
                                fish_db_id = excluded.fish_db_id,
                                probability_percent = excluded.probability_percent;
                            """, bindings: [
                                .integer(Int64(pond.pond_data_id)),
                                .text(periodName),
                                .integer(Int64(slotFactor.bait_slot_index)),
                                .integer(Int64(slotFactor.bait_index_0based)),
                                .integer(Int64(entryIdx)),
                                .integer(Int64(fp.fish_index_0based)),
                                .integer(Int64(fp.fish_db_id)),
                                .integer(Int64(fp.bite_probability_percent))
                            ])
                            timeFactorRowCount += 1
                        }
                    }
                }
            }

            // 11. Rank thresholds
            for rank in progressionFile.rank_progression {
                try connection.run("""
                INSERT INTO ref_rank_thresholds (rank_index_1based, required_experience)
                VALUES (?, ?)
                ON CONFLICT(rank_index_1based) DO UPDATE SET
                    required_experience = excluded.required_experience;
                """, bindings: [
                    .integer(Int64(rank.rank_index_1based)),
                    .integer(Int64(rank.required_experience))
                ])
            }

            // 12. Recompute and upsert reference `data_signs` (1..7)
            try rebuildReferenceDataSigns(nowMs: nowMs)

            return ReferenceImportSummary(
                fishesCount: fishesFile.items.count,
                baitsCount: baitsFile.items.count,
                rodsCount: rodsFile.items.count,
                linesCount: linesFile.items.count,
                coilsCount: coilsFile.items.count,
                hooksCount: hooksFile.items.count,
                couponsCount: couponsFile.items.count,
                pondsCount: pondsFile.ponds.count,
                pondCatchRowsCount: catchRowCount,
                pondWeightRowsCount: weightRowCount,
                pondTimeFactorRowsCount: timeFactorRowCount,
                rankRowsCount: progressionFile.rank_progression.count
            )
        }
    }

    // MARK: - Reference DataSign Calculation & Verification (Ids 1..7)

    public func computeReferenceDataSignMd5(for tableId: DataSignTableId) throws -> String {
        let sum: Int
        switch tableId {
        case .fishes:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(unit_price + unit_weight), 0) FROM fishes;")
        case .fishingRods:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(price + weight), 0) FROM fishing_rods;")
        case .fishingLines:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(price + weight), 0) FROM fishing_lines;")
        case .coils:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(price + bearing_count), 0) FROM coils;")
        case .coupons:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(price + dn), 0) FROM coupons;")
        case .hooks:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(price + stock_amount), 0) FROM hooks;")
        case .baits:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(price + stock_amount), 0) FROM baits;")
        case .userFishes:
            sum = try connection.scalarInt("SELECT COALESCE(SUM(fish + weight), 0) FROM user_fishes;")
        }
        return FishingChecksum.dataSignMd5(sumOfPairs: sum, installationUuid: installationUuid)
    }

    public func rebuildReferenceDataSigns(nowMs: Int64 = 0) throws {
        let refIds: [DataSignTableId] = [.fishes, .fishingRods, .fishingLines, .coils, .coupons, .hooks, .baits]
        for signId in refIds {
            let md5 = try computeReferenceDataSignMd5(for: signId)
            try connection.run("""
            INSERT INTO data_signs (id, date, md5)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                date = excluded.date,
                md5 = excluded.md5;
            """, bindings: [
                .integer(Int64(signId.rawValue)),
                .integer(nowMs),
                .text(md5)
            ])
        }
    }

    public func verifyDataSign(_ signId: DataSignTableId) throws -> Bool {
        let rows = try connection.query(
            "SELECT md5 FROM data_signs WHERE id = ?;",
            bindings: [.integer(Int64(signId.rawValue))]
        )
        guard let storedMd5 = rows.first?.string("md5") else { return false }
        if signId == .userFishes {
            let count = try connection.scalarInt("SELECT COUNT(*) FROM user_fishes;")
            if count == 0 {
                // In MainActivity$e.q() (`pc=005c..0074`), empty `user_fishes` always passes checkBase!
                return true
            }
        }
        let expectedMd5 = try computeReferenceDataSignMd5(for: signId)
        return storedMd5 == expectedMd5
    }

    // MARK: - Read-Only Catalog Queries Producing `FishingCore` Types

    public func loadFishCatalogById() throws -> [Int: FishSpecies] {
        let rows = try connection.query("""
        SELECT id, name, unit_weight, unit_price, strength, stamina, intelligence, aggression, md5
        FROM fishes ORDER BY id ASC;
        """)
        var catalog: [Int: FishSpecies] = [:]
        catalog.reserveCapacity(rows.count)
        for row in rows {
            let id = row.int("id")
            let unitWeight = row.int("unit_weight")
            let unitPrice = row.int("unit_price")
            let strength = row.int("strength")
            let stamina = row.int("stamina")
            let intelligence = row.int("intelligence")
            let aggression = row.int("aggression")
            let storedMd5 = row.string("md5")
            let expectedMd5 = FishingChecksum.fishMd5(
                id: id,
                unitWeight: unitWeight,
                unitPrice: unitPrice,
                strength: strength,
                stamina: stamina,
                intelligence: intelligence,
                aggression: aggression,
                installationUuid: installationUuid
            )
            catalog[id] = FishSpecies(
                id: id,
                name: row.string("name"),
                unitWeight: unitWeight,
                unitPrice: unitPrice,
                strength: strength,
                stamina: stamina,
                intelligence: intelligence,
                aggression: aggression,
                md5Valid: storedMd5 == expectedMd5
            )
        }
        return catalog
    }

    public func loadFishingRodSpec(id: Int) throws -> FishingRodSpec? {
        let rows = try connection.query(
            "SELECT id, name, weight, price FROM fishing_rods WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
        guard let row = rows.first else { return nil }
        return FishingRodSpec(
            id: row.int("id"),
            name: row.string("name"),
            weight: row.int("weight"),
            price: row.int("price")
        )
    }

    public func loadCoilSpec(id: Int) throws -> CoilSpec? {
        let rows = try connection.query(
            "SELECT id, name, bearing_count, price FROM coils WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
        guard let row = rows.first else { return nil }
        return CoilSpec(
            id: row.int("id"),
            name: row.string("name"),
            bearingCount: row.int("bearing_count"),
            price: row.int("price")
        )
    }

    public func loadFishingLineSpec(id: Int) throws -> FishingLineSpec? {
        let rows = try connection.query(
            "SELECT id, name, weight, price, stock_length FROM fishing_lines WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
        guard let row = rows.first else { return nil }
        return FishingLineSpec(
            id: row.int("id"),
            name: row.string("name"),
            weight: row.int("weight"),
            stockLength: row.int("stock_length"),
            price: row.int("price")
        )
    }

    public func loadHookSpec(id: Int) throws -> HookSpec? {
        let rows = try connection.query(
            "SELECT id, name, stock_amount, price FROM hooks WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
        guard let row = rows.first else { return nil }
        return HookSpec(
            id: row.int("id"),
            name: row.string("name"),
            price: row.int("price")
        )
    }

    public func loadHookStockAmount(id: Int) throws -> Int {
        try connection.scalarInt(
            "SELECT stock_amount FROM hooks WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
    }

    public func loadBaitSpec(id: Int) throws -> (spec: BaitSpec, stockAmount: Int)? {
        let rows = try connection.query(
            "SELECT id, name, stock_amount, price FROM baits WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
        guard let row = rows.first else { return nil }
        let spec = BaitSpec(
            id: row.int("id"),
            name: row.string("name"),
            rank: 0,
            price: row.int("price")
        )
        return (spec, row.int("stock_amount"))
    }

    public func loadCouponSpec(id: Int) throws -> CouponSpec? {
        let rows = try connection.query(
            "SELECT id, name, day_count, price, dn FROM coupons WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
        guard let row = rows.first else { return nil }
        return CouponSpec(
            id: row.int("id"),
            name: row.string("name"),
            dayCount: row.int("day_count"),
            price: row.int("price"),
            dn: row.int("dn")
        )
    }

    /// Reconstructs `PondSimulationData` for `FishingCore` directly from normalized `ref_pond_*` SQLite tables.
    public func loadPondSimulationData(pondIndex: Int) throws -> PondSimulationData {
        let catchRows = try connection.query("""
        SELECT bait_slot_index, bait_index_0based, catch_order_index, fish_index_0based
        FROM ref_pond_bait_catches
        WHERE pond_data_id = ?
        ORDER BY bait_slot_index ASC, catch_order_index ASC;
        """, bindings: [.integer(Int64(pondIndex))])

        var maxSlot = -1
        for r in catchRows {
            maxSlot = max(maxSlot, r.int("bait_slot_index"))
        }
        let slotCount = maxSlot + 1
        var activeBaitIndices = [Int](repeating: 0, count: max(0, slotCount))
        var catchableFishBySlot = [[Int]](repeating: [], count: max(0, slotCount))

        for r in catchRows {
            let slot = r.int("bait_slot_index")
            activeBaitIndices[slot] = r.int("bait_index_0based")
            catchableFishBySlot[slot].append(r.int("fish_index_0based"))
        }

        let weightRows = try connection.query("""
        SELECT fish_index_0based, min_weight_grams, max_weight_grams
        FROM ref_pond_species_weights
        WHERE pond_data_id = ?
        ORDER BY rowid ASC;
        """, bindings: [.integer(Int64(pondIndex))])

        let weightRanges = weightRows.map {
            PondFishWeightRange(
                fishIndex0Based: $0.int("fish_index_0based"),
                minWeightGrams: $0.int("min_weight_grams"),
                maxWeightGrams: $0.int("max_weight_grams")
            )
        }

        func loadFactors(period: String) throws -> [[PondFishBiteFactor]] {
            var result = [[PondFishBiteFactor]](repeating: [], count: max(0, slotCount))
            let rows = try connection.query("""
            SELECT bait_slot_index, fish_index_0based, probability_percent
            FROM ref_pond_time_factors
            WHERE pond_data_id = ? AND day_period = ?
            ORDER BY bait_slot_index ASC, entry_index ASC;
            """, bindings: [.integer(Int64(pondIndex)), .text(period)])
            for r in rows {
                let slot = r.int("bait_slot_index")
                if slot >= 0 && slot < result.count {
                    result[slot].append(
                        PondFishBiteFactor(
                            fishIndex0Based: r.int("fish_index_0based"),
                            probabilityPercent: r.int("probability_percent")
                        )
                    )
                }
            }
            return result
        }

        return PondSimulationData(
            pondIndex: pondIndex,
            activeBaitIndices0Based: activeBaitIndices,
            catchableFishByBaitSlot: catchableFishBySlot,
            fishWeightRanges: weightRanges,
            factorsMorning: try loadFactors(period: "morning"),
            factorsAfternoon: try loadFactors(period: "afternoon"),
            factorsEvening: try loadFactors(period: "evening"),
            factorsNight: try loadFactors(period: "night")
        )
    }
}
