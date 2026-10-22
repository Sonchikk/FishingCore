import XCTest
import simd
import Metal
@testable import FishingCore
@testable import FishingDatabase
@testable import FishingGameApp

@MainActor
final class FishingGameAppTests: XCTestCase {

    // MARK: - 1. App Bootstrap & Starter Catalog Initialization

    func testAppBootstrapInitializesNewPlayerAndStarterCatalog() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:")

        XCTAssertEqual(coordinator.profile.balance, 500)
        XCTAssertEqual(coordinator.profile.experience, 0)
        XCTAssertEqual(coordinator.profile.category, 0)
        XCTAssertFalse(coordinator.assembledTackle.isComplete)
        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertGreaterThanOrEqual(coordinator.availablePonds.count, 2)
        XCTAssertGreaterThanOrEqual(coordinator.catalogRods.count, 1)
        XCTAssertGreaterThanOrEqual(coordinator.catalogBaits.count, 1)
        XCTAssertEqual(coordinator.achievements.count, 14)
        XCTAssertGreaterThanOrEqual(coordinator.quests.count, 5)
    }

    // MARK: - 2. Cast Without Tackle Triggers Missing-Tackle Alert and Returns to Idle

    func testCastWithIncompleteTackleTriggersMissingTackleAlert() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:")
        var rng = ScriptedFishingRandom(ints: [10])

        coordinator.castAt(x: 640, y: 500, nowMs: 1000, rng: &rng)

        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertEqual(
            coordinator.activeAlert,
            .missingTackle(missingComponents: "удочка, леска, катушка, крючок, наживка")
        )
    }

    // MARK: - 3. Full End-to-End Integration: Starter Kit -> Cast -> Bite -> Fight -> Catch -> DB Record -> Sell

    func testBuyStarterKitEquipCastFightCatchAndSellFullLoop() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            viewWidth: 1280,
            viewHeight: 800,
            nowMs: 1000
        )

        coordinator.buyAndEquipStarterKit(nowMs: 2000)
        XCTAssertEqual(coordinator.profile.balance, 70)
        XCTAssertTrue(coordinator.assembledTackle.isComplete)
        XCTAssertEqual(coordinator.assembledTackle.userBait?.amount, 30)

        var rng = ScriptedFishingRandom(
            ints: [0, 2, 10, 100, 450],
            defaultInt: 99,
            defaultFloat: 1.0
        )
        coordinator.castAt(x: 640, y: 778, nowMs: 3000, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)

        let biteTime = coordinator.stateMachine.scheduledBiteTimeMs + 100
        coordinator.stepSimulationTick(nowMs: biteTime, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .fishFight)
        XCTAssertEqual(coordinator.stateMachine.activeFishId1Based, 1)

        coordinator.setReelPulled(true)
        var fightRng = ScriptedFishingRandom(
            ints: [0, 99, 99, 99, 0],
            defaultInt: 99,
            defaultFloat: 1.0
        )
        coordinator.stepSimulationTick(nowMs: biteTime + 200, rng: &fightRng)

        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertEqual(coordinator.fishnetEntries.count, 1)
        XCTAssertEqual(coordinator.fishnetEntries.first?.caughtFish.fish.id, 1)
        XCTAssertEqual(coordinator.assembledTackle.userBait?.amount, 29)
        XCTAssertGreaterThan(coordinator.profile.experience, 0)

        let ach2 = try coordinator.repository.loadAchievement(id: 2)
        XCTAssertEqual(ach2?.score, 1)
        let quest1 = coordinator.quests.first(where: { $0.id == 1 })
        XCTAssertNotEqual(quest1?.progressRes, "null")

        if case .catchDialog(let caught, let result, _, _, _) = coordinator.activeAlert {
            XCTAssertEqual(caught.fish.id, 1)
            XCTAssertTrue(result.storedInFishnet)
            XCTAssertTrue(result.isNewPersonalRecord)
        } else {
            XCTFail("Expected .catchDialog alert, got \(String(describing: coordinator.activeAlert))")
        }

        let balanceBeforeSale = coordinator.profile.balance
        let expectedCoins = coordinator.fishnetEntries.first!.caughtFish.sellingPriceCoins
        coordinator.sellAllFishInFishnet(nowMs: biteTime + 1000)

        XCTAssertEqual(coordinator.fishnetEntries.count, 0)
        XCTAssertEqual(coordinator.profile.balance, balanceBeforeSale + expectedCoins)
        let ach10 = try coordinator.repository.loadAchievement(id: 10)
        XCTAssertEqual(ach10?.score, balanceBeforeSale + expectedCoins)
    }

    // MARK: - 4. Tackle Breakage Persistence (Line Break Persists -10m Line, -1 Hook, -1 Bait in SQLite)

    func testFightLineBreakPersistsShortenedLineAndConsumedHookAndBaitInSQLite() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            viewWidth: 1280,
            viewHeight: 800,
            nowMs: 1000
        )
        coordinator.buyAndEquipStarterKit(nowMs: 2000)

        coordinator.selectPond(pondIndex: 1)
        XCTAssertEqual(coordinator.selectedPondIndex, 1)

        var rng = ScriptedFishingRandom(
            ints: [0, 2, 80, 10, 998, 320],
            defaultInt: 99,
            defaultFloat: 0.5
        )
        coordinator.castAt(x: 640, y: 500, nowMs: 3000, rng: &rng)
        let biteTime = coordinator.stateMachine.scheduledBiteTimeMs + 100
        coordinator.stepSimulationTick(nowMs: biteTime, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .fishFight)
        XCTAssertEqual(coordinator.stateMachine.activeFishWeightGrams, 4000)

        coordinator.setReelPulled(true)
        var fightRng = ScriptedFishingRandom(ints: [0, 99, 99, 99, 0], defaultInt: 99, defaultFloat: 0.5)
        coordinator.stepSimulationTick(nowMs: biteTime + 200, rng: &fightRng)

        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertEqual(coordinator.activeAlert, .lineBroken)
        XCTAssertEqual(coordinator.assembledTackle.userLine?.length, 90)
        XCTAssertEqual(coordinator.assembledTackle.userHook?.amount, 4)
        XCTAssertEqual(coordinator.assembledTackle.userBait?.amount, 29)
    }

    // MARK: - 5. Navigation Switching & Game Clock Day/Night Transitions

    func testNavigationAndGameClockDayNightTransition() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            initialHour: 21,
            initialMinute: 59
        )

        XCTAssertTrue(coordinator.dayNightLighting.isDayLight)
        XCTAssertEqual(coordinator.stateMachine.timeOfDay, .evening)

        coordinator.stepGameClockMinute()
        XCTAssertEqual(coordinator.gameClock.hour, 22)
        XCTAssertEqual(coordinator.gameClock.minute, 0)
        XCTAssertFalse(coordinator.dayNightLighting.isDayLight)
        XCTAssertEqual(coordinator.dayNightLighting.canvasColorFilterHex, 0xFF8888AA)

        for tab in AppNavigationTab.allCases {
            coordinator.selectedTab = tab
            XCTAssertEqual(coordinator.selectedTab, tab)
        }
    }

    // MARK: - 6. Phase 7: TGA 24-Bit BGR Texture Parser (`F0.s` — `TgaTextureLoader`)

    func testTgaTextureLoaderDecodes24BitBgrIntoRgbAndRgba() throws {
        let tgaData = TgaTextureLoader.makeProceduralWaveNoiseTGA(width: 256, height: 128, seedPhase: 0)
        XCTAssertEqual(tgaData.count, 18 + 256 * 128 * 3)

        let decoded = try TgaTextureLoader.decode(data: tgaData)
        XCTAssertEqual(decoded.width, 256)
        XCTAssertEqual(decoded.height, 128)
        XCTAssertEqual(decoded.bitsPerPixel, 24)
        XCTAssertEqual(decoded.rgbBytes.count, 256 * 128 * 3)
        XCTAssertEqual(decoded.rgbaBytes.count, 256 * 128 * 4)

        let rawBytes = [UInt8](tgaData)
        let b0 = rawBytes[18]
        let g0 = rawBytes[19]
        let r0 = rawBytes[20]
        XCTAssertEqual(decoded.rgbBytes[0], r0)
        XCTAssertEqual(decoded.rgbBytes[1], g0)
        XCTAssertEqual(decoded.rgbBytes[2], b0)
        XCTAssertEqual(decoded.rgbaBytes[3], 255)

        XCTAssertThrowsError(try TgaTextureLoader.decode(data: Data([0, 1, 2])))
    }

    // MARK: - 7. Phase 7: Water Shader Activation Policy, Shader Math & Metal Pipeline Compilation (`F0.n`)

    func testWaterShaderActivationPolicyAndShaderMathDayNightAndMslSource() throws {
        XCTAssertFalse(WaterShaderActivationPolicy.shouldActivate(pondBackgroundSetIndex: 0, waterShaderSettingEnabled: true))
        XCTAssertFalse(WaterShaderActivationPolicy.shouldActivate(pondBackgroundSetIndex: 1, waterShaderSettingEnabled: false))
        XCTAssertTrue(WaterShaderActivationPolicy.shouldActivate(pondBackgroundSetIndex: 1, waterShaderSettingEnabled: true))

        XCTAssertEqual(WaterShaderMath.stepPhaseOffset(0.0), 0.0005, accuracy: 1e-6)
        XCTAssertEqual(WaterShaderMath.stepPhaseOffset(0.9998), 0.0003, accuracy: 1e-6)

        let uvExtreme = WaterShaderMath.computeRefractedUV(
            texCoords: SIMD2<Float>(0.0, 1.0),
            ndcPosition: SIMD3<Float>(0.0, -1.0, 0.0),
            noise1Sample: SIMD4<Float>(1.0, -1.0, 0.5, 1.0),
            noise2Sample: SIMD4<Float>(1.0, -1.0, 0.5, 1.0)
        )
        XCTAssertGreaterThanOrEqual(uvExtreme.x, 0.01)
        XCTAssertLessThanOrEqual(uvExtreme.x, 0.99)
        XCTAssertGreaterThanOrEqual(uvExtreme.y, 0.01)
        XCTAssertLessThanOrEqual(uvExtreme.y, 0.99)

        let sample = SIMD4<Float>(0.8, 0.6, 0.5, 1.0)
        let dayColor = WaterShaderMath.applyBlitShaderColor(sample: sample, isDayLight: true)
        XCTAssertEqual(dayColor, SIMD4<Float>(0.8, 0.6, 0.5, 0.9))

        let nightColor = WaterShaderMath.applyBlitShaderColor(sample: sample, isDayLight: false)
        XCTAssertEqual(nightColor.x, 0.20, accuracy: 1e-5)
        XCTAssertEqual(nightColor.y, 0.15, accuracy: 1e-5)
        XCTAssertEqual(nightColor.z, 0.20, accuracy: 1e-5)
        XCTAssertEqual(nightColor.w, 0.90, accuracy: 1e-5)

        if let device = MTLCreateSystemDefaultDevice() {
            let renderer = WaterMetalRenderer(device: device)
            XCTAssertNotNil(renderer)
            XCTAssertEqual(renderer?.offscreenWaterTexture.width, 256)
            XCTAssertEqual(renderer?.offscreenWaterTexture.height, 512)
        }
    }

    // MARK: - 8. Phase 7: Achievements Engine (`F0.o.a`) — Lucky 25, Repdigit, Cleaner Trash, Trophy, Rod Break

    func testAchievementsEvaluateOnCatchRodBreakAndFishSaleWithObfuscation() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)

        let karas = coordinator.fishCatalogById[1]!
        let luckyCatch = CaughtUserFish(
            fish: karas,
            weightGrams: 898,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 3,
            catchTimeMs: 2000
        )
        try coordinator.repository.evaluateAchievementsOnCatch(luckyCatch, nowMs: 2000)

        let ach2 = try coordinator.repository.loadAchievement(id: 2)
        let ach7 = try coordinator.repository.loadAchievement(id: 7)
        let ach9 = try coordinator.repository.loadAchievement(id: 9)
        XCTAssertEqual(ach2?.score, 1)
        XCTAssertEqual(ach7?.score, 1)
        XCTAssertEqual(ach9?.score, 898)

        let tireFish = coordinator.fishCatalogById[71]!
        let tireCatch = CaughtUserFish(
            fish: tireFish,
            weightGrams: 1111,
            pondIndex: 8,
            baitIndex: 0,
            rodWeightKg: 3,
            catchTimeMs: 3000
        )
        try coordinator.repository.evaluateAchievementsOnCatch(tireCatch, nowMs: 3000)

        let ach8 = try coordinator.repository.loadAchievement(id: 8)
        let ach12 = try coordinator.repository.loadAchievement(id: 12)
        let ach9After = try coordinator.repository.loadAchievement(id: 9)
        XCTAssertEqual(ach8?.score, 1)
        XCTAssertEqual(ach12?.score, 1)
        XCTAssertEqual(ach9After?.score, 1111)

        for i in 1...30 {
            try coordinator.repository.updateAchievementProgress(
                achievementId: 3,
                valueOrDelta: 1,
                nowMs: Int64(4000 + i),
                obfuscationMultiplier: 7
            )
        }
        let ach3 = try coordinator.repository.loadAchievement(id: 3)
        XCTAssertEqual(ach3?.score, 30)
        XCTAssertEqual(ach3?.level, 1)
    }

    // MARK: - 9. Phase 7: Quests Engine (`F0.o.b`) — Cumulative Weight, Interval, and Language Filter

    func testQuestsEvaluateAcrossTypesAndLanguageFilter() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)
        let karas = coordinator.fishCatalogById[1]!

        let catch1 = CaughtUserFish(
            fish: karas,
            weightGrams: 5000,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 5,
            catchTimeMs: 2000
        )
        let skipped = try coordinator.repository.evaluateQuestsOnCatch(
            catch1,
            playerCategory: 0,
            tasksEnabled: true,
            languageCode: "de",
            nowMs: 2000
        )
        XCTAssertNil(skipped)

        let q1Step1 = try coordinator.repository.evaluateQuestsOnCatch(
            catch1,
            playerCategory: 0,
            tasksEnabled: true,
            languageCode: "ru",
            nowMs: 2100
        )
        XCTAssertEqual(q1Step1?.id, 1)
        XCTAssertEqual(q1Step1?.progressRes, "5000")
        XCTAssertEqual(q1Step1?.made, 0)

        let catch2 = CaughtUserFish(
            fish: karas,
            weightGrams: 16000,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 17,
            catchTimeMs: 2200
        )
        let q1Completed = try coordinator.repository.evaluateQuestsOnCatch(
            catch2,
            playerCategory: 0,
            tasksEnabled: true,
            languageCode: "ru",
            nowMs: 2200
        )
        XCTAssertEqual(q1Completed?.id, 1)
        XCTAssertEqual(q1Completed?.progressRes, "20000")
        XCTAssertEqual(q1Completed?.made, 1)

        let plotva = coordinator.fishCatalogById[3]!
        let inRangeCatch = CaughtUserFish(
            fish: plotva,
            weightGrams: 750,
            pondIndex: 0,
            baitIndex: 1,
            rodWeightKg: 3,
            catchTimeMs: 3000
        )
        let q2Step = try coordinator.repository.evaluateQuestsOnCatch(
            inRangeCatch,
            playerCategory: 0,
            tasksEnabled: true,
            languageCode: "en",
            nowMs: 3000
        )
        XCTAssertEqual(q2Step?.id, 2)
        XCTAssertEqual(q2Step?.progressRes, "1,0,0")
        XCTAssertEqual(q2Step?.made, 0)
    }
}
