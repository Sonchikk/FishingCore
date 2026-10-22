import XCTest
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

        // 1. Buy and equip starter kit (100 rod + 100 line + 100 coil + 100 hook + 30 bait = 430 coins -> 70 left)
        coordinator.buyAndEquipStarterKit(nowMs: 2000)
        XCTAssertEqual(coordinator.profile.balance, 70)
        XCTAssertTrue(coordinator.assembledTackle.isComplete)
        XCTAssertEqual(coordinator.assembledTackle.userBait?.amount, 30)

        // 2. Cast near the bottom of the screen (`y = 778`) so the fish is pulled onto shore quickly
        // RNG sequence:
        // 0   -> cast randomSeconds
        // 2   -> obfuscationMultiplier = 2 + 2 = 4
        // 10  -> fishIdx 0 ('Карась', prob 65%) roll: 10 < 65 (hook Карась, id=1)
        // 100 -> weight bracket roll [50..350]
        // 450 -> weight offset -> 50 + 450 = 500g ('Карась', unitWeight=500, unitPrice=55 -> 55 coins)
        var rng = ScriptedFishingRandom(
            ints: [0, 2, 10, 100, 450],
            defaultInt: 99,
            defaultFloat: 1.0
        )
        coordinator.castAt(x: 640, y: 778, nowMs: 3000, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)

        // 3. Advance past scheduledBiteTimeMs to trigger bite (`.fishFight`)
        let biteTime = coordinator.stateMachine.scheduledBiteTimeMs + 100
        coordinator.stepSimulationTick(nowMs: biteTime, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .fishFight)
        XCTAssertEqual(coordinator.stateMachine.activeFishId1Based, 1)

        // 4. Press reel button (`setReelPulled(true)`) and step fight physics until fish is landed (`y + halfH >= 800`)
        coordinator.setReelPulled(true)
        var fightRng = ScriptedFishingRandom(
            ints: [0, 99, 99, 99, 0],
            defaultInt: 99,
            defaultFloat: 1.0
        )
        coordinator.stepSimulationTick(nowMs: biteTime + 200, rng: &fightRng)

        // 5. Verify state machine returned to `.idle`, catch dialog alert is shown, and SQLite persisted everything
        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertEqual(coordinator.fishnetEntries.count, 1)
        XCTAssertEqual(coordinator.fishnetEntries.first?.caughtFish.fish.id, 1)
        XCTAssertEqual(coordinator.assembledTackle.userBait?.amount, 29) // 1 bait consumed
        XCTAssertGreaterThan(coordinator.profile.experience, 0)

        if case .catchDialog(let caught, let result, _, _, _) = coordinator.activeAlert {
            XCTAssertEqual(caught.fish.id, 1)
            XCTAssertTrue(result.storedInFishnet)
            XCTAssertTrue(result.isNewPersonalRecord)
        } else {
            XCTFail("Expected .catchDialog alert, got \(String(describing: coordinator.activeAlert))")
        }

        // 6. Sell all fish from fishnet and verify coin balance increase
        let balanceBeforeSale = coordinator.profile.balance
        let expectedCoins = coordinator.fishnetEntries.first!.caughtFish.sellingPriceCoins
        coordinator.sellAllFishInFishnet(nowMs: biteTime + 1000)

        XCTAssertEqual(coordinator.fishnetEntries.count, 0)
        XCTAssertEqual(coordinator.profile.balance, balanceBeforeSale + expectedCoins)
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

        // Select Pond #1 ('Лесное озеро') where Pike ('Щука', id=5, up to 4500g = 4.5 kg) bites on worm
        coordinator.selectPond(pondIndex: 1)
        XCTAssertEqual(coordinator.selectedPondIndex, 1)

        // RNG sequence to hook a 4,000g (4.0 kg) Pike on a 3.0 kg starter line (`lineId = 1`, maxLineKg = 3.0):
        // 0   -> cast randomSeconds
        // 2   -> obfuscationMultiplier = 4
        // 80  -> skip fishIdx 0 ('Карась', prob 60%)
        // 10  -> hook fishIdx 4 ('Щука', prob 50%)
        // 998 -> top weight bracket (> 995 -> 80%..100% of 400..4500g = 3680..4500g)
        // 320 -> weight offset -> 3680 + 320 = 4000g (4.0 kg > 3.0 kg line limit!)
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

        // Pull reel -> 4.0 kg exceeds starter line limit (3.0 kg), triggering immediate `.lineBroken`
        coordinator.setReelPulled(true)
        var fightRng = ScriptedFishingRandom(ints: [0, 99, 99, 99, 0], defaultInt: 99, defaultFloat: 0.5)
        coordinator.stepSimulationTick(nowMs: biteTime + 200, rng: &fightRng)

        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertEqual(coordinator.activeAlert, .lineBroken)
        // Verify SQLite persisted -10m line (`100 -> 90`), -1 hook (`5 -> 4`), -1 bait (`30 -> 29`)
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
}
