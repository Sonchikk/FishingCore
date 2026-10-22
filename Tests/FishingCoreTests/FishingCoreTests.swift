import XCTest
@testable import FishingCore

final class FishingCoreTests: XCTestCase {

    private func makeTestPond() -> PondSimulationData {
        PondSimulationData(
            pondIndex: 0,
            activeBaitIndices0Based: [0, 5],
            catchableFishByBaitSlot: [
                [0, 1],
                [2]
            ],
            fishWeightRanges: [
                PondFishWeightRange(fishIndex0Based: 0, minWeightGrams: 100, maxWeightGrams: 1100),
                PondFishWeightRange(fishIndex0Based: 1, minWeightGrams: 500, maxWeightGrams: 2500),
                PondFishWeightRange(fishIndex0Based: 2, minWeightGrams: 1000, maxWeightGrams: 5000)
            ],
            factorsMorning: [
                [
                    PondFishBiteFactor(fishIndex0Based: 0, probabilityPercent: 60),
                    PondFishBiteFactor(fishIndex0Based: 1, probabilityPercent: 80)
                ],
                [
                    PondFishBiteFactor(fishIndex0Based: 2, probabilityPercent: 50)
                ]
            ],
            factorsAfternoon: [
                [PondFishBiteFactor(fishIndex0Based: 0, probabilityPercent: 40)],
                []
            ],
            factorsEvening: [
                [PondFishBiteFactor(fishIndex0Based: 0, probabilityPercent: 70)],
                []
            ],
            factorsNight: [
                [PondFishBiteFactor(fishIndex0Based: 1, probabilityPercent: 30)],
                []
            ]
        )
    }

    private func makeTestCatalog() -> [Int: FishSpecies] {
        [
            1: FishSpecies(
                id: 1,
                name: "Карась",
                unitWeight: 500,
                unitPrice: 55,
                strength: 2,
                stamina: 3,
                intelligence: 2,
                aggression: 1,
                md5Valid: true
            ),
            2: FishSpecies(
                id: 2,
                name: "Щука",
                unitWeight: 2000,
                unitPrice: 306,
                strength: 7,
                stamina: 6,
                intelligence: 8,
                aggression: 8,
                md5Valid: true
            ),
            3: FishSpecies(
                id: 3,
                name: "Сом (Tampered MD5)",
                unitWeight: 5000,
                unitPrice: 500,
                strength: 1,
                stamina: 1,
                intelligence: 1,
                aggression: 1,
                md5Valid: false
            )
        ]
    }

    private func makeDefaultTackle(
        rodId: Int = 5,
        lineId: Int = 5,
        coilId: Int = 4,
        hookId: Int = 4,
        baitId: Int = 1
    ) -> AssembledTackle {
        let bt = BalanceTables()
        return AssembledTackle(
            userRod: UserRodItem(
                rod: FishingRodSpec(id: rodId, weight: bt.rodMaxWeightKg(at: rodId - 1)),
                strength: 100
            ),
            userLine: UserLineItem(
                line: FishingLineSpec(id: lineId, weight: bt.lineMaxWeightKg(at: lineId - 1)),
                length: 100
            ),
            userCoil: UserCoilItem(
                coil: CoilSpec(id: coilId, bearingCount: BalanceTables.coilBearingCounts[coilId - 1]),
                strength: 100
            ),
            userHook: UserHookItem(
                hook: HookSpec(id: hookId),
                amount: 10
            ),
            userBait: UserBaitItem(
                bait: BaitSpec(id: baitId),
                amount: 20
            )
        )
    }

    func testBalanceTablesCountsAndBoundaries() {
        let bt = BalanceTables()
        XCTAssertEqual(BalanceTables.fishReferenceWeightsGrams.count, 141)
        XCTAssertEqual(BalanceTables.coilBearingCounts.count, 10)
        XCTAssertEqual(BalanceTables.coilInitialStrengths.count, 10)
        XCTAssertEqual(BalanceTables.fightTensionParameters, [2000, 1600, 1200, 800, 400, 10000])
        XCTAssertEqual(BalanceTables.hookMaxFishWeightsKg.count, 10)
        XCTAssertEqual(BalanceTables.coilMaxFishWeightsKg.count, 10)
        XCTAssertEqual(BalanceTables.weightRollBracketsPermille, [50, 350, 400, 700, 730, 995, 0, 50, 350, 400, 700, 730, 995, 1000])
        XCTAssertEqual(bt.rankCount(), 45)
        XCTAssertEqual(bt.rankExpThreshold(at: 0), 500)
        XCTAssertEqual(bt.rankExpThreshold(at: 44), 170_000_000)
        XCTAssertEqual(BalanceTables.fishingRodWeightsKg.count, 13)
        XCTAssertEqual(BalanceTables.fishingLineWeightsKg.count, 16)
        XCTAssertEqual(BalanceTables.achievementThresholds.count, 14)
    }

    func testCastValidationAndBiteDelayFormula() {
        var rng = ScriptedFishingRandom(ints: [25])
        var incompleteTackle = makeDefaultTackle()
        incompleteTackle.userRod = nil
        incompleteTackle.userHook = nil

        var sm = FishingStateMachine(
            viewWidth: 1280,
            viewHeight: 800,
            bobberBitmapWidth: 24,
            bobberBitmapHeight: 40,
            pondData: makeTestPond(),
            fishCatalogById1Based: makeTestCatalog(),
            tackle: incompleteTackle
        )

        let missingEvents = sm.cast(x: 400, y: 500, nowMs: 1000, rng: &rng)
        XCTAssertEqual(sm.state, .missingTackleHold)
        XCTAssertEqual(missingEvents, [.missingTackle("удочка, крючок")])

        sm.stepTick(nowMs: 1100, rng: &rng)
        XCTAssertEqual(sm.state, .idle)

        sm.tackle = makeDefaultTackle()

        let aboveHorizonEvents = sm.cast(x: 400, y: 200.0, nowMs: 2000, rng: &rng)
        XCTAssertTrue(aboveHorizonEvents.isEmpty)
        XCTAssertEqual(sm.state, .idle)
        XCTAssertNil(sm.bobber)

        let validEvents = sm.cast(x: 400, y: 500.0, nowMs: 2000, rng: &rng)
        XCTAssertTrue(validEvents.isEmpty)
        XCTAssertEqual(sm.state, .waitingForBite)
        XCTAssertEqual(sm.scheduledBiteTimeMs, 52_000)
        XCTAssertEqual(sm.bobber?.ripples.count, 1)
    }

    func testFishSelectionAndWeightRollBrackets() {
        var rng = ScriptedFishingRandom(ints: [0, 3, 45, 998, 150])
        var sm = FishingStateMachine(
            viewWidth: 1280,
            viewHeight: 800,
            bobberBitmapWidth: 24,
            bobberBitmapHeight: 40,
            pondData: makeTestPond(),
            timeOfDay: .morning,
            fishCatalogById1Based: makeTestCatalog(),
            tackle: makeDefaultTackle()
        )

        sm.cast(x: 640, y: 350, nowMs: 1000, rng: &rng)
        let biteEvents = sm.stepTick(nowMs: 100_000, rng: &rng)

        XCTAssertEqual(sm.state, .fishFight)
        XCTAssertEqual(biteEvents, [.biteTriggered])
        XCTAssertEqual(sm.obfuscationMultiplier, 5)
        XCTAssertEqual(sm.activeFishId1Based, 1)
        XCTAssertEqual(sm.obfuscatedWeightGrams, 5250)
        XCTAssertEqual(sm.activeFishWeightGrams, 1050)
        XCTAssertEqual(sm.hookEscapeBonus, 1500)
        XCTAssertEqual(sm.rodRatioEscapeBase, 2000)
    }

    func testOriginalBugHookSlipReturnsEarlyWithoutSettingEscapedState() {
        var rng = ScriptedFishingRandom(ints: [0, 2, 10, 100, 50], defaultFloat: 0.5)
        var sm = FishingStateMachine(
            pondData: makeTestPond(),
            fishCatalogById1Based: makeTestCatalog(),
            tackle: makeDefaultTackle()
        )
        sm.cast(x: 640, y: 785, nowMs: 1000, rng: &rng)
        sm.stepTick(nowMs: 100_000, rng: &rng)
        XCTAssertEqual(sm.state, .fishFight)

        sm.setPulled(true)
        var slipRng = ScriptedFishingRandom(ints: [0, 99, 99, 99, 1], defaultFloat: 1.0)
        sm.stepFightPhysics(nowMs: 100_200, rng: &slipRng)

        XCTAssertEqual(sm.state, .fishFight)
        XCTAssertEqual(sm.tackle.userBait?.amount, 20)
    }

    func testOriginalBugDoubleSurgeCheckInTensionLoadForHighIntelligenceFish() {
        var rng = ScriptedFishingRandom(ints: [0, 2, 70, 50, 100, 500])
        var sm = FishingStateMachine(
            pondData: makeTestPond(),
            fishCatalogById1Based: makeTestCatalog(),
            tackle: makeDefaultTackle()
        )
        sm.cast(x: 640, y: 500, nowMs: 1000, rng: &rng)
        sm.stepTick(nowMs: 100_000, rng: &rng)
        XCTAssertEqual(sm.activeFishId1Based, 2)
        XCTAssertEqual(sm.fishController?.intelligenceValue, 8)

        sm.setPulled(true)
        var tensionRng = ScriptedFishingRandom(ints: [20])
        let rod = sm.tackle.userRod!.rod
        sm.stepTensionLoad(rod: rod, nowMs: 105_000, rng: &tensionRng)

        XCTAssertEqual(sm.fishController?.lastSurgeTimeMs, 105_000)
        XCTAssertGreaterThan(sm.tension, 0)
    }

    func testCriticalTensionOverloadBreaksRodWhenLineIsStrongerThanRod() {
        var rng = ScriptedFishingRandom(ints: [0, 2, 10, 100, 50])
        var sm = FishingStateMachine(
            pondData: makeTestPond(),
            fishCatalogById1Based: makeTestCatalog(),
            tackle: makeDefaultTackle(rodId: 1, lineId: 5, coilId: 4, hookId: 4, baitId: 1)
        )
        sm.cast(x: 640, y: 500, nowMs: 1000, rng: &rng)
        sm.stepTick(nowMs: 100_000, rng: &rng)
        sm.setPulled(true)

        let rod = sm.tackle.userRod!.rod
        for step in 1...40 {
            var stepRng = ScriptedFishingRandom(ints: [99, 99])
            sm.stepTensionLoad(rod: rod, nowMs: 100_000 + Int64(step * 200), rng: &stepRng)
        }
        XCTAssertGreaterThanOrEqual(sm.tension, 225)

        let didOverload = sm.checkCriticalTensionOverload(rod: rod, fishnetCount: 1)
        XCTAssertTrue(didOverload)
        XCTAssertEqual(sm.state, .rodBroken)
        XCTAssertNil(sm.tackle.userRod)
        XCTAssertEqual(sm.tackle.userLine?.length, 90)
        XCTAssertEqual(sm.tackle.userHook?.amount, 9)
        XCTAssertEqual(sm.tackle.userBait?.amount, 19)
    }

    func testRodBendFramesAndBezierLineGeometry() {
        XCTAssertEqual(RodSpriteState.frameIndex(forTension: 0), 0)
        XCTAssertEqual(RodSpriteState.frameIndex(forTension: 15), 1)
        XCTAssertEqual(RodSpriteState.frameIndex(forTension: 185), 10)
        XCTAssertEqual(RodSpriteState.frameIndex(forTension: 215), 15)
        XCTAssertEqual(RodSpriteState.frameIndex(forTension: 250), 15)

        let rod = RodSpriteState(viewWidth: 1280, viewHeight: 800, rodWidth: 200, rodHeight: 400)
        let bobber = BobberState(x: 500, y: 400, ripplesEnabled: true)
        var line = FishingLineGeometry()
        line.startCastAnimation()

        let castCurve = line.stepAndBuildCurve(rod: rod, bobber: bobber)
        XCTAssertEqual(castCurve.alpha, 0)
        XCTAssertTrue(line.isCastAnimating)
    }

    func testProgressionAndLuckyWeightChecks() {
        XCTAssertTrue(ProgressionCalculator.isLuckyWeight25(898))
        XCTAssertFalse(ProgressionCalculator.isLuckyWeight25(900))

        XCTAssertTrue(ProgressionCalculator.isRepdigitWeight(7777))
        XCTAssertFalse(ProgressionCalculator.isRepdigitWeight(777))

        XCTAssertTrue(ProgressionCalculator.isCleanerTrashCatch(fishId1Based: 71))
        XCTAssertTrue(ProgressionCalculator.isCleanerTrashCatch(fishId1Based: 112))
        XCTAssertFalse(ProgressionCalculator.isCleanerTrashCatch(fishId1Based: 1))

        let xp = ProgressionCalculator.experienceGained(fishId1Based: 1, weightGrams: 1230)
        XCTAssertEqual(xp, 11)
        XCTAssertEqual(ProgressionCalculator.categoryForExperience(499), 0)
        XCTAssertEqual(ProgressionCalculator.categoryForExperience(500), 1)
        XCTAssertEqual(ProgressionCalculator.categoryForExperience(170_000_000), 45)
    }

    func testGameClockTimerAndCouponCountdown() {
        var clock = GameClockTimer(hour: 23, minute: 59)
        var coupon: Int? = 2
        clock.tickOneGameMinute(isPaidPond: true, activeCouponRemainingTicks: &coupon)
        XCTAssertEqual(clock.hour, 0)
        XCTAssertEqual(clock.minute, 0)
        XCTAssertEqual(coupon, 1)

        clock.tickOneGameMinute(isPaidPond: true, activeCouponRemainingTicks: &coupon)
        XCTAssertNil(coupon)
    }
}