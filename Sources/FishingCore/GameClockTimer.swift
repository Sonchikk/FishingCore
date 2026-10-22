import Foundation

public struct GameClockTimer: Sendable, Equatable {
    public static let tickIntervalMs: Int64 = 2000
    public static let couponTicksPerDay: Int = 288

    public var hour: Int
    public var minute: Int

    public init(hour: Int = 6, minute: Int = 0) {
        self.hour = ((hour % 24) + 24) % 24
        self.minute = ((minute % 60) + 60) % 60
    }

    public mutating func tickOneGameMinute(
        isPaidPond: Bool = false,
        activeCouponRemainingTicks: inout Int?
    ) {
        if minute == 59 {
            minute = 0
            if hour == 23 {
                hour = 0
            } else {
                hour += 1
            }
        } else {
            minute += 1
        }

        if isPaidPond, var remaining = activeCouponRemainingTicks {
            remaining -= 1
            if remaining <= 0 {
                activeCouponRemainingTicks = nil
            } else {
                activeCouponRemainingTicks = remaining
            }
        }
    }

    public mutating func catchUpAfterSleepIfNeeded(
        stateCode: Int,
        beginTimeMs: Int64,
        beginHour: Int,
        beginMinute: Int,
        nowMs: Int64
    ) -> Bool {
        guard stateCode == 1 || stateCode == 2 else { return false }
        let elapsedMinutes = Int((nowMs - beginTimeMs) / Self.tickIntervalMs)
        guard elapsedMinutes > 0 && elapsedMinutes < 120 else { return false }

        let targetTotalMinutes = (beginHour * 60 + beginMinute + elapsedMinutes) % (24 * 60)
        let currentTotalMinutes = hour * 60 + minute
        let diff = abs(targetTotalMinutes - currentTotalMinutes)
        guard diff > 2 else { return false }

        self.hour = targetTotalMinutes / 60
        self.minute = targetTotalMinutes % 60
        return true
    }

    public static func antiCheatCatchDeltaMs(
        beginTimeMs: Int64,
        catchTimeMs: Int64
    ) -> Int64 {
        let raw = beginTimeMs - catchTimeMs
        if raw > 60000 { return 60000 }
        if raw < -10000 { return -10000 }
        return raw
    }

    public static func antiCheatBiteDelaySeconds(
        beginTimeMs: Int64,
        biteTimeMs: Int64
    ) -> Int64 {
        let raw = (biteTimeMs - beginTimeMs) / 1000
        if raw > 500 { return 500 }
        if raw < -50 { return -50 }
        return raw
    }
}