import Foundation

public struct ProgressionCalculator: Sendable, Equatable {
    public static let maxFishnetCapacity: Int = 50

    public static func experienceGained(
        fishId1Based: Int,
        weightGrams: Int,
        balanceTables: BalanceTables = BalanceTables()
    ) -> Int {
        let index = fishId1Based - 1
        guard index >= 0 && index < BalanceTables.fishReferenceWeightsGrams.count else {
            return 1
        }
        let divisor = balanceTables.fishReferenceWeightGrams(at: index)
        guard divisor > 0 else { return 1 }
        return (weightGrams / divisor) + 1
    }

    public static func categoryForExperience(
        _ experience: Int,
        balanceTables: BalanceTables = BalanceTables()
    ) -> Int {
        var category = 0
        for i in 0..<balanceTables.rankCount() {
            if experience >= balanceTables.rankExpThreshold(at: i) {
                category = i + 1
            } else {
                break
            }
        }
        return category
    }

    public static func decimalDigitSum(of weightGrams: Int) -> Int {
        let text = String(abs(weightGrams))
        return text.compactMap { $0.wholeNumberValue }.reduce(0, +)
    }

    public static func isLuckyWeight25(_ weightGrams: Int) -> Bool {
        decimalDigitSum(of: weightGrams) == 25
    }

    public static func isRepdigitWeight(_ weightGrams: Int) -> Bool {
        let text = String(abs(weightGrams))
        guard text.count > 3, let first = text.first else { return false }
        return text.allSatisfy { $0 == first }
    }

    public static func isCleanerTrashCatch(fishId1Based: Int) -> Bool {
        fishId1Based == 71 || fishId1Based == 112
    }
}