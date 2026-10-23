import Foundation

public enum FishingState: Int, Sendable, Equatable, CaseIterable {
    case idle = 0
    case waitingForBite = 1
    case fishFight = 2
    case fishCaught = 3
    case missingTackleHold = 4
    case lineBroken = 5
    case fishEscaped = 6
    case rodBroken = 7
    case coilBroken = 8
    case alarmPermissionHold = 9
}

public enum FishingUIEvent: Sendable, Equatable {
    case missingTackle(String)
    case tensionChanged(Int)
    case missedBiteDuringSleep
    case rodBroken
    case exactAlarmPermissionRequired
    case fishCaught(CaughtUserFish)
    case fishEscaped
    case biteTriggered
    case lineBroken
    case coilBroken
}

public struct CastSessionMetadata: Sendable, Equatable {
    public let beginTimeMs: Int64
    public let beginHour: Int
    public let beginMinute: Int
    public let bobberX: Float
    public let bobberY: Float

    public init(
        beginTimeMs: Int64,
        beginHour: Int,
        beginMinute: Int,
        bobberX: Float,
        bobberY: Float
    ) {
        self.beginTimeMs = beginTimeMs
        self.beginHour = beginHour
        self.beginMinute = beginMinute
        self.bobberX = bobberX
        self.bobberY = bobberY
    }
}

public struct FishingStateMachine: Sendable, Equatable {
    public var viewWidth: Int
    public var viewHeight: Int
    public var bobberBitmapWidth: Int
    public var bobberBitmapHeight: Int
    public var animationsEnabled: Bool
    public let balanceTables: BalanceTables
    public var pondData: PondSimulationData
    public var timeOfDay: BiteTimeOfDay
    public var fishCatalogById1Based: [Int: FishSpecies]
    public var tackle: AssembledTackle

    public var isRunning: Bool = true
    public var holdStateFlag: Bool = false
    public private(set) var isPulled: Bool = false
    public private(set) var isPreHookBobbing: Bool = false
    public private(set) var state: FishingState = .idle
    public private(set) var tension: Int = 0
    public private(set) var hookEscapeBonus: Int = 0
    public private(set) var rodRatioEscapeBase: Int = 0
    public private(set) var obfuscatedFishIndex: Int = 0
    public private(set) var obfuscatedWeightGrams: Int = 0
    public private(set) var obfuscationMultiplier: Int = 1
    public private(set) var bobbingDirectionSign: Int = -1
    public private(set) var scheduledBiteTimeMs: Int64 = 0
    public private(set) var idleReleaseStartTimeMs: Int64 = 0
    public private(set) var biteStartTimeMs: Int64 = 0
    public private(set) var lastCaughtFish: CaughtUserFish? = nil
    public private(set) var fishController: FishBehaviorController? = nil

    public private(set) var bobber: BobberState? = nil
    public private(set) var rodSprite: RodSpriteState
    public private(set) var lineGeometry: FishingLineGeometry? = nil
    public private(set) var castBeginTimeMs: Int64 = 0
    public var castActiveFlag: Int = 0
    public var isCatchTimeLocked: Bool = false
    public private(set) var lastCastMetadata: CastSessionMetadata? = nil

    public init(
        viewWidth: Int = 1280,
        viewHeight: Int = 800,
        bobberBitmapWidth: Int = 24,
        bobberBitmapHeight: Int = 40,
        animationsEnabled: Bool = true,
        balanceTables: BalanceTables = BalanceTables(),
        pondData: PondSimulationData,
        timeOfDay: BiteTimeOfDay = .morning,
        fishCatalogById1Based: [Int: FishSpecies],
        tackle: AssembledTackle
    ) {
        self.viewWidth = viewWidth
        self.viewHeight = viewHeight
        self.bobberBitmapWidth = bobberBitmapWidth
        self.bobberBitmapHeight = bobberBitmapHeight
        self.animationsEnabled = animationsEnabled
        self.balanceTables = balanceTables
        self.pondData = pondData
        self.timeOfDay = timeOfDay
        self.fishCatalogById1Based = fishCatalogById1Based
        self.tackle = tackle
        self.rodSprite = RodSpriteState(
            viewWidth: viewWidth,
            viewHeight: viewHeight,
            rodWidth: 200,
            rodHeight: viewHeight / 2
        )
    }

    public var activeFishId1Based: Int? {
        guard obfuscationMultiplier > 0, fishController != nil else { return nil }
        return (obfuscatedFishIndex / obfuscationMultiplier) + 1
    }

    public var activeFishWeightGrams: Int {
        guard obfuscationMultiplier > 0 else { return 0 }
        return obfuscatedWeightGrams / obfuscationMultiplier
    }

    public var activeFishWeightKg: Double {
        guard obfuscationMultiplier > 0 else { return 0.0 }
        return Double(obfuscatedWeightGrams) / (Double(obfuscationMultiplier) * 1000.0)
    }

    public var horizonMinY: Float {
        Float((viewHeight / 5) + bobberBitmapHeight)
    }

    public var waterVerticalSpan: Float {
        Float(viewHeight - (viewHeight / 5) - bobberBitmapHeight)
    }

    public static func randomInclusive(
        min: Int,
        max: Int,
        rng: inout some FishingRandomGenerator
    ) -> Int {
        let span = (max - min) + 1
        guard span > 0 else { return min }
        return min + rng.nextInt(bound: span)
    }

    @discardableResult
    public mutating func cast(
        x: Float,
        y: Float,
        nowMs: Int64,
        currentHour: Int = 6,
        currentMinute: Int = 0,
        checkModeEnabled: Bool = false,
        canScheduleExactAlarms: Bool = true,
        rng: inout some FishingRandomGenerator
    ) -> [FishingUIEvent] {
        var events: [FishingUIEvent] = []

        if !tackle.isComplete {
            state = .missingTackleHold
            holdStateFlag = false
            let missing = tackle.missingComponentNames().joined(separator: ", ").lowercased()
            events.append(.missingTackle(missing))
            return events
        }

        if checkModeEnabled && !canScheduleExactAlarms {
            state = .alarmPermissionHold
            holdStateFlag = false
            events.append(.exactAlarmPermissionRequired)
            return events
        }

        guard !isCatchTimeLocked, bobber == nil else {
            return events
        }
        guard y > horizonMinY else {
            return events
        }

        castBeginTimeMs = nowMs
        castActiveFlag = 1
        lastCastMetadata = CastSessionMetadata(
            beginTimeMs: nowMs,
            beginHour: currentHour,
            beginMinute: currentMinute,
            bobberX: x,
            bobberY: y
        )

        var newBobber = BobberState(
            x: x,
            y: y,
            ripplesEnabled: animationsEnabled,
            bitmapWidth: bobberBitmapWidth,
            bitmapHeight: bobberBitmapHeight
        )
        if animationsEnabled {
            newBobber.addCastRipple(enabled: true)
        }
        bobber = newBobber

        var newLine = FishingLineGeometry()
        newLine.startCastAnimation()
        lineGeometry = newLine

        let depthOffset = newBobber.y - Float(viewHeight / 5) - Float(bobberBitmapHeight)
        let depthBonusSeconds = Int((depthOffset * 20.0) / waterVerticalSpan)
        let randomSeconds = rng.nextInt(bound: 50)
        let totalWaitSeconds = Int64(depthBonusSeconds) + 15 + Int64(randomSeconds)
        scheduledBiteTimeMs = nowMs + (totalWaitSeconds * 1000)
        state = .waitingForBite

        return events
    }

    public mutating func setPulled(_ pulled: Bool) {
        isPulled = pulled
        isPreHookBobbing = false
        if state == .fishFight {
            lineGeometry?.setPulled(pulled)
        }
    }

    /// Steps one visual canvas frame (`GameView$a` 60ms render loop: `D0.a.k(Canvas)` bounds clamping & ripple
    /// expansion + `D0.b.d(Canvas)` cast line animation & tautness curve) and persists the mutated structs.
    /// If `displayBobberPosition` is supplied (e.g. interpolated between 200ms physics ticks), the returned
    /// line curve attaches to that display coordinate while preserving the authoritative `self.bobber` state.
    @discardableResult
    public mutating func stepVisualFrame(
        stepRipplesAndCast: Bool = true,
        displayBobberPosition: Point2D? = nil,
        rng: inout some FishingRandomGenerator
    ) -> QuadraticBezierCurve? {
        guard var currentBobber = bobber else {
            return nil
        }
        if stepRipplesAndCast {
            currentBobber.clampAndStep(
                canvasWidth: viewWidth,
                canvasHeight: viewHeight,
                rng: &rng
            )
            self.bobber = currentBobber
        }

        guard var currentLine = lineGeometry else {
            return nil
        }
        var bobberForLine = currentBobber
        if let displayPos = displayBobberPosition {
            bobberForLine.x = displayPos.x
            bobberForLine.y = displayPos.y
        }
        let curve = currentLine.stepAndBuildCurve(
            rod: rodSprite,
            bobber: bobberForLine,
            jitterRandom: rng.nextFloat()
        )
        if stepRipplesAndCast {
            self.lineGeometry = currentLine
        }
        return curve
    }

    @discardableResult
    public mutating func stepTick(
        nowMs: Int64,
        checkModeEnabled: Bool = false,
        spDateMs: Int64 = 0,
        fishnetCount: Int = 0,
        overflowFcount: Int = 0,
        rng: inout some FishingRandomGenerator
    ) -> [FishingUIEvent] {
        var events: [FishingUIEvent] = []

        switch state {
        case .idle:
            break

        case .waitingForBite:
            isPreHookBobbing = true
            if nowMs > scheduledBiteTimeMs {
                if castActiveFlag == 1 && spDateMs > 0 {
                    let wakeDelayMs = spDateMs - castBeginTimeMs
                    let maxAllowedMs: Int64 = checkModeEnabled ? 11000 : 20000
                    if wakeDelayMs > maxAllowedMs || wakeDelayMs < 0 {
                        castActiveFlag = 0
                        events.append(.biteTriggered)
                        events.append(.missedBiteDuringSleep)
                        events.append(contentsOf: resetToIdle())
                        return events
                    }
                }
                events.append(contentsOf: selectFishAndRollWeight(nowMs: nowMs, rng: &rng))
                castActiveFlag = 0
            }

        case .fishFight:
            if bobber != nil {
                stepFightPhysics(
                    nowMs: nowMs,
                    fishnetCount: fishnetCount,
                    overflowFcount: overflowFcount,
                    rng: &rng
                )
                events.append(.tensionChanged(tension))
            }

        case .fishCaught:
            if let caught = lastCaughtFish {
                events.append(.fishCaught(caught))
            }
            events.append(contentsOf: resetToIdle())

        case .missingTackleHold:
            if !holdStateFlag {
                state = .idle
                holdStateFlag = false
            }

        case .lineBroken:
            events.append(.lineBroken)
            events.append(contentsOf: resetToIdle())

        case .fishEscaped:
            events.append(.fishEscaped)
            events.append(contentsOf: resetToIdle())

        case .rodBroken:
            events.append(.rodBroken)
            events.append(contentsOf: resetToIdle())

        case .coilBroken:
            events.append(.coilBroken)
            events.append(contentsOf: resetToIdle())

        case .alarmPermissionHold:
            if !holdStateFlag {
                state = .idle
                holdStateFlag = false
            }
        }

        return events
    }

    @discardableResult
    public mutating func selectFishAndRollWeight(
        nowMs: Int64,
        rng: inout some FishingRandomGenerator
    ) -> [FishingUIEvent] {
        var events: [FishingUIEvent] = []
        guard let userBait = tackle.userBait else { return events }

        let baitIndex0Based = userBait.bait.id - 1
        obfuscationMultiplier = Self.randomInclusive(min: 2, max: 10, rng: &rng)

        let activeTimeFactors = pondData.factors(for: timeOfDay)
        var didSelectFish = false

        outerLoop: for slot in 0..<pondData.activeBaitIndices0Based.count {
            if pondData.activeBaitIndices0Based[slot] == baitIndex0Based {
                guard slot < pondData.catchableFishByBaitSlot.count,
                      slot < activeTimeFactors.count else { continue }
                let slotCatches = pondData.catchableFishByBaitSlot[slot]
                let slotFactors = activeTimeFactors[slot]

                for fishIdx in slotCatches {
                    for factor in slotFactors {
                        if factor.fishIndex0Based == fishIdx {
                            let roll = rng.nextInt(bound: 100)
                            if roll < factor.probabilityPercent {
                                obfuscatedFishIndex = fishIdx * obfuscationMultiplier
                                didSelectFish = true
                                break outerLoop
                            }
                        }
                    }
                }
            }
        }

        guard didSelectFish else {
            return events
        }

        let fishId1Based = (obfuscatedFishIndex / obfuscationMultiplier) + 1
        var controller = FishBehaviorController()
        if let species = fishCatalogById1Based[fishId1Based], species.md5Valid {
            controller.configure(
                strength: species.strength,
                stamina: species.stamina,
                intelligence: species.intelligence,
                aggression: species.aggression
            )
        } else {
            let s = 8 + rng.nextInt(bound: 3)
            let st = 8 + rng.nextInt(bound: 3)
            let intel = 8 + rng.nextInt(bound: 3)
            let agg = 8 + rng.nextInt(bound: 3)
            controller.configure(strength: s, stamina: st, intelligence: intel, aggression: agg)
        }
        fishController = controller
        events.append(.biteTriggered)

        let selectedFishIdx0Based = obfuscatedFishIndex / obfuscationMultiplier
        let currentBobberY = bobber?.y ?? (horizonMinY + 10.0)

        for slot in 0..<pondData.activeBaitIndices0Based.count {
            if pondData.activeBaitIndices0Based[slot] == baitIndex0Based {
                for weightEntry in pondData.fishWeightRanges {
                    if weightEntry.fishIndex0Based == selectedFishIdx0Based {
                        let roll = rng.nextInt(bound: balanceTables.weightBracketBoundary(at: 13))
                        let minW = weightEntry.minWeightGrams
                        let maxW = weightEntry.maxWeightGrams
                        let range = maxW - minW

                        let v10 = currentBobberY - Float(viewHeight / 5) - Float(bobberBitmapHeight)
                        let v3Water = waterVerticalSpan
                        let v3 = Int(((v3Water - v10) / v3Water) * 10.0 + 1.0)

                        let g0 = balanceTables.weightBracketBoundary(at: 0)
                        let g1 = balanceTables.weightBracketBoundary(at: 1)
                        let g2 = balanceTables.weightBracketBoundary(at: 2)
                        let g3 = balanceTables.weightBracketBoundary(at: 3)
                        let g4 = balanceTables.weightBracketBoundary(at: 4)
                        let g5 = balanceTables.weightBracketBoundary(at: 5)
                        let g6 = balanceTables.weightBracketBoundary(at: 6)
                        let g7 = balanceTables.weightBracketBoundary(at: 7)
                        let g8 = balanceTables.weightBracketBoundary(at: 8)
                        let g9 = balanceTables.weightBracketBoundary(at: 9)
                        let g10 = balanceTables.weightBracketBoundary(at: 10)
                        let g11 = balanceTables.weightBracketBoundary(at: 11)
                        let g12 = balanceTables.weightBracketBoundary(at: 12)

                        if (roll >= g0 && roll <= g1) || (roll >= g2 && roll <= g3) || (roll >= g4 && roll <= g5) {
                            let rolledW: Int
                            if v3 < 4 {
                                rolledW = Self.randomInclusive(
                                    min: minW,
                                    max: minW + (range * 40) / 100,
                                    rng: &rng
                                )
                            } else {
                                rolledW = Self.randomInclusive(
                                    min: minW,
                                    max: minW + ((v3 + 40) * range) / 100,
                                    rng: &rng
                                )
                            }
                            obfuscatedWeightGrams = rolledW * obfuscationMultiplier
                        }

                        if (roll >= g6 && roll < g7) || (roll > g8 && roll < g9) {
                            let rolledW: Int
                            if v3 < 4 {
                                rolledW = Self.randomInclusive(
                                    min: minW + (range * 40) / 100,
                                    max: minW + (range * 60) / 100,
                                    rng: &rng
                                )
                            } else {
                                rolledW = Self.randomInclusive(
                                    min: minW + ((v3 + 40) * range) / 100,
                                    max: minW + ((v3 + 60) * range) / 100,
                                    rng: &rng
                                )
                            }
                            obfuscatedWeightGrams = rolledW * obfuscationMultiplier
                        }

                        if roll > g10 && roll < g11 {
                            let rolledW: Int
                            if v3 < 4 {
                                rolledW = Self.randomInclusive(
                                    min: minW + (range * 60) / 100,
                                    max: minW + (range * 80) / 100,
                                    rng: &rng
                                )
                            } else {
                                rolledW = Self.randomInclusive(
                                    min: minW + ((v3 + 60) * range) / 100,
                                    max: minW + ((v3 + 80) * range) / 100,
                                    rng: &rng
                                )
                            }
                            obfuscatedWeightGrams = rolledW * obfuscationMultiplier
                        }

                        if roll > g12 {
                            let rolledW = Self.randomInclusive(
                                min: minW + (range * 80) / 100,
                                max: maxW,
                                rng: &rng
                            )
                            obfuscatedWeightGrams = rolledW * obfuscationMultiplier
                        }
                    }
                }
            }
        }

        computeEscapeParameters()
        bobber?.switchToBiteSprite()
        biteStartTimeMs = nowMs
        state = .fishFight
        lineGeometry?.setPulled(true)

        return events
    }

    public mutating func computeEscapeParameters() {
        if let userHook = tackle.userHook {
            let hookIdx = max(0, min(userHook.hook.id - 1, BalanceTables.coilInitialStrengths.count - 1))
            hookEscapeBonus = balanceTables.coilInitialStrengthOrHookBonus(at: hookIdx)
        }

        guard let userRod = tackle.userRod else { return }
        let rodIdx = max(0, min(userRod.rod.id - 1, BalanceTables.fishingRodWeightsKg.count - 1))
        let rodMaxKg = Double(balanceTables.rodMaxWeightKg(at: rodIdx))
        let ratio = activeFishWeightKg / rodMaxKg

        if ratio <= 0.25 {
            rodRatioEscapeBase = balanceTables.fightTensionParameter(at: 0)
        } else if ratio <= 0.50 {
            rodRatioEscapeBase = balanceTables.fightTensionParameter(at: 1)
        } else if ratio <= 0.75 {
            rodRatioEscapeBase = balanceTables.fightTensionParameter(at: 2)
        } else if ratio <= 1.00 {
            rodRatioEscapeBase = balanceTables.fightTensionParameter(at: 3)
        } else {
            rodRatioEscapeBase = balanceTables.fightTensionParameter(at: 4)
        }
    }

    public mutating func stepFightPhysics(
        nowMs: Int64,
        fishnetCount: Int = 0,
        overflowFcount: Int = 0,
        rng: inout some FishingRandomGenerator
    ) {
        guard let userRod = tackle.userRod else { return }
        let rod = userRod.rod

        stepStaminaDrain()
        stepBobberMovement(rod: rod, nowMs: nowMs, rng: &rng)
        stepTensionLoad(rod: rod, nowMs: nowMs, rng: &rng)

        if checkInactivityTimeout(nowMs: nowMs) {
            return
        }
        if checkRandomHookSlip(rng: &rng) {
            return
        }
        if !checkHookWeightLimit() {
            return
        }
        if !checkCoilWeightLimit() {
            return
        }
        if !checkLineWeightLimit() {
            return
        }
        if checkCriticalTensionOverload(
            rod: rod,
            fishnetCount: fishnetCount,
            overflowFcount: overflowFcount
        ) {
            return
        }

        guard isPulled, let currentBobber = bobber else { return }
        let bobberBottomY = currentBobber.y + Float(currentBobber.bitmapHeight / 2)
        if bobberBottomY >= Float(viewHeight) {
            let baitIdx = (tackle.userBait?.bait.id ?? 1) - 1
            let weightGrams = activeFishWeightGrams
            let fishId1Based = (obfuscatedFishIndex / obfuscationMultiplier) + 1
            let species = fishCatalogById1Based[fishId1Based] ?? FishSpecies(
                id: fishId1Based,
                unitWeight: 100,
                unitPrice: 10,
                strength: 1,
                stamina: 1,
                intelligence: 1,
                aggression: 1
            )
            let rodIdx = max(0, min(rod.id - 1, BalanceTables.fishingRodWeightsKg.count - 1))
            let rodRefWeightKg = balanceTables.rodMaxWeightKg(at: rodIdx)

            lastCaughtFish = CaughtUserFish(
                fish: species,
                weightGrams: weightGrams,
                pondIndex: pondData.pondIndex,
                baitIndex: baitIdx,
                rodWeightKg: rodRefWeightKg,
                catchTimeMs: nowMs
            )
            idleReleaseStartTimeMs = 0
            consumeBait()
            applyRodWear(fishnetCount: fishnetCount, overflowFcount: overflowFcount)
            applyCoilWear(fishnetCount: fishnetCount, overflowFcount: overflowFcount)
            state = .fishCaught
        }
    }

    public mutating func stepStaminaDrain() {
        guard isPulled else { return }
        let drain = (tension / 50) + 1
        fishController?.drainStamina(drain)
    }

    public static func clampVerticalScale(_ scale: Float) -> Float {
        scale > 5.0 ? 5.0 : scale
    }

    public mutating func stepBobberMovement(
        rod: FishingRodSpec,
        nowMs: Int64,
        rng: inout some FishingRandomGenerator
    ) {
        guard var currentBobber = bobber else { return }
        var x = currentBobber.x
        var y = currentBobber.y
        let rawScaleY = Float(Double(viewHeight) / 326.0)
        let scaleY = Self.clampVerticalScale(rawScaleY)

        let parity = (biteStartTimeMs / 1000) % 2
        let expPower: Int
        if parity == 0 {
            expPower = rng.nextInt(bound: 5)
        } else {
            expPower = rng.nextInt(bound: 5) + 1
        }
        let sign: Double = (expPower % 2 == 0) ? 1.0 : -1.0
        let randFloatX = Double(rng.nextFloat())
        x = Float(Double(x) + sign * randFloatX * 4.0)

        if fishController == nil {
            var fallback = FishBehaviorController()
            fallback.configure(
                strength: 9 + rng.nextInt(bound: 2),
                stamina: 9 + rng.nextInt(bound: 2),
                intelligence: 9 + rng.nextInt(bound: 2),
                aggression: 9 + rng.nextInt(bound: 2)
            )
            fishController = fallback
            tension += 30
            return
        }

        if var ctrl = fishController, ctrl.shouldEvadeHorizontally(rng: &rng) {
            let centerX = Float(viewWidth / 2)
            let deltaX = Float(ctrl.intelligenceValue) * 0.05
            if x < centerX {
                x -= deltaX
            } else {
                x += deltaX
            }
            fishController = ctrl
        }

        if isPreHookBobbing {
            let dy = Float(bobbingDirectionSign) * rng.nextFloat() * 3.0
            y += dy
            bobbingDirectionSign *= -1
        } else if isPulled {
            if var ctrl = fishController {
                if ctrl.exhaustedFlag {
                    y += 4.5 * scaleY * rng.nextFloat()
                } else if ctrl.trySurge(nowMs: nowMs, rng: &rng) {
                    fishController = ctrl
                    y += 2.4 * scaleY * rng.nextFloat()
                } else {
                    fishController = ctrl
                    let pullFactor = max(
                        Float(0.4),
                        Float(1.0)
                            - Float(ctrl.strengthValue) * Float(0.02)
                            - Float(ctrl.aggressionValue) * Float(0.01)
                            - Float(ctrl.intelligenceValue) * Float(0.005)
                    )
                    y += (4.0 * pullFactor) * scaleY * rng.nextFloat()
                }
            }
        } else {
            if var ctrl = fishController {
                if ctrl.exhaustedFlag {
                    y += -2.0 * scaleY * rng.nextFloat()
                } else if ctrl.trySurge(nowMs: nowMs, rng: &rng) {
                    let surgeMult = ctrl.surgeSpeedMultiplier
                    fishController = ctrl
                    y += (-4.0 * surgeMult) * scaleY * rng.nextFloat()
                } else {
                    fishController = ctrl
                    y += -3.0 * scaleY * rng.nextFloat()
                }
            }
        }

        currentBobber.x = x
        currentBobber.y = y
        if animationsEnabled {
            currentBobber.addBiteRipple(enabled: true)
        }
        bobber = currentBobber
    }

    public mutating func stepTensionLoad(
        rod: FishingRodSpec,
        nowMs: Int64,
        rng: inout some FishingRandomGenerator
    ) {
        let rodIdx = max(0, min(rod.id - 1, BalanceTables.fishingRodWeightsKg.count - 1))
        let rodMaxKg = Double(balanceTables.rodMaxWeightKg(at: rodIdx))
        let v0 = (activeFishWeightKg / rodMaxKg) * 10.0

        var v2: Double = 1.0
        if var ctrl = fishController {
            let strTerm = Double(ctrl.strengthValue) * 0.02 + 0.9
            let aggTerm = Double(ctrl.aggressionValue) * 0.04 + 0.8
            var v4 = strTerm * aggTerm

            if ctrl.trySurge(nowMs: nowMs, rng: &rng) {
                let surgeBoost = Double(Float(ctrl.aggressionValue) * 0.1 + 1.0) * 1.3
                v4 *= surgeBoost
            }

            if ctrl.intelligenceValue > 6 {
                if !ctrl.trySurge(nowMs: nowMs, rng: &rng) {
                    v4 *= 0.95
                }
            }

            v2 = v4
            if ctrl.exhaustedFlag {
                v2 *= 0.7
            }
            fishController = ctrl
        }

        if isPulled {
            let delta = Int(v0 * v2) + 1
            tension += delta
        } else {
            let delta = Int(v0 * v2) + 2
            tension -= delta
        }

        if tension < 0 {
            tension = 0
        }
        if tension > 250 {
            tension = 250
        }

        rodSprite.updateFrame(forTension: tension)
    }

    public mutating func checkInactivityTimeout(nowMs: Int64) -> Bool {
        if isPulled {
            idleReleaseStartTimeMs = 0
        }
        if idleReleaseStartTimeMs == 0 {
            idleReleaseStartTimeMs = nowMs
        }
        if !isPulled && (nowMs - idleReleaseStartTimeMs) > 20000 {
            consumeBait()
            state = .fishEscaped
            idleReleaseStartTimeMs = 0
            return true
        }
        return false
    }

    public mutating func checkRandomHookSlip(
        rng: inout some FishingRandomGenerator
    ) -> Bool {
        guard isPulled else { return false }
        let baseSum = hookEscapeBonus + rodRatioEscapeBase
        let v2 = 3 * baseSum

        var mult: Float = 1.0
        if let ctrl = fishController {
            let strFactor = 1.0 - Float(ctrl.strengthValue) * 0.02
            let aggFactor = 1.0 - Float(ctrl.aggressionValue) * 0.01
            let intFactor = 1.0 - Float(ctrl.intelligenceValue) * 0.035
            mult = strFactor * aggFactor * intFactor
            if ctrl.exhaustedFlag {
                mult *= 1.25
            }
            mult = min(mult, 1.5)
            mult = max(Float(0.3), mult)
        }

        let bound = max(800, Int(Float(v2) * mult))
        let roll = rng.nextInt(bound: bound)
        return roll == 1
    }

    public mutating func checkHookWeightLimit() -> Bool {
        guard isPulled, let userHook = tackle.userHook else { return true }
        let hookIdx = max(0, min(userHook.hook.id - 1, BalanceTables.hookMaxFishWeightsKg.count - 1))
        let maxHookKg = Double(balanceTables.hookMaxFishWeightKg(at: hookIdx))
        if activeFishWeightKg > maxHookKg {
            consumeHook()
            consumeBait()
            state = .fishEscaped
            return false
        }
        return true
    }

    public mutating func checkCoilWeightLimit() -> Bool {
        guard isPulled, let userCoil = tackle.userCoil else { return true }
        let coilIdx = max(0, min(userCoil.coil.id - 1, BalanceTables.coilMaxFishWeightsKg.count - 1))
        let maxCoilKg = Double(balanceTables.coilMaxFishWeightKg(at: coilIdx))
        if activeFishWeightKg > maxCoilKg {
            tackle.userCoil = nil
            state = .coilBroken
            return false
        }
        return true
    }

    public mutating func checkLineWeightLimit() -> Bool {
        guard isPulled, let userLine = tackle.userLine else { return true }
        let lineIdx = max(0, min(userLine.line.id - 1, BalanceTables.fishingLineWeightsKg.count - 1))
        let maxLineKg = Double(balanceTables.lineMaxWeightKg(at: lineIdx))
        if activeFishWeightKg > maxLineKg {
            consumeBait()
            consumeHook()
            shortenLineOnBreak()
            state = .lineBroken
            return false
        }
        return true
    }

    public mutating func checkCriticalTensionOverload(
        rod: FishingRodSpec,
        fishnetCount: Int = 0,
        overflowFcount: Int = 0
    ) -> Bool {
        guard isPulled, tension >= 225, let userLine = tackle.userLine else {
            return false
        }
        let lineIdx = max(0, min(userLine.line.id - 1, BalanceTables.fishingLineWeightsKg.count - 1))
        let rodIdx = max(0, min(rod.id - 1, BalanceTables.fishingRodWeightsKg.count - 1))
        let lineMaxKg = balanceTables.lineMaxWeightKg(at: lineIdx)
        let rodMaxKg = balanceTables.rodMaxWeightKg(at: rodIdx)

        if lineMaxKg > rodMaxKg {
            tackle.userRod = nil
            state = .rodBroken
        } else {
            state = .lineBroken
        }

        consumeBait()
        consumeHook()
        shortenLineOnBreak()
        applyCoilWear(fishnetCount: fishnetCount, overflowFcount: overflowFcount)
        return true
    }

    public mutating func consumeBait() {
        guard var baitItem = tackle.userBait else { return }
        baitItem.amount -= 1
        if baitItem.amount > 0 {
            tackle.userBait = baitItem
        } else {
            tackle.userBait = nil
        }
    }

    public mutating func consumeHook() {
        guard var hookItem = tackle.userHook else { return }
        hookItem.amount -= 1
        if hookItem.amount > 0 {
            tackle.userHook = hookItem
        } else {
            tackle.userHook = nil
        }
    }

    public mutating func shortenLineOnBreak() {
        guard var lineItem = tackle.userLine else { return }
        lineItem.length -= 10
        if lineItem.length > 0 {
            tackle.userLine = lineItem
        } else {
            tackle.userLine = nil
        }
    }

    public mutating func applyCoilWear(
        fishnetCount: Int,
        overflowFcount: Int = 0
    ) {
        guard var coilItem = tackle.userCoil else { return }
        var v1 = fishnetCount
        if fishnetCount >= 50 {
            v1 += overflowFcount
        }

        let bearings = coilItem.coil.bearingCount
        if bearings == 1 || bearings == 2 {
            coilItem.strength -= 1
        } else if (bearings == 3 || bearings == 4) && ((v1 / 2) * 2 == v1) {
            coilItem.strength -= 1
        } else if (bearings == 5 || bearings == 6) && ((v1 / 3) * 3 == v1) {
            coilItem.strength -= 1
        } else if bearings == 7 && ((v1 / 4) * 4 == v1) {
            coilItem.strength -= 1
        } else if bearings == 8 && ((v1 / 5) * 5 == v1) {
            coilItem.strength -= 1
        } else if bearings == 9 && ((v1 / 6) * 6 == v1) {
            coilItem.strength -= 1
        } else if bearings == 10 && ((v1 / 7) * 7 == v1) {
            coilItem.strength -= 1
        }

        if coilItem.strength > 0 {
            tackle.userCoil = coilItem
        } else {
            tackle.userCoil = nil
        }
    }

    public mutating func applyRodWear(
        fishnetCount: Int,
        overflowFcount: Int = 0
    ) {
        guard var rodItem = tackle.userRod else { return }
        let rod = rodItem.rod
        let rodIdx = max(0, min(rod.id - 1, BalanceTables.fishingRodWeightsKg.count - 1))
        let refMaxKg = balanceTables.rodMaxWeightKg(at: rodIdx)

        if activeFishWeightKg > Double(refMaxKg) {
            rodItem.strength -= 10
        } else {
            var v3 = fishnetCount
            if fishnetCount >= 50 {
                v3 += overflowFcount
            }

            if ((v3 / 2) * 2 == v3) && refMaxKg <= 179 {
                rodItem.strength -= 1
            } else if ((v3 / 3) * 3 == v3) && rod.weight == balanceTables.rodMaxWeightKg(at: 10) {
                rodItem.strength -= 1
            } else if ((v3 / 4) * 4 == v3) && (rod.weight == balanceTables.rodMaxWeightKg(at: 11) || rod.weight == balanceTables.rodMaxWeightKg(at: 12)) {
                rodItem.strength -= 1
            } else if refMaxKg != rod.weight {
                rodItem.strength -= 1
            }
        }

        if rodItem.strength > 0 {
            tackle.userRod = rodItem
        } else {
            tackle.userRod = nil
        }
    }

    @discardableResult
    public mutating func resetToIdle() -> [FishingUIEvent] {
        bobber = nil
        lineGeometry = nil
        fishController = nil
        tension = 0
        idleReleaseStartTimeMs = 0
        state = .idle
        rodSprite.updateFrame(forTension: 0)
        return [.tensionChanged(0)]
    }
}