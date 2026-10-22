import Foundation

public protocol FishingRandomGenerator: Sendable {
    mutating func nextInt(bound: Int) -> Int
    mutating func nextFloat() -> Float
}

public struct SystemFishingRandom: FishingRandomGenerator {
    public init() {}
    public mutating func nextInt(bound: Int) -> Int {
        guard bound > 1 else { return 0 }
        return Int.random(in: 0..<bound)
    }
    public mutating func nextFloat() -> Float {
        Float.random(in: 0.0..<1.0)
    }
}

public struct ScriptedFishingRandom: FishingRandomGenerator {
    public var intQueue: [Int]
    public var floatQueue: [Float]
    public var defaultInt: Int
    public var defaultFloat: Float

    public init(
        ints: [Int] = [],
        floats: [Float] = [],
        defaultInt: Int = 0,
        defaultFloat: Float = 0.5
    ) {
        self.intQueue = ints
        self.floatQueue = floats
        self.defaultInt = defaultInt
        self.defaultFloat = defaultFloat
    }

    public mutating func nextInt(bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        if !intQueue.isEmpty {
            let val = intQueue.removeFirst()
            return ((val % bound) + bound) % bound
        }
        return ((defaultInt % bound) + bound) % bound
    }

    public mutating func nextFloat() -> Float {
        if !floatQueue.isEmpty {
            return floatQueue.removeFirst()
        }
        return defaultFloat
    }
}

public enum BiteTimeOfDay: String, Sendable, Equatable, CaseIterable {
    case night
    case morning
    case afternoon
    case evening

    public static func from(hour: Int, minute: Int = 0) -> BiteTimeOfDay {
        if hour >= 6 && hour < 12 {
            return .morning
        } else if hour >= 12 && hour < 20 {
            return .afternoon
        } else if hour >= 20 && hour <= 23 && minute <= 59 {
            return .evening
        } else {
            return .night
        }
    }
}

public struct DayNightLighting: Sendable, Equatable {
    public let isDayLight: Bool
    public let canvasColorFilterHex: UInt32?
    public let ambientTrackIndex: Int

    public static func forHour(_ hour: Int) -> DayNightLighting {
        let isDay = (hour >= 5 && hour < 22)
        return DayNightLighting(
            isDayLight: isDay,
            canvasColorFilterHex: isDay ? nil : 0xFF8888AA,
            ambientTrackIndex: isDay ? 0 : 1
        )
    }
}

public struct FishSpecies: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let unitWeight: Int
    public let unitPrice: Int
    public let strength: Int
    public let stamina: Int
    public let intelligence: Int
    public let aggression: Int
    public let md5Valid: Bool

    public init(
        id: Int,
        name: String = "",
        unitWeight: Int,
        unitPrice: Int,
        strength: Int,
        stamina: Int,
        intelligence: Int,
        aggression: Int,
        md5Valid: Bool = true
    ) {
        self.id = id
        self.name = name
        self.unitWeight = unitWeight
        self.unitPrice = unitPrice
        self.strength = strength
        self.stamina = stamina
        self.intelligence = intelligence
        self.aggression = aggression
        self.md5Valid = md5Valid
    }
}

public struct FishingRodSpec: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let weight: Int
    public let price: Int

    public init(id: Int, name: String = "", weight: Int, price: Int = 0) {
        self.id = id
        self.name = name
        self.weight = weight
        self.price = price
    }
}

public struct CoilSpec: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let bearingCount: Int
    public let price: Int

    public init(id: Int, name: String = "", bearingCount: Int, price: Int = 0) {
        self.id = id
        self.name = name
        self.bearingCount = bearingCount
        self.price = price
    }
}

public struct FishingLineSpec: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let weight: Int
    public let stockLength: Int
    public let price: Int

    public init(id: Int, name: String = "", weight: Int, stockLength: Int = 100, price: Int = 0) {
        self.id = id
        self.name = name
        self.weight = weight
        self.stockLength = stockLength
        self.price = price
    }
}

public struct HookSpec: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let price: Int

    public init(id: Int, name: String = "", price: Int = 0) {
        self.id = id
        self.name = name
        self.price = price
    }
}

public struct BaitSpec: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let rank: Int
    public let price: Int

    public init(id: Int, name: String = "", rank: Int = 0, price: Int = 0) {
        self.id = id
        self.name = name
        self.rank = rank
        self.price = price
    }
}

public struct UserRodItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public var rod: FishingRodSpec
    public var strength: Int

    public init(id: Int = 1, rod: FishingRodSpec, strength: Int = 100) {
        self.id = id
        self.rod = rod
        self.strength = strength
    }
}

public struct UserCoilItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public var coil: CoilSpec
    public var strength: Int

    public init(id: Int = 1, coil: CoilSpec, strength: Int = 100) {
        self.id = id
        self.coil = coil
        self.strength = strength
    }
}

public struct UserLineItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public var line: FishingLineSpec
    public var length: Int

    public init(id: Int = 1, line: FishingLineSpec, length: Int = 100) {
        self.id = id
        self.line = line
        self.length = length
    }
}

public struct UserHookItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public var hook: HookSpec
    public var amount: Int

    public init(id: Int = 1, hook: HookSpec, amount: Int = 10) {
        self.id = id
        self.hook = hook
        self.amount = amount
    }
}

public struct UserBaitItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public var bait: BaitSpec
    public var amount: Int

    public init(id: Int = 1, bait: BaitSpec, amount: Int = 30) {
        self.id = id
        self.bait = bait
        self.amount = amount
    }
}

public struct AssembledTackle: Sendable, Equatable {
    public var userRod: UserRodItem?
    public var userLine: UserLineItem?
    public var userCoil: UserCoilItem?
    public var userHook: UserHookItem?
    public var userBait: UserBaitItem?

    public init(
        userRod: UserRodItem? = nil,
        userLine: UserLineItem? = nil,
        userCoil: UserCoilItem? = nil,
        userHook: UserHookItem? = nil,
        userBait: UserBaitItem? = nil
    ) {
        self.userRod = userRod
        self.userLine = userLine
        self.userCoil = userCoil
        self.userHook = userHook
        self.userBait = userBait
    }

    public func missingComponentNames(
        rodLabel: String = "удочка",
        lineLabel: String = "леска",
        coilLabel: String = "катушка",
        hookLabel: String = "крючок",
        baitLabel: String = "наживка"
    ) -> [String] {
        var missing: [String] = []
        if userRod == nil { missing.append(rodLabel) }
        if userLine == nil { missing.append(lineLabel) }
        if userCoil == nil { missing.append(coilLabel) }
        if userHook == nil { missing.append(hookLabel) }
        if userBait == nil { missing.append(baitLabel) }
        return missing
    }

    public var isComplete: Bool {
        userRod != nil && userLine != nil && userCoil != nil && userHook != nil && userBait != nil
    }
}

public struct CaughtUserFish: Sendable, Equatable {
    public let fish: FishSpecies
    public let weightGrams: Int
    public let pondIndex: Int
    public let baitIndex: Int
    public let rodWeightKg: Int
    public let catchTimeMs: Int64

    public init(
        fish: FishSpecies,
        weightGrams: Int,
        pondIndex: Int,
        baitIndex: Int,
        rodWeightKg: Int,
        catchTimeMs: Int64
    ) {
        self.fish = fish
        self.weightGrams = weightGrams
        self.pondIndex = pondIndex
        self.baitIndex = baitIndex
        self.rodWeightKg = rodWeightKg
        self.catchTimeMs = catchTimeMs
    }

    public var sellingPriceCoins: Int {
        guard fish.unitWeight > 0 else { return 0 }
        let ratio = Double(weightGrams) / Double(fish.unitWeight)
        return Int(ratio * Double(fish.unitPrice))
    }
}

public struct PondFishWeightRange: Sendable, Equatable {
    public let fishIndex0Based: Int
    public let minWeightGrams: Int
    public let maxWeightGrams: Int

    public init(fishIndex0Based: Int, minWeightGrams: Int, maxWeightGrams: Int) {
        self.fishIndex0Based = fishIndex0Based
        self.minWeightGrams = minWeightGrams
        self.maxWeightGrams = maxWeightGrams
    }
}

public struct PondFishBiteFactor: Sendable, Equatable {
    public let fishIndex0Based: Int
    public let probabilityPercent: Int

    public init(fishIndex0Based: Int, probabilityPercent: Int) {
        self.fishIndex0Based = fishIndex0Based
        self.probabilityPercent = probabilityPercent
    }
}

public struct PondSimulationData: Sendable, Equatable {
    public let pondIndex: Int
    public let activeBaitIndices0Based: [Int]
    public let catchableFishByBaitSlot: [[Int]]
    public let fishWeightRanges: [PondFishWeightRange]
    public let factorsMorning: [[PondFishBiteFactor]]
    public let factorsAfternoon: [[PondFishBiteFactor]]
    public let factorsEvening: [[PondFishBiteFactor]]
    public let factorsNight: [[PondFishBiteFactor]]

    public init(
        pondIndex: Int,
        activeBaitIndices0Based: [Int],
        catchableFishByBaitSlot: [[Int]],
        fishWeightRanges: [PondFishWeightRange],
        factorsMorning: [[PondFishBiteFactor]],
        factorsAfternoon: [[PondFishBiteFactor]],
        factorsEvening: [[PondFishBiteFactor]],
        factorsNight: [[PondFishBiteFactor]]
    ) {
        self.pondIndex = pondIndex
        self.activeBaitIndices0Based = activeBaitIndices0Based
        self.catchableFishByBaitSlot = catchableFishByBaitSlot
        self.fishWeightRanges = fishWeightRanges
        self.factorsMorning = factorsMorning
        self.factorsAfternoon = factorsAfternoon
        self.factorsEvening = factorsEvening
        self.factorsNight = factorsNight
    }

    public func factors(for timeOfDay: BiteTimeOfDay) -> [[PondFishBiteFactor]] {
        switch timeOfDay {
        case .morning: return factorsMorning
        case .afternoon: return factorsAfternoon
        case .evening: return factorsEvening
        case .night: return factorsNight
        }
    }
}