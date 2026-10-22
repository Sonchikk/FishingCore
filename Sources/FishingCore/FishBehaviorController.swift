import Foundation

public struct FishBehaviorController: Sendable, Equatable {
    public private(set) var strength: Int = 0
    public private(set) var stamina: Int = 0
    public private(set) var currentStamina: Int = 0
    public private(set) var intelligence: Int = 0
    public private(set) var aggression: Int = 0
    public private(set) var isExhausted: Bool = false
    public private(set) var lastSurgeTimeMs: Int64 = 0

    public init() {}

    public init(strength: Int, stamina: Int, intelligence: Int, aggression: Int) {
        self.configure(
            strength: strength,
            stamina: stamina,
            intelligence: intelligence,
            aggression: aggression
        )
    }

    public mutating func configure(
        strength: Int,
        stamina: Int,
        intelligence: Int,
        aggression: Int
    ) {
        self.strength = strength
        self.stamina = stamina
        self.currentStamina = stamina * 10
        self.intelligence = intelligence
        self.aggression = aggression
    }

    public var aggressionValue: Int { aggression }
    public var intelligenceValue: Int { intelligence }
    public var strengthValue: Int { strength }
    public var exhaustedFlag: Bool { isExhausted }

    public var surgeSpeedMultiplier: Float {
        Float(aggression) * 0.2 + 1.5
    }

    public mutating func drainStamina(_ amount: Int) {
        currentStamina -= amount
        if currentStamina <= 0 {
            currentStamina = 0
            isExhausted = true
        }
    }

    public mutating func trySurge(
        nowMs: Int64,
        rng: inout some FishingRandomGenerator
    ) -> Bool {
        if isExhausted {
            return false
        }
        let elapsed = nowMs - lastSurgeTimeMs
        if elapsed < 2000 {
            return false
        }
        let threshold = aggression * 5 + 10
        let roll = rng.nextInt(bound: 100)
        let didSurge = roll < threshold
        if didSurge {
            lastSurgeTimeMs = nowMs
        }
        return didSurge
    }

    public func shouldEvadeHorizontally(
        rng: inout some FishingRandomGenerator
    ) -> Bool {
        let roll = rng.nextInt(bound: 100)
        return roll < (intelligence * 5)
    }
}