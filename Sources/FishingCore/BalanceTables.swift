import Foundation

/// Exact port of `LD0/d;` (`BalanceTables`) from `classes.dex` (`fishing181.apk`).
/// Contains all 13 static balance, progression, and probability tables (`a`..`m`) and their index accessors.
public struct BalanceTables: Sendable, Equatable {

    /// `LD0/d;.a:[I` (`f(I)I`) — XP divisor in grams per 1 XP (`(weightGrams / a[fishId - 1]) + 1`) for all 141 fish species.
    public static let fishReferenceWeightsGrams: [Int] = [
        123, 103, 84, 108, 71, 55, 217, 146, 166, 11,
        267, 1343, 272, 195, 44, 15, 12, 152, 315, 255,
        193, 105, 143, 378, 288, 87, 234, 203, 745, 24,
        88, 177, 54, 40, 499, 99, 890, 1280, 430, 344,
        505, 689, 125, 789, 590, 34, 178, 76, 144, 238,
        201, 333, 400, 1108, 607, 292, 60, 775, 48, 203,
        162, 188, 377, 74, 85, 198, 15, 93, 545, 60,
        2345, 3089, 81, 67, 110, 23, 2678, 2500, 43, 1640,
        878, 1005, 15678, 2345, 1456, 10789, 7890, 2349, 1367, 1144,
        2050, 177, 655, 144, 154, 615, 1785, 1447, 1972, 7438,
        750, 290, 289, 250, 198, 155, 170, 117, 95, 106,
        178, 1590, 1350, 850, 950, 202, 161, 480, 270, 710,
        491, 510, 990, 217, 58, 157, 103, 29, 32, 178,
        172, 38, 212, 147, 252, 178, 97, 312, 78, 204,
        217
    ]

    /// `LD0/d;.b:[I` — Bearing counts (`1..10`) for all 10 coils (including online coils `8..10`).
    public static let coilBearingCounts: [Int] = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    ]

    /// `LD0/d;.c:[I` (`j(I)I`) — Initial durability units (`500..3300`) for all 10 coils.
    /// NOTE: **[ORIGINAL BUG]** `GameView$c.t()` calls `D0.d.j(hook.id - 1)` and uses this array as the hook escape resistance bonus `i`.
    public static let coilInitialStrengths: [Int] = [
        500, 800, 1200, 1500, 1800, 2100, 2400, 2700, 3000, 3300
    ]

    /// `LD0/d;.d:[I` (`k(I)I`) — Escape resistance base steps `j` in `GameView$c.t()` by fishWeight / rodWeight ratio (`<=0.25`, `<=0.50`, `<=0.75`, `<=1.00`, `>1.00`, plus `10000`).
    public static let fightTensionParameters: [Int] = [
        2000, 1600, 1200, 800, 400, 10000
    ]

    /// `LD0/d;.e:[I` (`d(I)I`) — Maximum fish weight threshold (kg) per hook (`1..10`) used in `GameView$c.z()`.
    public static let hookMaxFishWeightsKg: [Int] = [
        6, 14, 20, 44, 78, 118, 225, 383, 617, 2177
    ]

    /// `LD0/d;.f:[I` (`b(I)I`) — Maximum fish weight threshold (kg) per coil (`1..10`) used in `GameView$c.y()`.
    public static let coilMaxFishWeightsKg: [Int] = [
        8, 19, 35, 67, 94, 155, 273, 481, 609, 2177
    ]

    /// `LD0/d;.g:[I` (`c(I)I`) — `Random(1000)` probability bracket boundaries used in `GameView$c.p()`.
    public static let weightRollBracketsPermille: [Int] = [
        50, 350, 400, 700, 730, 995, 0, 50, 350, 400, 700, 730, 995, 1000
    ]

    /// `LD0/d;.j:[I` (`g(I)I`, length via `h()I`) — Experience thresholds for player ranks (categories `1..45`).
    public static let playerRankExpThresholds: [Int] = [
        500, 1500, 4000, 9700, 18000, 34000, 50000, 68000, 100000, 150000,
        260000, 440000, 800000, 1110000, 1400000, 1650000, 2000000, 2500000, 3000000, 4000000,
        5000000, 6000000, 7000000, 8000000, 9000000, 10000000, 11000000, 12000000, 13000000, 14000000,
        15000000, 16000000, 17000000, 18000000, 19000000, 20000000, 30000000, 40000000, 50000000, 70000000,
        90000000, 110000000, 130000000, 150000000, 170000000
    ]

    /// `LD0/d;.k:[I` (`i(I)I`) — Reference max weight (kg) for all 13 fishing rods (`1..13`), including online rods `11..13` (`525, 680, 1900` kg).
    public static let fishingRodWeightsKg: [Int] = [
        3, 5, 9, 17, 33, 52, 74, 112, 146, 179, 525, 680, 1900
    ]

    /// `LD0/d;.l:[I` (`e(I)I`) — Reference max weight (kg) for all 16 fishing lines (`1..16`), including online lines `14..16` (`600, 810, 2150` kg).
    public static let fishingLineWeightsKg: [Int] = [
        3, 6, 13, 22, 45, 78, 116, 149, 180, 225, 290, 333, 376, 600, 810, 2150
    ]

    /// `LD0/d;.m:[[I` (`a()[[I`) — 3-tier target thresholds `[tier1, tier2, tier3]` for each of the 14 achievements (`1..14`).
    public static let achievementThresholds: [[Int]] = [
        [7, 15, 30],
        [1000, 100000, 500000],
        [30, 150, 300],
        [20, 100, 200],
        [20, 100, 200],
        [10, 50, 100],
        [50, 400, 1000],
        [20, 100, 200],
        [100000, 1000000, 2000000],
        [500000, 5000000, 50000000],
        [30, 150, 300],
        [30, 150, 300],
        [50, 200, 500],
        [6, 12, 17]
    ]

    public var fishXpWeightDivisors: [Int] { Self.fishReferenceWeightsGrams }

    public init() {}

    public func achievementThresholdsMatrix() -> [[Int]] { Self.achievementThresholds }
    public func coilMaxFishWeightKg(at index: Int) -> Int { Self.coilMaxFishWeightsKg[index] }
    public func weightBracketBoundary(at index: Int) -> Int { Self.weightRollBracketsPermille[index] }
    public func hookMaxFishWeightKg(at index: Int) -> Int { Self.hookMaxFishWeightsKg[index] }
    public func lineMaxWeightKg(at index: Int) -> Int { Self.fishingLineWeightsKg[index] }
    public func fishReferenceWeightGrams(at index: Int) -> Int { Self.fishReferenceWeightsGrams[index] }
    public func rankExpThreshold(at index: Int) -> Int { Self.playerRankExpThresholds[index] }
    public func rankCount() -> Int { Self.playerRankExpThresholds.count }
    public func rodMaxWeightKg(at index: Int) -> Int { Self.fishingRodWeightsKg[index] }
    public func coilInitialStrengthOrHookBonus(at index: Int) -> Int { Self.coilInitialStrengths[index] }
    public func fightTensionParameter(at index: Int) -> Int { Self.fightTensionParameters[index] }
}