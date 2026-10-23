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


    // MARK: - 10. Phase 8: Network Crypto — Double-MD5 (`F0.h`), 10-Column Permutation (`F0.t.a`), `X-Fish-*` Headers & Cooldown

    func testNetworkCryptoDoubleMd5PermutationF0tAndXFishHeaders() throws {
        XCTAssertEqual(FishingNetworkCrypto.appSignConstant, "baa4d19bbde3a629d99fcd7e7d89beae")
        XCTAssertEqual(FishingHttpEndpoint.allCases.count, 17)

        let singleMd5 = FishingChecksum.md5("secret123")
        let expectedDoubleMd5 = FishingChecksum.md5(singleMd5)
        XCTAssertEqual(FishingNetworkCrypto.doubleMd5Password("secret123"), expectedDoubleMd5)
        XCTAssertEqual(expectedDoubleMd5.count, 32)

        let sampleFolp = "0:0:0:1250:0"
        let encodedPi0 = FishingNetworkCrypto.encodeF0t(sampleFolp, simpleBase64: false, permVariant: 0)
        XCTAssertEqual(encodedPi0.count % 10, 0)
        XCTAssertEqual(FishingNetworkCrypto.decodeF0t(encodedPi0, simpleBase64: false, permVariant: 0), sampleFolp)

        let encodedPi1 = FishingNetworkCrypto.encodeF0t("fisherman:ZWY=:0:baa4d19bbde3a629d99fcd7e7d89beae", simpleBase64: false, permVariant: 1)
        XCTAssertEqual(encodedPi1.count % 10, 0)
        XCTAssertEqual(
            FishingNetworkCrypto.decodeF0t(encodedPi1, simpleBase64: false, permVariant: 1),
            "fisherman:ZWY=:0:baa4d19bbde3a629d99fcd7e7d89beae"
        )

        let folpHeader = FishingNetworkCrypto.makeFishCatchFolpHeader(
            pondId0Based: 2,
            baitId0Based: 5,
            fishId0Based: 70,
            weightGrams: 4800,
            tourType: 1
        )
        XCTAssertEqual(FishingNetworkCrypto.decodeF0t(folpHeader, simpleBase64: false, permVariant: 0), "2:5:70:4800:1")

        XCTAssertEqual(FishingNetworkCrypto.truncateTournamentHeaderString("Турнир дня\r\n"), "Турнир дн")
        XCTAssertEqual(FishingNetworkCrypto.truncateTournamentHeaderString("Без переноса"), "Без переноса")

        var limiter = AuthAttemptLimiter()
        XCTAssertNil(limiter.registerAttempt(nowSeconds: 1000))
        XCTAssertNil(limiter.registerAttempt(nowSeconds: 1010))
        XCTAssertNil(limiter.registerAttempt(nowSeconds: 1020))
        let cooldown = limiter.registerAttempt(nowSeconds: 1050)
        XCTAssertEqual(cooldown, 150)
    }

    // MARK: - 11. Phase 8: 7-Section `auth.php` Profile & Inventory Restore (`C0.a.l`) + `X-Fish-Fach` / `X-Fish-Fqst`

    func testAuthProfile7SectionRestoreAndFachFqstHeaders() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)

        let authPayload = "4500;125000;kosrep:5:92|dasf:1900:100|not|not|not;terf:2:88|wectern:10:95|not|not|not;kosp:6:90|big fish:2150:100|not|not|not;2:1500:1|9:250000:1;1|1|0|0|1"

        let summary = try coordinator.restoreFromOnlineAuthResponse(
            authPayload,
            login: "angler_pro",
            password: "myPassword",
            nowMs: 5000
        )

        XCTAssertEqual(summary.experience, 4500)
        XCTAssertEqual(summary.categoryRank, 3)
        XCTAssertEqual(summary.balanceCoins, 125000)
        XCTAssertEqual(summary.restoredRodsCount, 2)
        XCTAssertEqual(summary.restoredCoilsCount, 2)
        XCTAssertEqual(summary.restoredLinesCount, 2)
        XCTAssertEqual(summary.restoredAchievementsCount, 2)
        XCTAssertEqual(summary.restoredQuestsCount, 5)

        XCTAssertEqual(coordinator.profile.login, "angler_pro")
        XCTAssertEqual(coordinator.profile.balance, 125000)
        XCTAssertEqual(coordinator.profile.category, 3)
        XCTAssertTrue(try coordinator.repository.verifyPlayerProfileIntegrity())

        let dasfSpec = try coordinator.catalog.loadFishingRodSpec(id: 13)
        XCTAssertEqual(dasfSpec?.weight, 1900)
        XCTAssertTrue(try coordinator.catalog.verifyDataSign(.fishingRods))
        XCTAssertTrue(try coordinator.catalog.verifyDataSign(.coils))
        XCTAssertTrue(try coordinator.catalog.verifyDataSign(.fishingLines))

        let fach = try coordinator.repository.buildFachHeader()
        XCTAssertTrue(fach.contains("2:1500:1|"))
        XCTAssertTrue(fach.contains("9:250000:1|"))

        let fqst = try coordinator.repository.buildFqstHeader()
        XCTAssertTrue(fqst.hasPrefix("1|1|0|0|1|"))
    }

    // MARK: - 12. Phase 8: 37-Field `online.php` CSV Parser (`MainActivity$d.c`)

    func testOnlineShop37FieldCsvUpdatesOnlineTackleAndDataSigns() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)

        let csv = "350,525,680,1900,100,150,250,8,9,10,80,120,200,600,810,2150,150,200,300,50,90,160,0,0,0,0,0,0,0,0,10,25,45,70,100,150,200,note=4"

        let snapshot = try coordinator.syncOnlineShopFromCSV(csv, nowMs: 2000)
        XCTAssertEqual(snapshot.pearlsBalance, 350)
        XCTAssertEqual(snapshot.onlineRodWeightsKg, [525, 680, 1900])
        XCTAssertEqual(snapshot.onlineCoilBearings, [8, 9, 10])
        XCTAssertEqual(snapshot.onlineLineWeightsKg, [600, 810, 2150])
        XCTAssertEqual(snapshot.onlineLineStockLengthsM, [150, 200, 300])
        XCTAssertEqual(snapshot.couponPearlPrices, [10, 25, 45, 70, 100, 150, 200])
        XCTAssertEqual(snapshot.unreadNotesCount, 4)

        XCTAssertEqual(try coordinator.catalog.loadFishingRodSpec(id: 11)?.weight, 525)
        XCTAssertEqual(try coordinator.catalog.loadFishingRodSpec(id: 13)?.weight, 1900)
        XCTAssertEqual(try coordinator.catalog.loadCoilSpec(id: 10)?.bearingCount, 10)
        XCTAssertEqual(try coordinator.catalog.loadFishingLineSpec(id: 16)?.weight, 2150)
        XCTAssertEqual(try coordinator.catalog.loadFishingLineSpec(id: 16)?.stockLength, 300)
        XCTAssertTrue(try coordinator.catalog.verifyDataSign(.fishingRods))
        XCTAssertTrue(try coordinator.catalog.verifyDataSign(.coils))
        XCTAssertTrue(try coordinator.catalog.verifyDataSign(.fishingLines))
    }

    // MARK: - 13. Phase 8: Java Object Stream (`0xACED0005`) Binary Serialization & `Handler.selector`

    func testJavaObjectStreamBinaryCodecAndChatProtocolSelector() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)

        let openMess = ChatProtocolSelector.makeOpenHandshakeMess(
            userId: 42,
            login: "fisher42",
            pondRoom: 0,
            installationUuid: "00000000-0000-0000-0000-000000000000"
        )
        let openData = JavaObjectStreamCodec.encodeMess(openMess)
        let bytes = [UInt8](openData)
        XCTAssertEqual(bytes[0], 0xAC)
        XCTAssertEqual(bytes[1], 0xED)
        XCTAssertEqual(bytes[2], 0x00)
        XCTAssertEqual(bytes[3], 0x05)

        let decodedOpen = try JavaObjectStreamCodec.decodeMess(from: openData)
        XCTAssertEqual(decodedOpen, openMess)

        let sampleTour = ChatTourModel(
            active: 1,
            bait: 1,
            cond: 1500.0,
            fee: 500,
            feed: false,
            finish: 1_700_010_000_000,
            fish: 1,
            id: 77,
            leftToFinish: 1800,
            leftToStart: 0,
            pond: 0,
            reg: true,
            start: 1_700_000_000_000,
            vip: false,
            desc: "Поймать максимального карася",
            fond: "50 000 монет",
            title: "Кубок Кедрового острова",
            type: "max",
            users: ["fisher42", "champion"]
        )
        let serverUD = ChatServerUserData(lv: 12, money: 95000, prem: 1, rmoney: 250, xp: 45000)
        let initMess = ChatMess(
            fromID: -1,
            prem: 0,
            room: 0,
            from: "-1",
            object: .initObject(ChatInitObject(tours: [sampleTour], userData: serverUD)),
            text: "initialize",
            timeEpochMs: 1_700_000_005_000,
            to: "fisher42"
        )
        let initPacket = JavaObjectStreamCodec.encodeMess(initMess)
        let initOutcome = try coordinator.receiveChatStreamPacket(initPacket, currentUserId: 42)
        XCTAssertEqual(initOutcome, .initialized(ChatInitObject(tours: [sampleTour], userData: serverUD)))
        XCTAssertEqual(coordinator.onlineTours.count, 1)
        XCTAssertEqual(coordinator.onlineTours.first?.title, "Кубок Кедрового острова")

        let users: [ChatUserOnline] = [
            ChatUserOnline(frig: 0, id: 10, lv: 5, online: true, pond: 0, login: "pondPeer"),
            ChatUserOnline(frig: 1, id: 11, lv: 15, online: true, pond: 3, login: "bestFriend"),
            ChatUserOnline(frig: 2, id: 12, lv: 2, online: true, pond: 0, login: "spammer")
        ]
        let listMess = ChatMess(fromID: -1, room: 0, from: "-1", object: .userOnlineList(users), text: "getUserList3", to: "fisher42")
        let listPacket = JavaObjectStreamCodec.encodeMess(listMess)
        let listOutcome = try coordinator.receiveChatStreamPacket(listPacket, currentUserId: 42)
        if case .userListReceived(_, let partitioned) = listOutcome {
            XCTAssertEqual(partitioned.userPond.count, 2)
            XCTAssertEqual(partitioned.userFriends.map(\.login), ["bestFriend"])
            XCTAssertEqual(partitioned.userIgnore.map(\.login), ["spammer"])
        } else {
            XCTFail("Expected .userListReceived")
        }

        let bitMess = ChatMess(fromID: -1, room: 0, from: "-1", text: "bit", to: "fisher42")
        let bitOutcome = try coordinator.receiveChatStreamPacket(JavaObjectStreamCodec.encodeMess(bitMess), currentUserId: 42)
        if case .sendHeartbeatReply(let reply) = bitOutcome {
            XCTAssertEqual(reply.text, "bit")
            XCTAssertEqual(reply.to, "-1")
        } else {
            XCTFail("Expected .sendHeartbeatReply")
        }

        let sellFishMess = ChatMess(fromID: -1, room: 0, from: "-1", text: "sellFish", to: "fisher42")
        let sellOutcome = try coordinator.receiveChatStreamPacket(JavaObjectStreamCodec.encodeMess(sellFishMess), currentUserId: 42)
        XCTAssertEqual(sellOutcome, .unhandledSystemCommand("sellFish"))
    }

    // MARK: - 14. Phase 9: 5-Language Localization (`F0.g.b`) & Quest/Task Language Gate (`F0.o.b`)

    func testFiveLanguageLocalizationAndQuestLanguageGate() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)
        guard let pond0 = coordinator.availablePonds.first(where: { $0.id == 0 }) else {
            XCTFail("Expected Pond #0 in catalog")
            return
        }

        coordinator.setLanguage(.ru)
        XCTAssertEqual(coordinator.localeManager.pondName(for: pond0), "Кедровый остров")
        XCTAssertTrue(coordinator.localeManager.areQuestsAndTasksActive)

        coordinator.setLanguage(.en)
        XCTAssertEqual(coordinator.localeManager.pondName(for: pond0), "Cedar Island")
        XCTAssertEqual(coordinator.localeManager.tabTitle(for: .shop), "Shop")
        XCTAssertTrue(coordinator.localeManager.areQuestsAndTasksActive)

        coordinator.setLanguage(.de)
        XCTAssertEqual(coordinator.localeManager.pondName(for: pond0), "Zederinsel")
        XCTAssertEqual(coordinator.localeManager.missingTackleComponentName(.rod), "Angelrute")
        XCTAssertFalse(coordinator.localeManager.areQuestsAndTasksActive)

        coordinator.setLanguage(.es)
        XCTAssertEqual(coordinator.localeManager.pondName(for: pond0), "Isla de Cedro")
        XCTAssertFalse(coordinator.localeManager.areQuestsAndTasksActive)

        coordinator.setLanguage(.pt)
        XCTAssertEqual(coordinator.localeManager.pondName(for: pond0), "Ilha do Cedro")
        XCTAssertFalse(coordinator.localeManager.areQuestsAndTasksActive)
    }

    // MARK: - 15. Phase 9: Audio, SFX (`F0.p`), Ambient Day/Night Tracks (`pondsm.txt`) & `FishingService` Anti-Cheat Intervals

    func testAudioHapticsAndFishingServiceAntiCheatIntervals() throws {
        var controller = FishingAudioAndHapticsController()
        controller.syncAmbientTrack(pondIndex: 0, hour: 6)
        XCTAssertEqual(controller.activeAmbientTrack?.isDaylightTrack, true)
        XCTAssertEqual(controller.activeAmbientTrack?.trackIndex, 0)
        XCTAssertEqual(controller.activeAmbientTrack?.resourceName, "sounds/fon/pond0_day.ogg")

        controller.syncAmbientTrack(pondIndex: 0, hour: 23)
        XCTAssertEqual(controller.activeAmbientTrack?.isDaylightTrack, false)
        XCTAssertEqual(controller.activeAmbientTrack?.trackIndex, 1)
        XCTAssertEqual(controller.activeAmbientTrack?.resourceName, "sounds/fon/pond0_night.ogg")

        controller.recordCastScheduledBite(beginTimeMs: 100_000)
        XCTAssertEqual(controller.playedSoundEffects, [.castBobber])

        controller.handleBiteSignalWhat0(nowMs: 104_000)
        XCTAssertEqual(controller.biteAlarmTriggerCount, 1)
        XCTAssertEqual(controller.vibrationTriggerCount, 1)

        controller.setReelLooping(true)
        XCTAssertTrue(controller.isReelLoopPlaying)

        controller.handleCatchSignalWhat1(nowMs: 108_500)
        XCTAssertFalse(controller.isReelLoopPlaying)
        XCTAssertEqual(controller.lastAntiCheatCatchDeltaMs, -8500)
        XCTAssertEqual(controller.lastAntiCheatBiteDelaySeconds, 4)
    }

    // MARK: - 16. Phase 9: Server Rewards (`reaward.php`, `OnlineGameActivity$f.a`) Atomic SQLite Claim

    func testServerRewardsClaimUpdatesCoinsExpAndInventoryAtomically() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)
        let initialBalance = coordinator.profile.balance

        let rewardResponse = "--notes=2,1=5000,2=1600,3=11,4=8,5=14,6=2,7=3"
        let summary = try coordinator.claimServerRewards(rewardResponse, nowMs: 3000)

        XCTAssertEqual(summary.unreadNotesCount, 2)
        XCTAssertEqual(summary.coinsAdded, 5000)
        XCTAssertEqual(summary.experienceAdded, 1600)
        XCTAssertEqual(summary.newBalance, initialBalance + 5000)
        XCTAssertEqual(summary.newExperience, 1600)
        XCTAssertEqual(summary.newCategoryRank, 2)
        XCTAssertEqual(summary.grantedItems.count, 7)

        XCTAssertTrue(try coordinator.repository.verifyPlayerProfileIntegrity())
        XCTAssertTrue(coordinator.ownedRods.contains(where: { $0.rod.id == 11 }))
        XCTAssertTrue(coordinator.ownedCoils.contains(where: { $0.coil.id == 8 }))
        XCTAssertTrue(coordinator.ownedLines.contains(where: { $0.line.id == 14 }))
        XCTAssertTrue(coordinator.ownedHooks.contains(where: { $0.hook.id == 2 }))
        XCTAssertTrue(coordinator.ownedBaits.contains(where: { $0.bait.id == 3 }))
    }

    // MARK: - 17. Phase 9: Fisherman Contracts (`user_task` / `user_task_data`), `tour_results.php` & `update.php` Manifests

    func testUserTaskContractProgressionAndTournamentAndUpdateManifests() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1000)

        let contract = try coordinator.assignFishermanContract(
            taskType: 1,
            targetFishId: 1,
            targetBaitId: 1,
            requiredCount: 2,
            requiredWeightGrams: 400,
            bonusExperience: 600,
            nowMs: 2000
        )
        XCTAssertEqual(contract.made, 0)
        XCTAssertEqual(coordinator.activeContract?.requiredCount, 2)

        guard let karas = coordinator.fishCatalogById[1] else {
            XCTFail("Missing fish #1")
            return
        }
        let catch1 = CaughtUserFish(
            fish: karas,
            weightGrams: 500,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 3,
            catchTimeMs: 2500
        )
        let bonus1 = try coordinator.repository.evaluateUserTaskOnCatch(catch1, isLanguageSupported: true, nowMs: 2500)
        XCTAssertEqual(bonus1, 0)
        XCTAssertEqual(try coordinator.repository.loadActiveUserTaskContract()?.currentCount, 1)

        let catch2 = CaughtUserFish(
            fish: karas,
            weightGrams: 650,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 3,
            catchTimeMs: 3000
        )
        let bonus2 = try coordinator.repository.evaluateUserTaskOnCatch(catch2, isLanguageSupported: true, nowMs: 3000)
        XCTAssertEqual(bonus2, 600)
        XCTAssertEqual(try coordinator.repository.loadActiveUserTaskContract()?.made, 1)
        XCTAssertEqual(try coordinator.repository.loadPlayerProfile().experience, 600)
        XCTAssertEqual(try coordinator.repository.loadPlayerProfile().category, 1)

        let tourSnap = FishingNetworkCrypto.parseTournamentResultsResponse(
            "--regin=1,left=900,start=0,users=angler1|angler2,tour=Кубок дня\r\n"
        )
        XCTAssertTrue(tourSnap.isRegistered)
        XCTAssertEqual(tourSnap.secondsLeft, 900)
        XCTAssertEqual(tourSnap.participants, ["angler1", "angler2"])
        XCTAssertEqual(tourSnap.tournamentHeader, "Кубок дн")

        let manifestRaw = """
        1,sounds,sound,ru,1700000000,4500000,sounds/sounds.zip
        2,pond0,fon,all,1700000100,1250000,fon/pond0/bg_1.png
        """
        let packs = FishingNetworkCrypto.parseAssetPacksManifest(manifestRaw)
        XCTAssertEqual(packs.count, 2)
        XCTAssertEqual(packs[0].baseName, "sounds")
        XCTAssertEqual(packs[1].relativePath, "fon/pond0/bg_1.png")
    }

    // MARK: - 18. Phase 10: HTTP Request Builders for `auth.php`, `fish.php`, `buyballs.php`, `registration_app.php` & `tt.php`

    func testHttpEndpointRequestBuildersAndPlainPasswordRegistrationRule() throws {
        let uuid = "00000000-0000-0000-0000-000000000000"
        let authReq = FishingHttpRequestBuilder.makeAuthProfileRequest(
            login: "fisher1",
            password: "secret",
            installationUuid: uuid
        )
        XCTAssertEqual(authReq.httpMethod, "GET")
        XCTAssertEqual(authReq.url?.absoluteString, "http://fish-mob.ru/fff/auth.php")
        XCTAssertEqual(authReq.value(forHTTPHeaderField: "X-Fish-Login"), "fisher1")
        XCTAssertEqual(authReq.value(forHTTPHeaderField: "X-Fish-Uuid"), FishingChecksum.md5(uuid))

        let regNew = FishingHttpRequestBuilder.makeAccountRegistrationOrRecoveryRequest(
            loginOrEmail: "new_player",
            plainPassword: "myPass123",
            languageCode: "ru",
            categoryRank: 3
        )
        XCTAssertEqual(regNew.value(forHTTPHeaderField: "X-Fish-Pass"), "myPass123")
        XCTAssertEqual(regNew.value(forHTTPHeaderField: "X-Fish-KeyReg"), "367sdy672fdg243dtr671dfuReg")
        XCTAssertEqual(regNew.value(forHTTPHeaderField: "X-Fish-regType"), "0")

        let regRecover = FishingHttpRequestBuilder.makeAccountRegistrationOrRecoveryRequest(
            loginOrEmail: "player@example.com",
            plainPassword: "myPass123"
        )
        XCTAssertEqual(regRecover.value(forHTTPHeaderField: "X-Fish-regType"), "1")

        let pearlsReq = FishingHttpRequestBuilder.makeBuyPearlsRequest(
            login: "fisher1",
            password: "secret",
            pearlsAmount: 100,
            receiptSignData: "{}",
            receiptSignature: "sig123"
        )
        XCTAssertEqual(pearlsReq.value(forHTTPHeaderField: "X-Fish-KeyBuy"), "367sdy672fdg243dtr671dfu")
        XCTAssertEqual(pearlsReq.value(forHTTPHeaderField: "X-Fish-Balls"), "100")
        XCTAssertEqual(pearlsReq.value(forHTTPHeaderField: "X-Fish-Pass"), FishingNetworkCrypto.doubleMd5Password("secret"))
    }

    // MARK: - 19. Phase 10: `auth_chat.php`, `fish.php`, `top.php` & `rek.php` Response Parsers

    func testChatAuthFishCatchTopPlayersAndWorldRecordsParsers() throws {
        XCTAssertEqual(
            FishingOnlineResponseParser.parseChatAuthResponse("1:48291"),
            .authenticated(userId: 48291)
        )
        XCTAssertEqual(
            FishingOnlineResponseParser.parseChatAuthResponse("3:Account banned"),
            .rejected(statusCode: 3, message: "Account banned")
        )

        XCTAssertEqual(FishingOnlineResponseParser.parseFishCatchUploadResponse("status=1000"), .accepted)
        XCTAssertEqual(FishingOnlineResponseParser.parseFishCatchUploadResponse("status=1100"), .newWorldRecord)
        XCTAssertEqual(FishingOnlineResponseParser.parseFishCatchUploadResponse("status=2000"), .rejected(statusCode: 2000))

        let topRaw = """
        1:master_angler:75000000:45
        2:river_king:12000000:35
        """
        let topList = FishingOnlineResponseParser.parseTopPlayersResponse(topRaw)
        XCTAssertEqual(topList.count, 2)
        XCTAssertEqual(topList[0].login, "master_angler")
        XCTAssertEqual(topList[0].categoryRank, 45)

        let rekRaw = """
        Карась:2950:master_angler
        Щука:24800:river_king
        """
        let records = FishingOnlineResponseParser.parseWorldSpeciesRecordsResponse(rekRaw)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[1].fishName, "Щука")
        XCTAssertEqual(records[1].weightGrams, 24800)
    }

    // MARK: - 20. Phase 10: Sleep-Mode Clock Catch-Up (`GameActivity.onResume`) & `tourType` Resolution

    func testSleepModeClockCatchUpAndTournamentTypeResolution() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            initialHour: 21,
            initialMinute: 50,
            nowMs: 1_000_000
        )
        XCTAssertTrue(coordinator.dayNightLighting.isDayLight)
        XCTAssertEqual(coordinator.audioHaptics.activeAmbientTrack?.isDaylightTrack, true)

        coordinator.buyAndEquipStarterKit(nowMs: 999_000)
        var rng = ScriptedFishingRandom(ints: [10])
        coordinator.castAt(x: 640, y: 500, nowMs: 1_000_000, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)

        // Advance 20 game minutes (40,000 ms) during sleep -> crosses 22:00 into night
        let caughtUp = coordinator.handleResumeAfterSleep(
            beginTimeMs: 1_000_000,
            beginHour: 21,
            beginMinute: 50,
            nowMs: 1_040_000
        )
        XCTAssertTrue(caughtUp)
        XCTAssertEqual(coordinator.gameClock.hour, 22)
        XCTAssertEqual(coordinator.gameClock.minute, 10)
        XCTAssertFalse(coordinator.dayNightLighting.isDayLight)
        XCTAssertEqual(coordinator.audioHaptics.activeAmbientTrack?.isDaylightTrack, false)

        XCTAssertEqual(coordinator.resolveCurrentCatchTourType(hasActiveIndividualTour: false), 0)
        XCTAssertEqual(coordinator.resolveCurrentCatchTourType(hasActiveIndividualTour: true), 1)
    }

    // MARK: - 21. Phase 10: iOS 18+ `NSAppTransportSecurity` Configuration Verification

    func testIOSAppTransportSecurityConfiguration() throws {
        let ats = FishingIOSAppConfiguration.appTransportSecurityPlistDictionary
        XCTAssertEqual(ats["NSAllowsArbitraryLoads"] as? Bool, false)
        let domains = ats["NSExceptionDomains"] as? [String: [String: Bool]]
        XCTAssertEqual(domains?["fish-mob.ru"]?["NSExceptionAllowsInsecureHTTPLoads"], true)
        XCTAssertEqual(domains?["chat.fish-mob.ru"]?["NSExceptionAllowsInsecureHTTPLoads"], true)
        XCTAssertEqual(FishingIOSAppConfiguration.chatServerPort, 15701)
    }

    // MARK: - 22. Phase 11: Persistent `INSTALLATION` UUID (`F0.e.a`) & App Bundle `GameData` Bootstrapper

    func testInstallationUuidPersistenceAndAppBundleDatabaseBootstrap() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FishingAppBootstrapTest_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 1. First call creates `<tempDir>/INSTALLATION` with a valid 36-char UUID v4
        let uuid1 = try AppBundleDatabaseBootstrapper.resolveOrCreateInstallationUuid(in: tempDir)
        XCTAssertEqual(uuid1.count, 36)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("INSTALLATION").path))

        // 2. Second call returns the exact same persisted UUID (`F0.e.a` idempotency)
        let uuid2 = try AppBundleDatabaseBootstrapper.resolveOrCreateInstallationUuid(in: tempDir)
        XCTAssertEqual(uuid1, uuid2)

        // 3. Locate bundled `App/Resources/GameData` or fallback `FISHING_DATA_DIR` / `data/`
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var candidateDirs: [URL] = [
            packageRoot.appendingPathComponent("App/Resources/GameData", isDirectory: true),
            packageRoot.appendingPathComponent("data", isDirectory: true)
        ]
        if let envDir = ProcessInfo.processInfo.environment["FISHING_DATA_DIR"], !envDir.isEmpty {
            candidateDirs.insert(URL(fileURLWithPath: envDir, isDirectory: true), at: 1)
        }
        guard let gameDataURL = candidateDirs.first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("fishes.json").path)
        }) else {
            return
        }

        let resolvedURL = AppBundleDatabaseBootstrapper.resolveBundledGameDataURL(explicitURL: gameDataURL)
        XCTAssertEqual(resolvedURL?.standardizedFileURL, gameDataURL.standardizedFileURL)

        // 4. Verify bundled TGA normal maps (`wNoise3.tga` & `wNoise4.tga`) load and decode cleanly (`256 x 128`, 24-bit BGR)
        let n3Data = TgaTextureLoader.loadBundledNoiseTGA(named: "wNoise3.tga", gameDataDirectoryURL: gameDataURL)
            ?? TgaTextureLoader.makeProceduralWaveNoiseTGA(seedPhase: 0)
        let n4Data = TgaTextureLoader.loadBundledNoiseTGA(named: "wNoise4.tga", gameDataDirectoryURL: gameDataURL)
            ?? TgaTextureLoader.makeProceduralWaveNoiseTGA(seedPhase: 37)
        do {
            let decoded3 = try TgaTextureLoader.decode(data: n3Data)
            let decoded4 = try TgaTextureLoader.decode(data: n4Data)
            XCTAssertEqual(decoded3.width, 256)
            XCTAssertEqual(decoded3.height, 128)
            XCTAssertEqual(decoded3.bitsPerPixel, 24)
            XCTAssertEqual(decoded4.width, 256)
            XCTAssertEqual(decoded4.height, 128)
        }

        // 5. First launch bootstraps all 141 fish species, 15 ponds, 14 achievements, and 44 quests into `fishing2.db`
        let coordinator1 = try AppBundleDatabaseBootstrapper.bootstrapAppCoordinator(
            appSupportDirectory: tempDir,
            bundledGameDataURL: gameDataURL,
            nowMs: 1_700_000_000_000
        )
        XCTAssertEqual(coordinator1.fishCatalogById.count, 141)
        XCTAssertEqual(coordinator1.availablePonds.count, 15)
        XCTAssertEqual(coordinator1.achievements.count, 14)
        XCTAssertEqual(coordinator1.quests.count, 44)
        let dbPath = tempDir.appendingPathComponent("fishing2.db").path
        XCTAssertTrue(AppBundleDatabaseBootstrapper.isFullReferenceCatalogPopulated(atDatabasePath: dbPath))

        // Mutate player state (buy starter kit) and verify second launch preserves state without re-importing
        coordinator1.buyAndEquipStarterKit(nowMs: 1_700_000_001_000)
        let balanceAfterStarterKit = coordinator1.profile.balance
        XCTAssertLessThan(balanceAfterStarterKit, 500)

        let coordinator2 = try AppBundleDatabaseBootstrapper.bootstrapAppCoordinator(
            appSupportDirectory: tempDir,
            bundledGameDataURL: gameDataURL,
            nowMs: 1_700_000_002_000
        )
        XCTAssertEqual(coordinator2.profile.balance, balanceAfterStarterKit)
        XCTAssertEqual(coordinator2.ownedRods.count, 1)
        XCTAssertEqual(coordinator2.fishCatalogById.count, 141)
        // 6. Verify OriginalGameAssetsLoader decodes bundled pond_1_big.png and top-25% sky slice when Drawables/ are present
        if OriginalGameAssetsLoader.resolveDrawableURL(named: "pond_1_big", gameDataDirectoryURL: gameDataURL) != nil {
            let pondDecoded = OriginalGameAssetsLoader.decodePondAndTopQuarterSkyRGBA(
                pondIndex0Based: 0,
                gameDataDirectoryURL: gameDataURL
            )
            XCTAssertNotNil(pondDecoded)
            if let pondDecoded {
                XCTAssertGreaterThan(pondDecoded.width, 0)
                XCTAssertGreaterThan(pondDecoded.height, 0)
                XCTAssertEqual(pondDecoded.skyHeight, max(1, pondDecoded.height / 4))
                XCTAssertEqual(pondDecoded.skyRGBA.count, pondDecoded.width * pondDecoded.skyHeight * 4)
            }
        }
    }
}
