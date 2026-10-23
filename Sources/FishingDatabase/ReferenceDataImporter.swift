import Foundation
import FishingCore

// MARK: - Codable DTOs for Phase 2 Extracted JSON Files (`data/*.json`) & Test Fixtures

public struct FishesJSONFile: Decodable, Sendable {
    public struct LocalizedNames: Decodable, Sendable {
        public let ru: String?
        public let en: String?
        public let de: String?
        public let es: String?
        public let pt: String?
    }

    public struct Item: Decodable, Sendable {
        public let id: Int
        public let name_ru: String
        public let image_res_id: Int
        public let unit_weight_grams: Int
        public let unit_price_coins: Int
        public let strength: Int
        public let stamina: Int
        public let intelligence: Int
        public let aggression: Int

        enum CodingKeys: String, CodingKey {
            case id
            case name_ru
            case name
            case names_i18n
            case image_res_id
            case image
            case unit_weight_grams
            case unitWeight
            case unit_weight
            case unit_price_coins
            case unitPrice
            case unit_price
            case strength
            case stamina
            case intelligence
            case aggression
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            if let nameRu = try c.decodeIfPresent(String.self, forKey: .name_ru) {
                self.name_ru = nameRu
            } else if let i18n = try c.decodeIfPresent(LocalizedNames.self, forKey: .names_i18n), let ru = i18n.ru {
                self.name_ru = ru
            } else {
                self.name_ru = try c.decode(String.self, forKey: .name)
            }
            self.image_res_id = try c.decodeIfPresent(Int.self, forKey: .image_res_id)
                ?? c.decode(Int.self, forKey: .image)
            if let uw = try c.decodeIfPresent(Int.self, forKey: .unit_weight_grams) {
                self.unit_weight_grams = uw
            } else if let uw = try c.decodeIfPresent(Int.self, forKey: .unitWeight) {
                self.unit_weight_grams = uw
            } else {
                self.unit_weight_grams = try c.decode(Int.self, forKey: .unit_weight)
            }
            if let up = try c.decodeIfPresent(Int.self, forKey: .unit_price_coins) {
                self.unit_price_coins = up
            } else if let up = try c.decodeIfPresent(Int.self, forKey: .unitPrice) {
                self.unit_price_coins = up
            } else {
                self.unit_price_coins = try c.decode(Int.self, forKey: .unit_price)
            }
            self.strength = try c.decode(Int.self, forKey: .strength)
            self.stamina = try c.decode(Int.self, forKey: .stamina)
            self.intelligence = try c.decode(Int.self, forKey: .intelligence)
            self.aggression = try c.decode(Int.self, forKey: .aggression)
        }
    }

    public let items: [Item]

    enum CodingKeys: String, CodingKey {
        case items
        case records
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try container.decodeIfPresent([Item].self, forKey: .items) {
            self.items = items
        } else {
            self.items = try container.decode([Item].self, forKey: .records)
        }
    }
}

public struct BaitsJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let name_ru: String
        public let image_res_id: Int
        public let stock_amount: Int
        public let price_coins: Int

        enum CodingKeys: String, CodingKey {
            case id, name_ru, name, image_res_id, image, stock_amount, stockAmount, price_coins, price
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name_ru = try c.decodeIfPresent(String.self, forKey: .name_ru)
                ?? c.decode(String.self, forKey: .name)
            self.image_res_id = try c.decodeIfPresent(Int.self, forKey: .image_res_id)
                ?? c.decode(Int.self, forKey: .image)
            self.stock_amount = try c.decodeIfPresent(Int.self, forKey: .stock_amount)
                ?? c.decode(Int.self, forKey: .stockAmount)
            self.price_coins = try c.decodeIfPresent(Int.self, forKey: .price_coins)
                ?? c.decode(Int.self, forKey: .price)
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct FishingRodsJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let name: String
        public let max_weight_kg: Int
        public let price_coins: Int

        enum CodingKeys: String, CodingKey {
            case id, name, max_weight_kg_db, max_weight_kg, weight, price_coins, price
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name = try c.decode(String.self, forKey: .name)
            if let w = try c.decodeIfPresent(Int.self, forKey: .max_weight_kg_db) {
                self.max_weight_kg = w
            } else if let w = try c.decodeIfPresent(Int.self, forKey: .max_weight_kg) {
                self.max_weight_kg = w
            } else {
                self.max_weight_kg = try c.decode(Int.self, forKey: .weight)
            }
            self.price_coins = try c.decodeIfPresent(Int.self, forKey: .price_coins)
                ?? c.decode(Int.self, forKey: .price)
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct FishingLinesJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let name: String
        public let max_weight_kg: Int
        public let price_coins: Int
        public let stock_length_m: Int

        enum CodingKeys: String, CodingKey {
            case id, name, max_weight_kg_db, max_weight_kg, weight, price_coins, price
            case stock_length_meters, stock_length_m, stockLength, stock_length
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name = try c.decode(String.self, forKey: .name)
            if let w = try c.decodeIfPresent(Int.self, forKey: .max_weight_kg_db) {
                self.max_weight_kg = w
            } else if let w = try c.decodeIfPresent(Int.self, forKey: .max_weight_kg) {
                self.max_weight_kg = w
            } else {
                self.max_weight_kg = try c.decode(Int.self, forKey: .weight)
            }
            self.price_coins = try c.decodeIfPresent(Int.self, forKey: .price_coins)
                ?? c.decode(Int.self, forKey: .price)
            if let len = try c.decodeIfPresent(Int.self, forKey: .stock_length_meters) {
                self.stock_length_m = len
            } else if let len = try c.decodeIfPresent(Int.self, forKey: .stock_length_m) {
                self.stock_length_m = len
            } else if let len = try c.decodeIfPresent(Int.self, forKey: .stockLength) {
                self.stock_length_m = len
            } else {
                self.stock_length_m = try c.decode(Int.self, forKey: .stock_length)
            }
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct CoilsJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let name: String
        public let bearing_count: Int
        public let price_coins: Int

        enum CodingKeys: String, CodingKey {
            case id, name, bearing_count, bearingCount, price_coins, price
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name = try c.decode(String.self, forKey: .name)
            self.bearing_count = try c.decodeIfPresent(Int.self, forKey: .bearing_count)
                ?? c.decode(Int.self, forKey: .bearingCount)
            self.price_coins = try c.decodeIfPresent(Int.self, forKey: .price_coins)
                ?? c.decode(Int.self, forKey: .price)
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct HooksJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let name: String
        public let stock_amount: Int
        public let price_coins: Int

        enum CodingKeys: String, CodingKey {
            case id, name, stock_amount, stockAmount, price_coins, price
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name = try c.decode(String.self, forKey: .name)
            self.stock_amount = try c.decodeIfPresent(Int.self, forKey: .stock_amount)
                ?? c.decode(Int.self, forKey: .stockAmount)
            self.price_coins = try c.decodeIfPresent(Int.self, forKey: .price_coins)
                ?? c.decode(Int.self, forKey: .price)
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct CouponsJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let name_ru: String
        public let day_count: Int
        public let price_coins: Int
        public let dn_duration_units: Int

        enum CodingKeys: String, CodingKey {
            case id, name_ru, name, day_count, dayCount, price_coins, price, dn_duration_units, dn
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.name_ru = try c.decodeIfPresent(String.self, forKey: .name_ru)
                ?? c.decode(String.self, forKey: .name)
            self.day_count = try c.decodeIfPresent(Int.self, forKey: .day_count)
                ?? c.decode(Int.self, forKey: .dayCount)
            self.price_coins = try c.decodeIfPresent(Int.self, forKey: .price_coins)
                ?? c.decode(Int.self, forKey: .price)
            self.dn_duration_units = try c.decodeIfPresent(Int.self, forKey: .dn_duration_units)
                ?? c.decode(Int.self, forKey: .dn)
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct AchievementsJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let image_res_id: Int
        public let initial_score: Int
        public let initial_level: Int
        public let initial_nag: Int
        public let nagsize_reward_param: Int

        enum CodingKeys: String, CodingKey {
            case id, image_res_id, image, initial_score, score, initial_level, level, initial_nag, nag, nagsize_reward_param, nagsize
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.image_res_id = try c.decodeIfPresent(Int.self, forKey: .image_res_id)
                ?? c.decode(Int.self, forKey: .image)
            self.initial_score = try c.decodeIfPresent(Int.self, forKey: .initial_score)
                ?? c.decode(Int.self, forKey: .score)
            self.initial_level = try c.decodeIfPresent(Int.self, forKey: .initial_level)
                ?? c.decode(Int.self, forKey: .level)
            self.initial_nag = try c.decodeIfPresent(Int.self, forKey: .initial_nag)
                ?? c.decode(Int.self, forKey: .nag)
            self.nagsize_reward_param = try c.decodeIfPresent(Int.self, forKey: .nagsize_reward_param)
                ?? c.decode(Int.self, forKey: .nagsize)
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct QuestsJSONFile: Decodable, Sendable {
    public struct Item: Decodable, Sendable {
        public let id: Int
        public let type: Int
        public let fish_ids_raw: String
        public let bait_ids_raw: String
        public let target_counts_raw: String
        public let target_weights_raw: String
        public let required_category_rank: Int
        public let rewards_raw: String
        public let initial_res: String
        public let initial_made: Int

        enum CodingKeys: String, CodingKey {
            case id, type, fish_ids_raw, fish, bait_ids_raw, bait, target_counts_raw, num
            case target_weights_raw, weight, required_category_rank, cat, rewards_raw, nag
            case initial_res, res, initial_made, made
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(Int.self, forKey: .id)
            self.type = try c.decode(Int.self, forKey: .type)
            self.fish_ids_raw = try c.decodeIfPresent(String.self, forKey: .fish_ids_raw)
                ?? c.decode(String.self, forKey: .fish)
            self.bait_ids_raw = try c.decodeIfPresent(String.self, forKey: .bait_ids_raw)
                ?? c.decode(String.self, forKey: .bait)
            self.target_counts_raw = try c.decodeIfPresent(String.self, forKey: .target_counts_raw)
                ?? c.decode(String.self, forKey: .num)
            self.target_weights_raw = try c.decodeIfPresent(String.self, forKey: .target_weights_raw)
                ?? c.decode(String.self, forKey: .weight)
            self.required_category_rank = try c.decodeIfPresent(Int.self, forKey: .required_category_rank)
                ?? c.decode(Int.self, forKey: .cat)
            self.rewards_raw = try c.decodeIfPresent(String.self, forKey: .rewards_raw)
                ?? c.decode(String.self, forKey: .nag)
            self.initial_res = try c.decodeIfPresent(String.self, forKey: .initial_res)
                ?? c.decode(String.self, forKey: .res)
            self.initial_made = try c.decodeIfPresent(Int.self, forKey: .initial_made)
                ?? c.decode(Int.self, forKey: .made)
        }
    }
    public let items: [Item]

    enum CodingKeys: String, CodingKey { case items, records }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try c.decodeIfPresent([Item].self, forKey: .items) ?? c.decode([Item].self, forKey: .records)
    }
}

public struct PondsJSONFile: Decodable, Sendable {
    public struct CatchableFishEntry: Decodable, Sendable {
        public let fish_index_0based: Int
        public let fish_db_id: Int

        public init(fish_index_0based: Int, fish_db_id: Int) {
            self.fish_index_0based = fish_index_0based
            self.fish_db_id = fish_db_id
        }
    }
    public struct BaitSlotCatchEntry: Decodable, Sendable {
        public let bait_slot_index: Int
        public let bait_index_0based: Int
        public let bait_db_id: Int
        public let catchable_fishes: [CatchableFishEntry]

        public init(
            bait_slot_index: Int,
            bait_index_0based: Int,
            bait_db_id: Int,
            catchable_fishes: [CatchableFishEntry]
        ) {
            self.bait_slot_index = bait_slot_index
            self.bait_index_0based = bait_index_0based
            self.bait_db_id = bait_db_id
            self.catchable_fishes = catchable_fishes
        }
    }
    public struct SpeciesWeightEntry: Decodable, Sendable {
        public let fish_index_0based: Int
        public let fish_db_id: Int
        public let min_weight_grams: Int
        public let max_weight_grams: Int
    }
    public struct TimeSlotFishProb: Decodable, Sendable {
        public let fish_index_0based: Int
        public let fish_db_id: Int
        public let bite_probability_percent: Int

        enum CodingKeys: String, CodingKey {
            case fish_index_0based
            case fish_db_id
            case bite_probability_percent
            case probability_percent
        }

        public init(fish_index_0based: Int, fish_db_id: Int, bite_probability_percent: Int) {
            self.fish_index_0based = fish_index_0based
            self.fish_db_id = fish_db_id
            self.bite_probability_percent = bite_probability_percent
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let idx0 = try c.decode(Int.self, forKey: .fish_index_0based)
            self.fish_index_0based = idx0
            self.fish_db_id = try c.decodeIfPresent(Int.self, forKey: .fish_db_id) ?? (idx0 + 1)
            self.bite_probability_percent = try c.decodeIfPresent(Int.self, forKey: .bite_probability_percent)
                ?? c.decode(Int.self, forKey: .probability_percent)
        }
    }
    public struct TimeSlotFactor: Decodable, Sendable {
        public let bait_slot_index: Int
        public let bait_index_0based: Int
        public let fish_probabilities: [TimeSlotFishProb]

        public init(bait_slot_index: Int, bait_index_0based: Int, fish_probabilities: [TimeSlotFishProb]) {
            self.bait_slot_index = bait_slot_index
            self.bait_index_0based = bait_index_0based
            self.fish_probabilities = fish_probabilities
        }
    }
    public struct TimeOfDayFactors: Decodable, Sendable {
        public let morning: [TimeSlotFactor]
        public let afternoon: [TimeSlotFactor]
        public let evening: [TimeSlotFactor]
        public let night: [TimeSlotFactor]

        public init(
            morning: [TimeSlotFactor],
            afternoon: [TimeSlotFactor],
            evening: [TimeSlotFactor],
            night: [TimeSlotFactor]
        ) {
            self.morning = morning
            self.afternoon = afternoon
            self.evening = evening
            self.night = night
        }
    }

    public struct ResolvedBaitSlotDTO: Decodable, Sendable {
        public let slot_index: Int
        public let bait_index_0based: Int
        public let bait_db_id: Int
        public let catchable_fish_indices_0based: [Int]
        public let morning_probabilities: [TimeSlotFishProb]
        public let afternoon_probabilities: [TimeSlotFishProb]
        public let evening_probabilities: [TimeSlotFishProb]
        public let night_probabilities: [TimeSlotFishProb]
    }

    public struct PondEntry: Decodable, Sendable {
        public let pond_data_id: Int
        public let ui_display_index: Int
        public let chat_pond_id: Int
        public let name_ru: String
        public let name_en: String
        public let name_de: String
        public let name_es: String
        public let name_pt: String
        public let required_rank: Int
        public let requires_coupon: Bool
        public let pond_image_res_id: Int
        public let pond_image_name: String
        public let big_pond_image_res_id: Int
        public let big_pond_image_name: String
        public let bait_Slots_and_catches: [BaitSlotCatchEntry]
        public let species_weights: [SpeciesWeightEntry]
        public let time_of_day_bite_factors: TimeOfDayFactors

        enum CodingKeys: String, CodingKey {
            case pond_data_id, ui_display_index, chat_pond_id
            case name_ru, name_en, name_de, name_es, name_pt, names_i18n
            case required_rank, requires_coupon
            case pond_image_res_id, pondImage, pond_image_name, pondImage_res_name
            case big_pond_image_res_id, bigPondImage, big_pond_image_name, bigPondImage_res_name
            case bait_Slots_and_catches
            case bait_slots_and_catches
            case resolved_bait_slots
            case species_weights
            case resolved_species
            case time_of_day_bite_factors
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.pond_data_id = try c.decode(Int.self, forKey: .pond_data_id)
            self.ui_display_index = try c.decode(Int.self, forKey: .ui_display_index)
            self.chat_pond_id = try c.decode(Int.self, forKey: .chat_pond_id)
            self.name_ru = try c.decode(String.self, forKey: .name_ru)

            let i18n = try c.decodeIfPresent(FishesJSONFile.LocalizedNames.self, forKey: .names_i18n)
            self.name_en = try c.decodeIfPresent(String.self, forKey: .name_en) ?? i18n?.en ?? ""
            self.name_de = try c.decodeIfPresent(String.self, forKey: .name_de) ?? i18n?.de ?? ""
            self.name_es = try c.decodeIfPresent(String.self, forKey: .name_es) ?? i18n?.es ?? ""
            self.name_pt = try c.decodeIfPresent(String.self, forKey: .name_pt) ?? i18n?.pt ?? ""

            self.required_rank = try c.decode(Int.self, forKey: .required_rank)
            self.requires_coupon = try c.decode(Bool.self, forKey: .requires_coupon)

            self.pond_image_res_id = try c.decodeIfPresent(Int.self, forKey: .pond_image_res_id)
                ?? c.decode(Int.self, forKey: .pondImage)
            self.pond_image_name = try c.decodeIfPresent(String.self, forKey: .pond_image_name)
                ?? c.decode(String.self, forKey: .pondImage_res_name)
            self.big_pond_image_res_id = try c.decodeIfPresent(Int.self, forKey: .big_pond_image_res_id)
                ?? c.decode(Int.self, forKey: .bigPondImage)
            self.big_pond_image_name = try c.decodeIfPresent(String.self, forKey: .big_pond_image_name)
                ?? c.decode(String.self, forKey: .bigPondImage_res_name)

            if let slotsUpper = try c.decodeIfPresent([BaitSlotCatchEntry].self, forKey: .bait_Slots_and_catches) {
                self.bait_Slots_and_catches = slotsUpper
                self.species_weights = try c.decode([SpeciesWeightEntry].self, forKey: .species_weights)
                self.time_of_day_bite_factors = try c.decode(TimeOfDayFactors.self, forKey: .time_of_day_bite_factors)
            } else if let slotsLower = try c.decodeIfPresent([BaitSlotCatchEntry].self, forKey: .bait_slots_and_catches) {
                self.bait_Slots_and_catches = slotsLower
                self.species_weights = try c.decode([SpeciesWeightEntry].self, forKey: .species_weights)
                self.time_of_day_bite_factors = try c.decode(TimeOfDayFactors.self, forKey: .time_of_day_bite_factors)
            } else {
                let resolvedSlots = try c.decode([ResolvedBaitSlotDTO].self, forKey: .resolved_bait_slots)
                self.bait_Slots_and_catches = resolvedSlots.map { rs in
                    BaitSlotCatchEntry(
                        bait_slot_index: rs.slot_index,
                        bait_index_0based: rs.bait_index_0based,
                        bait_db_id: rs.bait_db_id,
                        catchable_fishes: rs.catchable_fish_indices_0based.map { idx0 in
                            CatchableFishEntry(fish_index_0based: idx0, fish_db_id: idx0 + 1)
                        }
                    )
                }
                self.species_weights = try c.decode([SpeciesWeightEntry].self, forKey: .resolved_species)
                self.time_of_day_bite_factors = TimeOfDayFactors(
                    morning: resolvedSlots.map {
                        TimeSlotFactor(bait_slot_index: $0.slot_index, bait_index_0based: $0.bait_index_0based, fish_probabilities: $0.morning_probabilities)
                    },
                    afternoon: resolvedSlots.map {
                        TimeSlotFactor(bait_slot_index: $0.slot_index, bait_index_0based: $0.bait_index_0based, fish_probabilities: $0.afternoon_probabilities)
                    },
                    evening: resolvedSlots.map {
                        TimeSlotFactor(bait_slot_index: $0.slot_index, bait_index_0based: $0.bait_index_0based, fish_probabilities: $0.evening_probabilities)
                    },
                    night: resolvedSlots.map {
                        TimeSlotFactor(bait_slot_index: $0.slot_index, bait_index_0based: $0.bait_index_0based, fish_probabilities: $0.night_probabilities)
                    }
                )
            }
        }
    }
    public let ponds: [PondEntry]

    enum CodingKeys: String, CodingKey {
        case ponds
        case ponds_by_data_id
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let ponds = try c.decodeIfPresent([PondEntry].self, forKey: .ponds) {
            self.ponds = ponds
        } else {
            self.ponds = try c.decode([PondEntry].self, forKey: .ponds_by_data_id)
        }
    }
}

public struct ProgressionAndBalanceJSONFile: Decodable, Sendable {
    public struct RankEntry: Decodable, Sendable {
        public let rank_index_1based: Int
        public let required_experience: Int

        public init(rank_index_1based: Int, required_experience: Int) {
            self.rank_index_1based = rank_index_1based
            self.required_experience = required_experience
        }

        enum CodingKeys: String, CodingKey {
            case rank_index_1based, rank, required_experience
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.rank_index_1based = try c.decodeIfPresent(Int.self, forKey: .rank_index_1based)
                ?? c.decode(Int.self, forKey: .rank)
            self.required_experience = try c.decode(Int.self, forKey: .required_experience)
        }
    }

    private struct D0DTablesContainer: Decodable {
        struct IntArrayTable: Decodable {
            let values: [Int]
        }
        let j_player_rank_exp_thresholds_45: IntArrayTable
    }

    public let rank_progression: [RankEntry]

    enum CodingKeys: String, CodingKey {
        case rank_progression
        case d0_d_tables
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let ranks = try c.decodeIfPresent([RankEntry].self, forKey: .rank_progression) {
            self.rank_progression = ranks
        } else {
            let tables = try c.decode(D0DTablesContainer.self, forKey: .d0_d_tables)
            self.rank_progression = tables.j_player_rank_exp_thresholds_45.values.enumerated().map { idx, exp in
                RankEntry(rank_index_1based: idx + 1, required_experience: exp)
            }
        }
    }
}

// MARK: - Reference Catalog Importer & Query Service

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

public final class ReferenceCatalogStore: @unchecked Sendable {
    public let connection: SQLiteConnection
    public let installationUuid: String

    public init(
        connection: SQLiteConnection,
        installationUuid: String = "00000000-0000-0000-0000-000000000000"
    ) {
        self.connection = connection
        self.installationUuid = installationUuid
    }

    // MARK: - Full Import from `data/*.json` (Idempotent & Non-Destructive to Player State)

    /// Populates or updates all reference catalog tables (`fishes`, `baits`, `fishing_rods`,
    /// `fishing_lines`, `coils`, `hooks`, `coupons`, `records`, `achievements`, `quests`,
    /// `ref_ponds`, `ref_pond_bait_catches`, `ref_pond_species_weights`, `ref_pond_time_factors`,
    /// `ref_rank_thresholds`, and `data_signs` 1..7) from a directory containing the Phase 2 JSON files.
    ///
    /// - Important: Replicates `DatabaseHelper.fill*` semantics:
    ///   - Preserves online-synced weights/lengths/bearings on `fishing_rods` (`price == 0`),
    ///     `fishing_lines` (`price == 0`), and `coils` (`price == 0`) if already > 0.
    ///   - Preserves existing player `records.weight` / `records.bait_id`, `achievements.score` / `level`,
    ///     and `quests.made` / `res`.
    @discardableResult
    public func importFromJSONDirectory(_ directoryURL: URL, nowMs: Int64 = 0) throws -> ReferenceImportSummary {
        let decoder = JSONDecoder()

        func loadJSON<T: Decodable>(_ filename: String) throws -> T {
            let fileURL = directoryURL.appendingPathComponent(filename)
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(T.self, from: data)
        }

        let fishesFile: FishesJSONFile = try loadJSON("fishes.json")
        let baitsFile: BaitsJSONFile = try loadJSON("baits.json")
        let rodsFile: FishingRodsJSONFile = try loadJSON("fishing_rods.json")
        let linesFile: FishingLinesJSONFile = try loadJSON("fishing_lines.json")
        let coilsFile: CoilsJSONFile = try loadJSON("coils.json")
        let hooksFile: HooksJSONFile = try loadJSON("hooks.json")
        let couponsFile: CouponsJSONFile = try loadJSON("coupons.json")
        let achievementsFile: AchievementsJSONFile = try loadJSON("achievements.json")
        let questsFile: QuestsJSONFile = try loadJSON("quests.json")
        let pondsFile: PondsJSONFile = try loadJSON("ponds.json")
        let progressionFile: ProgressionAndBalanceJSONFile = try loadJSON("progression_and_balance.json")

        return try connection.transaction {
            // 1. Fishes & Records (`DatabaseHelper.fillFishesTable` + `fillRecordsTable`)
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

                // Seed `records` row if missing, or update localized `fish_name` without resetting player's record weight!
                try connection.run("""
                INSERT INTO records (id, fish_name, weight, bait_id)
                VALUES (?, ?, 0, 0)
                ON CONFLICT(id) DO UPDATE SET
                    fish_name = excluded.fish_name;
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

            // 3. Fishing Rods catalog (preserving online rod weight if already set > 0 for `price == 0`)
            for item in rodsFile.items {
                try connection.run("""
                INSERT INTO fishing_rods (id, name, weight, price)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    weight = CASE WHEN excluded.price = 0 AND fishing_rods.weight > 0 THEN fishing_rods.weight ELSE excluded.weight END,
                    price = excluded.price;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name),
                    .integer(Int64(item.max_weight_kg)),
                    .integer(Int64(item.price_coins))
                ])
            }

            // 4. Fishing Lines catalog (preserving online line weight & stock_length if already set > 0 for `price == 0`)
            for item in linesFile.items {
                try connection.run("""
                INSERT INTO fishing_lines (id, name, weight, price, stock_length)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    weight = CASE WHEN excluded.price = 0 AND fishing_lines.weight > 0 THEN fishing_lines.weight ELSE excluded.weight END,
                    price = excluded.price,
                    stock_length = CASE WHEN excluded.price = 0 AND fishing_lines.stock_length > 0 THEN fishing_lines.stock_length ELSE excluded.stock_length END;
                """, bindings: [
                    .integer(Int64(item.id)),
                    .text(item.name),
                    .integer(Int64(item.max_weight_kg)),
                    .integer(Int64(item.price_coins)),
                    .integer(Int64(item.stock_length_m))
                ])
            }

            // 5. Coils catalog (preserving online coil bearing_count if already set > 0 for `price == 0`)
            for item in coilsFile.items {
                try connection.run("""
                INSERT INTO coils (id, name, bearing_count, price)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    bearing_count = CASE WHEN excluded.price = 0 AND coils.bearing_count > 0 THEN coils.bearing_count ELSE excluded.bearing_count END,
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

// MARK: - Catalog Listing & Starter Seed Helpers for UI Integration

public struct PondCatalogItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public let uiDisplayIndex: Int
    public let chatPondId: Int
    public let nameRu: String
    public let nameEn: String
    public let nameDe: String
    public let nameEs: String
    public let namePt: String
    public let requiredRank: Int
    public let requiresCoupon: Bool
    public let pondImageName: String

    public init(
        id: Int,
        uiDisplayIndex: Int,
        chatPondId: Int,
        nameRu: String,
        nameEn: String,
        nameDe: String = "",
        nameEs: String = "",
        namePt: String = "",
        requiredRank: Int,
        requiresCoupon: Bool,
        pondImageName: String
    ) {
        self.id = id
        self.uiDisplayIndex = uiDisplayIndex
        self.chatPondId = chatPondId
        self.nameRu = nameRu
        self.nameEn = nameEn
        self.nameDe = nameDe
        self.nameEs = nameEs
        self.namePt = namePt
        self.requiredRank = requiredRank
        self.requiresCoupon = requiresCoupon
        self.pondImageName = pondImageName
    }
}

public struct BaitShopCatalogItem: Sendable, Equatable, Identifiable {
    public var id: Int { spec.id }
    public let spec: BaitSpec
    public let stockAmount: Int

    public init(spec: BaitSpec, stockAmount: Int) {
        self.spec = spec
        self.stockAmount = stockAmount
    }
}

public struct HookShopCatalogItem: Sendable, Equatable, Identifiable {
    public var id: Int { spec.id }
    public let spec: HookSpec
    public let stockAmount: Int

    public init(spec: HookSpec, stockAmount: Int) {
        self.spec = spec
        self.stockAmount = stockAmount
    }
}

extension ReferenceCatalogStore {
    public func listAllRodSpecs() throws -> [FishingRodSpec] {
        let rows = try connection.query("SELECT id, name, weight, price FROM fishing_rods ORDER BY id ASC;")
        return rows.map {
            FishingRodSpec(
                id: $0.int("id"),
                name: $0.string("name"),
                weight: $0.int("weight"),
                price: $0.int("price")
            )
        }
    }

    public func listAllCoilSpecs() throws -> [CoilSpec] {
        let rows = try connection.query("SELECT id, name, bearing_count, price FROM coils ORDER BY id ASC;")
        return rows.map {
            CoilSpec(
                id: $0.int("id"),
                name: $0.string("name"),
                bearingCount: $0.int("bearing_count"),
                price: $0.int("price")
            )
        }
    }

    public func listAllLineSpecs() throws -> [FishingLineSpec] {
        let rows = try connection.query("SELECT id, name, weight, price, stock_length FROM fishing_lines ORDER BY id ASC;")
        return rows.map {
            FishingLineSpec(
                id: $0.int("id"),
                name: $0.string("name"),
                weight: $0.int("weight"),
                stockLength: $0.int("stock_length"),
                price: $0.int("price")
            )
        }
    }

    public func listAllHookCatalogItems() throws -> [HookShopCatalogItem] {
        let rows = try connection.query("SELECT id, name, stock_amount, price FROM hooks ORDER BY id ASC;")
        return rows.map {
            HookShopCatalogItem(
                spec: HookSpec(id: $0.int("id"), name: $0.string("name"), price: $0.int("price")),
                stockAmount: $0.int("stock_amount")
            )
        }
    }

    public func listAllBaitCatalogItems() throws -> [BaitShopCatalogItem] {
        let rows = try connection.query("SELECT id, name, stock_amount, price FROM baits ORDER BY id ASC;")
        return rows.map {
            BaitShopCatalogItem(
                spec: BaitSpec(id: $0.int("id"), name: $0.string("name"), rank: 0, price: $0.int("price")),
                stockAmount: $0.int("stock_amount")
            )
        }
    }

    public func listAllPonds() throws -> [PondCatalogItem] {
        let rows = try connection.query("""
        SELECT pond_data_id, ui_display_index, chat_pond_id, name_ru, name_en, name_de, name_es, name_pt, required_rank, requires_coupon, pond_image_name
        FROM ref_ponds
        ORDER BY ui_display_index ASC, pond_data_id ASC;
        """)
        return rows.map {
            PondCatalogItem(
                id: $0.int("pond_data_id"),
                uiDisplayIndex: $0.int("ui_display_index"),
                chatPondId: $0.int("chat_pond_id"),
                nameRu: $0.string("name_ru"),
                nameEn: $0.string("name_en"),
                nameDe: $0.string("name_de"),
                nameEs: $0.string("name_es"),
                namePt: $0.string("name_pt"),
                requiredRank: $0.int("required_rank"),
                requiresCoupon: $0.int("requires_coupon") != 0,
                pondImageName: $0.string("pond_image_name")
            )
        }
    }

    /// Seeds a built-in authentic starter subset of the v1.81 reference catalog if the database
    /// has not yet imported the full `data/*.json` files (e.g. on a fresh Simulator launch).
    /// Idempotent and non-destructive: does nothing if `fishes` already contains rows.
    public func seedBuiltInStarterCatalogIfEmpty(nowMs: Int64 = 0) throws {
        let fishCount = try connection.scalarInt("SELECT COUNT(*) FROM fishes;")
        guard fishCount == 0 else { return }

        try connection.transaction {
            let starterFishes: [(Int, String, Int, Int, Int, Int, Int, Int, Int)] = [
                (1, "Карась", 2131231046, 500, 55, 3, 6, 2, 4),
                (2, "Карась золотой", 2131231099, 500, 77, 3, 7, 3, 4),
                (3, "Плотва", 2131231157, 250, 35, 2, 5, 4, 3),
                (4, "Окунь", 2131231135, 400, 62, 3, 5, 3, 4),
                (5, "Щука", 2131231168, 2000, 306, 4, 5, 4, 5),
                (71, "Старая покрышка", 2131231100, 5000, 5, 5, 5, 1, 1)
            ]
            for f in starterFishes {
                let md5 = FishingChecksum.fishMd5(
                    id: f.0,
                    unitWeight: f.3,
                    unitPrice: f.4,
                    strength: f.5,
                    stamina: f.6,
                    intelligence: f.7,
                    aggression: f.8,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT INTO fishes (id, name, image, unit_weight, unit_price, strength, stamina, intelligence, aggression, md5)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(f.0)),
                    .text(f.1),
                    .integer(Int64(f.2)),
                    .integer(Int64(f.3)),
                    .integer(Int64(f.4)),
                    .integer(Int64(f.5)),
                    .integer(Int64(f.6)),
                    .integer(Int64(f.7)),
                    .integer(Int64(f.8)),
                    .text(md5)
                ])
                try connection.run("""
                INSERT OR IGNORE INTO records (id, fish_name, weight, bait_id)
                VALUES (?, ?, 0, 0);
                """, bindings: [.integer(Int64(f.0)), .text(f.1)])
            }

            let starterBaits: [(Int, String, Int, Int, Int)] = [
                (1, "червь", 2131230950, 30, 30),
                (2, "хлеб", 2131230961, 40, 15),
                (3, "опарыш", 2131230952, 35, 25)
            ]
            for b in starterBaits {
                try connection.run("""
                INSERT INTO baits (id, name, image, stock_amount, price)
                VALUES (?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(b.0)),
                    .text(b.1),
                    .integer(Int64(b.2)),
                    .integer(Int64(b.3)),
                    .integer(Int64(b.4))
                ])
            }

            let starterRods: [(Int, String, Int, Int)] = [
                (1, "fish small", 3, 100),
                (2, "kosrep", 5, 250),
                (3, "sokl", 9, 650),
                (5, "rotyl", 33, 4500),
                (11, "venol", 0, 0),
                (12, "master fish", 0, 0),
                (13, "dasf", 0, 0)
            ]
            for r in starterRods {
                try connection.run("""
                INSERT INTO fishing_rods (id, name, weight, price)
                VALUES (?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(r.0)),
                    .text(r.1),
                    .integer(Int64(r.2)),
                    .integer(Int64(r.3))
                ])
            }

            let starterLines: [(Int, String, Int, Int, Int)] = [
                (1, "small", 3, 100, 100),
                (2, "kosp", 6, 220, 100),
                (3, "master", 13, 550, 100),
                (5, "somik", 45, 3200, 100),
                (14, "leska 600", 0, 0, 0),
                (15, "leska 810", 0, 0, 0),
                (16, "big fish", 0, 0, 0)
            ]
            for l in starterLines {
                try connection.run("""
                INSERT INTO fishing_lines (id, name, weight, price, stock_length)
                VALUES (?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(l.0)),
                    .text(l.1),
                    .integer(Int64(l.2)),
                    .integer(Int64(l.3)),
                    .integer(Int64(l.4))
                ])
            }

            let starterCoils: [(Int, String, Int, Int)] = [
                (1, "gert", 1, 100),
                (2, "terf", 2, 300),
                (3, "rosl", 3, 850),
                (8, "rewery", 0, 0),
                (9, "tyhol", 0, 0),
                (10, "wectern", 0, 0)
            ]
            for c in starterCoils {
                try connection.run("""
                INSERT INTO coils (id, name, bearing_count, price)
                VALUES (?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(c.0)),
                    .text(c.1),
                    .integer(Int64(c.2)),
                    .integer(Int64(c.3))
                ])
            }

            let starterHooks: [(Int, String, Int, Int)] = [
                (1, "fish 1", 5, 100),
                (2, "fish 2", 5, 220)
            ]
            for h in starterHooks {
                try connection.run("""
                INSERT INTO hooks (id, name, stock_amount, price)
                VALUES (?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(h.0)),
                    .text(h.1),
                    .integer(Int64(h.2)),
                    .integer(Int64(h.3))
                ])
            }

            try connection.run("""
            INSERT INTO coupons (id, name, day_count, price, dn)
            VALUES (1, 'Путевой купон (1 день)', 1, 150000, 288);
            """)

            // All 14 Achievements (`AchievementGenerator` + `D0.d.m`)
            let starterAchievements: [(Int, Int, Int)] = [
                (1, 2131231372, 200),
                (2, 2131231378, 700),
                (3, 2131231379, -500),
                (4, 2131231380, 550),
                (5, 2131231381, 450),
                (6, 2131231382, 350),
                (7, 2131231383, 650),
                (8, 2131231384, 750),
                (9, 2131231385, 800),
                (10, 2131231373, 500),
                (11, 2131231374, -700),
                (12, 2131231375, 1000),
                (13, 2131231376, 300),
                (14, 2131231377, 400)
            ]
            for a in starterAchievements {
                let achMd5 = FishingChecksum.achievementMd5(
                    id: a.0,
                    score: 0,
                    level: 0,
                    nag: 0,
                    nagsize: a.2,
                    date: nowMs,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT OR IGNORE INTO achievements (id, image, score, level, nag, nagsize, date, md5)
                VALUES (?, ?, 0, 0, 0, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(a.0)),
                    .integer(Int64(a.1)),
                    .integer(Int64(a.2)),
                    .integer(nowMs),
                    .text(achMd5)
                ])
            }

            // Starter Quests covering Types 2, 7, 1, 3, 4 (`QuestGenerator`)
            let starterQuests: [(Int, Int, String, String, String, String, Int, String)] = [
                (1, 2, "0", "1,2,12", "0", "20000", 0, "200,150"),
                (2, 7, "3,4,5", "0", "5,5,5", "500-1000,500-1000,500-1000", 0, "500,300"),
                (3, 1, "1", "1", "3", "0", 0, "150,100"),
                (4, 3, "5", "1", "2", "1500", 0, "300,200"),
                (5, 4, "3", "2", "2", "300", 0, "250,150")
            ]
            for q in starterQuests {
                let qMd5 = FishingChecksum.questMd5(
                    id: q.0,
                    type: q.1,
                    fish: q.2,
                    bait: q.3,
                    num: q.4,
                    weight: q.5,
                    cat: q.6,
                    nag: q.7,
                    res: "null",
                    made: 0,
                    date: nowMs,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT OR IGNORE INTO quests (id, type, fish, bait, num, weight, cat, nag, res, made, date, md5)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'null', 0, ?, ?);
                """, bindings: [
                    .integer(Int64(q.0)),
                    .integer(Int64(q.1)),
                    .text(q.2),
                    .text(q.3),
                    .text(q.4),
                    .text(q.5),
                    .integer(Int64(q.6)),
                    .text(q.7),
                    .integer(nowMs),
                    .text(qMd5)
                ])
            }

            // Starter Pond #0 ('Кедровый остров') & Pond #1 ('Лесное озеро')
            try connection.run("""
            INSERT INTO ref_ponds (
                pond_data_id, ui_display_index, chat_pond_id,
                name_ru, name_en, name_de, name_es, name_pt,
                required_rank, requires_coupon,
                pond_image_res_id, pond_image_name,
                big_pond_image_res_id, big_pond_image_name
            ) VALUES
                (0, 0, 1, 'Кедровый остров', 'Cedar Island', 'Zederinsel', 'Isla de Cedro', 'Ilha do Cedro', 0, 0, 2131231519, 'pond_1', 2131231532, 'pond_1_big'),
                (1, 1, 2, 'Лесное озеро', 'Forest Lake', 'Waldsee', 'Lago del Bosque', 'Lago da Floresta', 0, 0, 2131231520, 'pond_2', 2131231533, 'pond_2_big');
            """)

            // Active baits for Pond 0: slot 0 -> bait 1 (червь, index 0), slot 1 -> bait 2 (хлеб, index 1)
            let pondCatches: [(Int, Int, Int, Int, Int, Int, Int)] = [
                (0, 0, 0, 1, 0, 0, 1),
                (0, 0, 0, 1, 1, 1, 2),
                (0, 0, 0, 1, 2, 3, 4),
                (0, 1, 1, 2, 0, 0, 1),
                (0, 1, 1, 2, 1, 2, 3),
                (1, 0, 0, 1, 0, 0, 1),
                (1, 0, 0, 1, 1, 4, 5)
            ]
            for pc in pondCatches {
                try connection.run("""
                INSERT INTO ref_pond_bait_catches (
                    pond_data_id, bait_slot_index, bait_index_0based, bait_db_id,
                    catch_order_index, fish_index_0based, fish_db_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(pc.0)),
                    .integer(Int64(pc.1)),
                    .integer(Int64(pc.2)),
                    .integer(Int64(pc.3)),
                    .integer(Int64(pc.4)),
                    .integer(Int64(pc.5)),
                    .integer(Int64(pc.6))
                ])
            }

            let pondWeights: [(Int, Int, Int, Int, Int)] = [
                (0, 0, 1, 50, 2450),
                (0, 1, 2, 80, 2200),
                (0, 2, 3, 40, 1200),
                (0, 3, 4, 70, 1800),
                (1, 0, 1, 60, 2500),
                (1, 4, 5, 400, 4500)
            ]
            for pw in pondWeights {
                try connection.run("""
                INSERT INTO ref_pond_species_weights (
                    pond_data_id, fish_index_0based, fish_db_id, min_weight_grams, max_weight_grams
                ) VALUES (?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(pw.0)),
                    .integer(Int64(pw.1)),
                    .integer(Int64(pw.2)),
                    .integer(Int64(pw.3)),
                    .integer(Int64(pw.4))
                ])
            }

            for period in ["morning", "afternoon", "evening", "night"] {
                let factors: [(Int, Int, Int, Int, Int, Int, Int)] = [
                    (0, 0, 0, 0, 0, 1, 65),
                    (0, 0, 0, 1, 1, 2, 45),
                    (0, 0, 0, 2, 3, 4, 50),
                    (0, 1, 1, 0, 0, 1, 70),
                    (0, 1, 1, 1, 2, 3, 60),
                    (1, 0, 0, 0, 0, 1, 60),
                    (1, 0, 0, 1, 4, 5, 50)
                ]
                for tf in factors {
                    try connection.run("""
                    INSERT INTO ref_pond_time_factors (
                        pond_data_id, day_period, bait_slot_index, bait_index_0based,
                        entry_index, fish_index_0based, fish_db_id, probability_percent
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                    """, bindings: [
                        .integer(Int64(tf.0)),
                        .text(period),
                        .integer(Int64(tf.1)),
                        .integer(Int64(tf.2)),
                        .integer(Int64(tf.3)),
                        .integer(Int64(tf.4)),
                        .integer(Int64(tf.5)),
                        .integer(Int64(tf.6))
                    ])
                }
            }

            for (idx, exp) in BalanceTables.playerRankExpThresholds.enumerated() {
                try connection.run("""
                INSERT INTO ref_rank_thresholds (rank_index_1based, required_experience)
                VALUES (?, ?);
                """, bindings: [
                    .integer(Int64(idx + 1)),
                    .integer(Int64(exp))
                ])
            }

            try rebuildReferenceDataSigns(nowMs: nowMs)
        }
    }
}