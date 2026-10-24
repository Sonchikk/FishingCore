import XCTest
@testable import FishingCore
@testable import FishingDatabase
@testable import FishingGameApp

@MainActor
final class FishingGameAppTests: XCTestCase {

    // MARK: - 1. Coordinator Initialization & Starter Kit Assembly

    func testCoordinatorInitializationAndStarterKitAssembly() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            initialHour: 8,
            initialMinute: 30,
            nowMs: 1_700_000_000_000
        )

        XCTAssertEqual(coordinator.profile.balance, 500)
        XCTAssertEqual(coordinator.profile.category, 0)
        XCTAssertFalse(coordinator.assembledTackle.isComplete)
        XCTAssertTrue(coordinator.dayNightLighting.isDayLight)
        XCTAssertTrue(coordinator.isWaterShaderActive)

        coordinator.buyAndEquipStarterKit(nowMs: 1_700_000_001_000)

        XCTAssertTrue(coordinator.assembledTackle.isComplete)
        XCTAssertEqual(coordinator.ownedRods.count, 1)
        XCTAssertEqual(coordinator.ownedCoils.count, 1)
        XCTAssertEqual(coordinator.ownedLines.count, 1)
        XCTAssertEqual(coordinator.ownedHooks.count, 1)
        XCTAssertEqual(coordinator.ownedBaits.count, 1)
        XCTAssertLessThan(coordinator.profile.balance, 500)
    }

    // MARK: - 2. Cast With Missing Tackle Emits Modal Alert

    func testCastWithMissingTackleShowsAlertAndReturnsToIdle() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000
        )

        var rng = ScriptedFishingRandom(ints: [10])
        coordinator.castAt(x: 640, y: 500, nowMs: 1_700_000_002_000, rng: &rng)

        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        guard case .missingTackle(let missing) = coordinator.activeAlert else {
            XCTFail("Expected .missingTackle alert, got \(String(describing: coordinator.activeAlert))")
            return
        }
        XCTAssertTrue(missing.localizedCaseInsensitiveContains("удочка"))
    }

    // MARK: - 3. Full End-to-End Gameplay Loop (Cast -> Bite -> Fight -> Catch -> Sell)

    func testEndToEndCastBiteFightCatchAndSellInCoordinator() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            initialHour: 7,
            initialMinute: 0,
            viewWidth: 1280,
            viewHeight: 800,
            nowMs: 1_700_000_000_000
        )

        coordinator.buyAndEquipStarterKit(nowMs: 1_700_000_001_000)
        let balanceAfterKit = coordinator.profile.balance

        // 1. Cast near bottom so pull reel catches quickly
        // RNG sequence:
        // - 10  -> cast randomSeconds (bound 50)
        // - 3   -> obfuscationMultiplier offset (2 + 3 = 5)
        // - 10  -> fish probability roll (< 65% for Fish #1 'Карась' on pond 0 + bait 1)
        // - 100 -> weight bracket permille roll (in [50..350] bracket: 50g..1010g)
        // - 50  -> weight offset within bracket (50 + 50 = 100g)
        // - defaultInt: 50 (never rolls 1 on hook-slip check), defaultFloat: 0.8 (fast downward pull)
        var rng = ScriptedFishingRandom(
            ints: [10, 3, 10, 100, 50],
            floats: [0.5, 0.5, 0.8, 0.8, 0.8],
            defaultInt: 50,
            defaultFloat: 0.8
        )

        let castTimeMs: Int64 = 1_700_000_010_000
        coordinator.castAt(x: 640, y: 745, nowMs: castTimeMs, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)
        XCTAssertNotNil(coordinator.currentLineCurve)

        // 2. Advance past scheduled bite time -> transitions to .fishFight (pre-hook bobbing)
        let biteTimeMs = coordinator.stateMachine.scheduledBiteTimeMs + 100
        coordinator.stepSimulationTick(nowMs: biteTimeMs, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .fishFight)
        XCTAssertTrue(coordinator.stateMachine.isPreHookBobbing)

        // 3. Touching the reel button (`setReelPulled(true)`) clears `isPreHookBobbing` and starts active fight
        coordinator.setReelPulled(true)
        XCTAssertFalse(coordinator.stateMachine.isPreHookBobbing)

        // 4. Step ticks while holding pull button until fish reaches bottom landing threshold
        var tickMs = biteTimeMs + 200
        for _ in 0..<25 {
            if coordinator.stateMachine.state == .idle { break }
            coordinator.stepSimulationTick(nowMs: tickMs, rng: &rng)
            tickMs += 200
        }

        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertEqual(coordinator.fishnetEntries.count, 1)
        XCTAssertGreaterThan(coordinator.profile.experience, 0)

        guard case .catchDialog(let caughtFish, let txResult, _, _, _) = coordinator.activeAlert else {
            XCTFail("Expected .catchDialog alert, got \(String(describing: coordinator.activeAlert))")
            return
        }
        XCTAssertEqual(caughtFish.fish.id, 1)
        XCTAssertTrue(txResult.storedInFishnet)

        // 5. Sell all fish in fishnet and verify coin balance increases
        coordinator.sellAllFishInFishnet(nowMs: tickMs + 1_000)
        XCTAssertEqual(coordinator.fishnetEntries.count, 0)
        XCTAssertGreaterThan(coordinator.profile.balance, balanceAfterKit)
    }

    // MARK: - 4. Water Shader Activation Policy (`GameActivity.b0()`)

    func testWaterShaderActivationPolicyMatchesGameActivity() {
        XCTAssertTrue(
            WaterShaderActivationPolicy.shouldActivate(
                pondBackgroundSetIndex: 1,
                waterShaderSettingEnabled: true
            )
        )
        XCTAssertFalse(
            WaterShaderActivationPolicy.shouldActivate(
                pondBackgroundSetIndex: 0,
                waterShaderSettingEnabled: true
            )
        )
        XCTAssertFalse(
            WaterShaderActivationPolicy.shouldActivate(
                pondBackgroundSetIndex: 1,
                waterShaderSettingEnabled: false
            )
        )
    }

    // MARK: - 5. 24-Bit BGR TGA Texture Decoder (`F0.s`)

    func testTgaTextureLoaderDecodes24BitBGRAndSwapsRedBlue() throws {
        var tgaBytes = [UInt8](repeating: 0, count: 18)
        tgaBytes[2] = 2   // Uncompressed true-color
        tgaBytes[12] = 2  // Width = 2 (LE)
        tgaBytes[13] = 0
        tgaBytes[14] = 1  // Height = 1 (LE)
        tgaBytes[15] = 0
        tgaBytes[16] = 24 // 24 bits per pixel

        tgaBytes.append(contentsOf: [10, 20, 30, 100, 150, 200])

        let decoded = try TgaTextureLoader.decode(data: Data(tgaBytes))
        XCTAssertEqual(decoded.width, 2)
        XCTAssertEqual(decoded.height, 1)
        XCTAssertEqual(decoded.bitsPerPixel, 24)
        XCTAssertEqual(decoded.rgbBytes, [30, 20, 10, 200, 150, 100])
        XCTAssertEqual(decoded.rgbaBytes, [30, 20, 10, 255, 200, 150, 100, 255])

        // Procedural 256x128 normal map round-trip
        let proceduralData = TgaTextureLoader.makeProceduralWaveNoiseTGA(width: 256, height: 128, seedPhase: 11)
        let proceduralDecoded = try TgaTextureLoader.decode(data: proceduralData)
        XCTAssertEqual(proceduralDecoded.width, 256)
        XCTAssertEqual(proceduralDecoded.height, 128)
        XCTAssertEqual(proceduralDecoded.rgbBytes.count, 256 * 128 * 3)
    }

    // MARK: - 6. Exact Water Shader Mathematics (`F0.n`, `PSBackGround.glsl`, `PSBlit0_night.glsl`)

    func testWaterShaderMathPhaseWrapRefractionAndNightTint() {
        let step1 = WaterShaderMath.stepPhaseOffset(0.0)
        XCTAssertEqual(step1, 0.0005, accuracy: 1e-7)

        let wrapped = WaterShaderMath.stepPhaseOffset(0.9998)
        XCTAssertEqual(wrapped, 0.0003, accuracy: 1e-6)

        let uvExtremeLow = WaterShaderMath.computeRefractedUV(
            texCoords: SIMD2<Float>(0.001, 0.002),
            ndcPosition: SIMD3<Float>(0.0, -0.5, 0.0),
            noise1Sample: SIMD4<Float>(1.0, 1.0, 0.5, 0.5),
            noise2Sample: SIMD4<Float>(1.0, 1.0, 0.5, 0.5)
        )
        XCTAssertGreaterThanOrEqual(uvExtremeLow.x, 0.01)
        XCTAssertGreaterThanOrEqual(uvExtremeLow.y, 0.01)

        let uvExtremeHigh = WaterShaderMath.computeRefractedUV(
            texCoords: SIMD2<Float>(0.999, 0.998),
            ndcPosition: SIMD3<Float>(0.0, -0.5, 0.0),
            noise1Sample: SIMD4<Float>(0.0, 0.0, 0.5, 0.5),
            noise2Sample: SIMD4<Float>(0.0, 0.0, 0.5, 0.5)
        )
        XCTAssertLessThanOrEqual(uvExtremeHigh.x, 0.99)
        XCTAssertLessThanOrEqual(uvExtremeHigh.y, 0.99)

        let specOut = WaterShaderMath.applyWaterSpecularAndAlpha(
            diffuseColor: SIMD4<Float>(0.2, 0.4, 0.6, 1.0),
            ndcPosition: SIMD3<Float>(0.0, -0.5, 0.0),
            normalizedNoise4D: SIMD4<Float>(0.0, 0.0, 1.0, 0.0)
        )
        XCTAssertEqual(specOut.w, 0.8, accuracy: 1e-6)

        let baseColor = SIMD4<Float>(0.8, 0.6, 0.5, 1.0)
        let dayBlit = WaterShaderMath.applyScreenBlitTint(color: baseColor, isDaylight: true)
        XCTAssertEqual(dayBlit.x, 0.8, accuracy: 1e-6)
        XCTAssertEqual(dayBlit.y, 0.6, accuracy: 1e-6)
        XCTAssertEqual(dayBlit.z, 0.5, accuracy: 1e-6)
        XCTAssertEqual(dayBlit.w, 0.9, accuracy: 1e-6)

        let nightBlit = WaterShaderMath.applyScreenBlitTint(color: baseColor, isDaylight: false)
        XCTAssertEqual(nightBlit.x, 0.8 * 0.25, accuracy: 1e-6)
        XCTAssertEqual(nightBlit.y, 0.6 * 0.25, accuracy: 1e-6)
        XCTAssertEqual(nightBlit.z, 0.5 * 0.40, accuracy: 1e-6)
        XCTAssertEqual(nightBlit.w, 0.9, accuracy: 1e-6)
    }

    // MARK: - 7. Online Auth Profile Restore (`C0.a.l`), Online Shop (`MainActivity$d.c`) & TCP Chat (`0xACED0005`)

    func testCoordinatorOnlineAuthRestoreShopSyncAndChatPacketHandling() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000
        )

        let rodName = try XCTUnwrap(coordinator.catalog.listAllRodSpecs().first?.name)
        let coilName = try XCTUnwrap(coordinator.catalog.listAllCoilSpecs().first?.name)
        let lineName = try XCTUnwrap(coordinator.catalog.listAllLineSpecs().first?.name)

        // 7-section `auth.php` response: `experience;balance;rods;coils;lines;achievs;quests`
        let authResponse = "18500;6500;\(rodName):3:97|not|not|not|not;\(coilName):1:92|not|not|not|not;\(lineName):3:95|not|not|not|not;1:4:1|2:15:1;2|1|0"
        let summary = try coordinator.restoreFromOnlineAuthResponse(
            authResponse,
            login: "ios_tester",
            password: "pw",
            nowMs: 1_700_000_005_000
        )

        XCTAssertEqual(summary.experience, 18500)
        XCTAssertEqual(summary.balanceCoins, 6500)
        XCTAssertEqual(summary.categoryRank, coordinator.profile.category)
        XCTAssertEqual(summary.restoredRodsCount, 1)
        XCTAssertEqual(summary.restoredCoilsCount, 1)
        XCTAssertEqual(summary.restoredLinesCount, 1)
        XCTAssertEqual(coordinator.profile.experience, 18500)
        XCTAssertEqual(coordinator.profile.balance, 6500)
        XCTAssertGreaterThan(coordinator.profile.category, 0)
        XCTAssertEqual(coordinator.ownedRods.count, 1)
        XCTAssertEqual(coordinator.ownedCoils.count, 1)
        XCTAssertEqual(coordinator.ownedLines.count, 1)

        var csvTokens: [String] = []
        for idx in 0..<37 {
            switch idx {
            case 0: csvTokens.append("320")
            case 1, 2, 3: csvTokens.append("\(525 + (idx - 1) * 600)")
            case 4, 5, 6: csvTokens.append("\(50 + (idx - 4) * 30)")
            case 7, 8, 9: csvTokens.append("\(10 + (idx - 7) * 2)")
            case 10, 11, 12: csvTokens.append("\(35 + (idx - 10) * 20)")
            case 13, 14, 15: csvTokens.append("\(600 + (idx - 13) * 700)")
            case 16, 17, 18: csvTokens.append("250")
            case 19, 20, 21: csvTokens.append("\(25 + (idx - 19) * 15)")
            case 30...36: csvTokens.append("\((idx - 29) * 10)")
            default: csvTokens.append("0")
            }
        }
        let csvString = csvTokens.joined(separator: ",") + ",note=3"
        let snapshot = try coordinator.syncOnlineShopFromCSV(csvString, nowMs: 1_700_000_006_000)
        XCTAssertEqual(snapshot.pearlsBalance, 320)
        XCTAssertEqual(snapshot.unreadNotesCount, 3)
        XCTAssertEqual(coordinator.onlineShopSnapshot?.pearlsBalance, 320)

        let incomingMess = ChatMess(
            fromID: 42,
            prem: 1,
            room: 0,
            from: "fisher_pro",
            object: nil,
            text: "Всем трофейного улова!",
            timeEpochMs: 1_700_000_007_000,
            to: ""
        )
        let packet = JavaObjectStreamCodec.encodeMess(incomingMess)
        let outcome = try coordinator.receiveChatStreamPacket(packet, currentUserId: 1)

        guard case .chatMessageReceived(let decodedMsg) = outcome else {
            XCTFail("Expected .chatMessageReceived, got \(outcome)")
            return
        }
        XCTAssertEqual(decodedMsg.from, "fisher_pro")
        XCTAssertEqual(decodedMsg.text, "Всем трофейного улова!")
        XCTAssertEqual(coordinator.chatMessages.count, 1)
    }

    // MARK: - 8. Phase 9: Audio, SFX (`F0.p`), Ambient Pond Music & Bite Haptics (`FishingService$e`)

    func testAudioAndHapticsBiteSignalAndAmbientSelection() {
        var controller = FishingAudioAndHapticsController(
            soundEnabled: true,
            vibrationEnabled: true,
            vibrationDurationMs: 500
        )

        // 1. Ambient track selection: day (05..21) -> day track, night (22..04) -> night track
        controller.syncAmbientTrack(pondIndex: 0, hour: 8)
        XCTAssertEqual(controller.activeAmbientTrack, AmbientPondTrack(pondIndex: 0, isDaylightTrack: true))

        controller.syncAmbientTrack(pondIndex: 0, hour: 23)
        XCTAssertEqual(controller.activeAmbientTrack, AmbientPondTrack(pondIndex: 0, isDaylightTrack: false))

        // 2. Record cast scheduled bite (`GameView.q`) -> plays `.castBobber`
        controller.recordCastScheduledBite(beginTimeMs: 10_000)
        XCTAssertEqual(controller.lastBeginTimeMs, 10_000)
        XCTAssertEqual(controller.playedSoundEffects, [.castBobber])

        // 3. Bite signal `what == 0` (`FishingService$e.handleMessage`)
        controller.handleBiteSignalWhat0(nowMs: 12_000)
        XCTAssertEqual(controller.lastBiteTimeMs, 12_000)
        XCTAssertEqual(controller.biteAlarmTriggerCount, 1)
        XCTAssertEqual(controller.vibrationTriggerCount, 1)

        // 4. Catch signal `what == 1` (`FishingService$e.handleMessage`) -> anti-cheat timing calculation
        controller.setReelLooping(true)
        XCTAssertTrue(controller.isReelLoopPlaying)
        controller.handleCatchSignalWhat1(nowMs: 18_000)
        XCTAssertFalse(controller.isReelLoopPlaying)
        XCTAssertEqual(controller.lastCatchTimeMs, 18_000)
        XCTAssertEqual(controller.lastAntiCheatBiteDelaySeconds, 2)
    }

    // MARK: - 9. Phase 9: Multi-Language Localization (`F0.g` & `F0.o.b`)

    func testLocalizationManagerPondNamesAndQuestLanguageGate() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000
        )
        let firstPond = try XCTUnwrap(coordinator.availablePonds.first)

        // Russian (`ru`): quests and tasks active
        coordinator.setLanguage(.ru)
        XCTAssertTrue(coordinator.localeManager.areQuestsAndTasksActive)
        XCTAssertEqual(coordinator.localeManager.pondName(for: firstPond), firstPond.nameRu)
        XCTAssertEqual(coordinator.localeManager.achievementTitle(id1Based: 1), "Завсегдатай")
        XCTAssertEqual(coordinator.localeManager.questTitle(id1Based: 1), "Ведро рыбы")

        // English (`en`): quests and tasks active
        coordinator.setLanguage(.en)
        XCTAssertTrue(coordinator.localeManager.areQuestsAndTasksActive)
        XCTAssertEqual(coordinator.localeManager.pondName(for: firstPond), firstPond.nameEn)
        XCTAssertEqual(coordinator.localeManager.achievementTitle(id1Based: 1), "Fishing everyday")
        XCTAssertEqual(coordinator.localeManager.questTitle(id1Based: 1), "Bucket of fishes")

        // German (`de`): quests and tasks disabled (`F0.g.b` returns false for non-ru/en)
        coordinator.setLanguage(.de)
        XCTAssertFalse(coordinator.localeManager.areQuestsAndTasksActive)
        XCTAssertEqual(coordinator.localeManager.pondName(for: firstPond), firstPond.nameDe)
        XCTAssertFalse(firstPond.nameDe.isEmpty)

        // Spanish (`es`) and Portuguese (`pt`): distinct localized names from reference data
        coordinator.setLanguage(.es)
        XCTAssertEqual(coordinator.localeManager.pondName(for: firstPond), firstPond.nameEs)
        XCTAssertFalse(firstPond.nameEs.isEmpty)

        coordinator.setLanguage(.pt)
        XCTAssertEqual(coordinator.localeManager.pondName(for: firstPond), firstPond.namePt)
        XCTAssertFalse(firstPond.namePt.isEmpty)
    }

    // MARK: - 10. Phase 9: Server Rewards (`reaward.php`) & Fisherman Contracts (`user_task`)

    func testCoordinatorClaimServerRewardsAndFishermanContractCompletion() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000
        )

        // 1. Claim server rewards (`reaward.php` format: `--notes=1,1=1500,2=800,3=2`): +1500 coins, +800 XP, and rod #2
        let rewardSummary = try coordinator.claimServerRewards(
            "--notes=1,1=1500,2=800,3=2",
            nowMs: 1_700_000_010_000
        )
        XCTAssertEqual(rewardSummary.unreadNotesCount, 1)
        XCTAssertEqual(rewardSummary.coinsAdded, 1500)
        XCTAssertEqual(rewardSummary.experienceAdded, 800)
        XCTAssertEqual(rewardSummary.newBalance, 2000)
        XCTAssertTrue(
            rewardSummary.grantedItems.contains(
                ServerRewardGrant(rewardType: .fishingRod, valueOrItemId: 2)
            )
        )
        XCTAssertEqual(coordinator.profile.balance, 2000)
        XCTAssertEqual(coordinator.ownedRods.count, 1)
        XCTAssertEqual(coordinator.ownedRods.first?.rod.id, 2)

        // 2. Assign a fisherman contract (`user_task`): catch 1 Crucian Carp (#1) of at least 100g for +500 XP
        let contract = try coordinator.assignFishermanContract(
            taskType: 1,
            targetFishId: 1,
            targetBaitId: 0,
            requiredCount: 1,
            requiredWeightGrams: 100,
            bonusExperience: 500,
            nowMs: 1_700_000_011_000
        )
        XCTAssertEqual(contract.currentCount, 0)
        XCTAssertEqual(contract.currentWeightGrams, 0)
        XCTAssertEqual(contract.made, 0)
        XCTAssertEqual(coordinator.activeContract?.targetFishId, 1)
    }

    // MARK: - 11. Phase 10: Live HTTP Request Builder & Response Parsers (`fish-mob.ru` & `chat.fish-mob.ru`)

    func testLiveHttpRequestHeadersAndResponseParsers() throws {
        let uuid = "550e8400-e29b-41d4-a716-446655440000"

        let authReq = FishingHttpRequestBuilder.makeAuthProfileRequest(
            login: "angler_one",
            password: "secret",
            installationUuid: uuid
        )
        XCTAssertEqual(authReq.url?.absoluteString, "http://fish-mob.ru/fff/auth.php")
        XCTAssertEqual(authReq.value(forHTTPHeaderField: "X-Fish-Login"), "angler_one")
        XCTAssertEqual(authReq.value(forHTTPHeaderField: "X-Fish-Uuid"), FishingNetworkCrypto.installationUuidMd5(uuid))
        XCTAssertNotNil(authReq.value(forHTTPHeaderField: "X-Fish-Fopl"))

        let fishSpec = FishSpecies(
            id: 1,
            name: "Карась",
            unitWeight: 500,
            unitPrice: 55,
            strength: 3,
            stamina: 6,
            intelligence: 2,
            aggression: 4
        )
        let caught = CaughtUserFish(
            fish: fishSpec,
            weightGrams: 1420,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 3,
            catchTimeMs: 1_700_000_123_000
        )
        let fishReq = FishingHttpRequestBuilder.makeSubmitFishCatchRequest(
            login: "angler_one",
            password: "secret",
            installationUuid: uuid,
            caughtFish: caught,
            tourType: 2
        )
        XCTAssertEqual(fishReq.url?.absoluteString, "http://fish-mob.ru/fff/fish.php")
        XCTAssertEqual(fishReq.value(forHTTPHeaderField: "X-Fish-Date"), "1700000123000")
        XCTAssertNotNil(fishReq.value(forHTTPHeaderField: "X-Fish-Folp"))

        XCTAssertEqual(
            FishingOnlineResponseParser.parseChatAuthResponse("1:778899"),
            .authenticated(userId: 778899)
        )
        XCTAssertEqual(
            FishingOnlineResponseParser.parseFishCatchUploadResponse("status=1100"),
            .newWorldRecord
        )

        let topRaw = """
        1:pro_fisher:950000:16
        2:lake_master:420000:13
        """
        let topEntries = FishingOnlineResponseParser.parseTopPlayersResponse(topRaw)
        XCTAssertEqual(topEntries.count, 2)
        XCTAssertEqual(topEntries[0].login, "pro_fisher")
        XCTAssertEqual(topEntries[0].categoryRank, 16)

        let rekRaw = """
        Карась:2950:master_angler
        Щука:24800:river_king
        """
        let records = FishingOnlineResponseParser.parseWorldSpeciesRecordsResponse(rekRaw)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[1].fishName, "Щука")
        XCTAssertEqual(records[1].weightGrams, 24800)
    }

    // MARK: - 12. Phase 10: Sleep-Mode Clock Catch-Up (`GameActivity.onResume`) & `tourType` Resolution

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

    // MARK: - 13. Phase 10: iOS 18+ `NSAppTransportSecurity` Configuration Verification

    func testIOSAppTransportSecurityConfiguration() throws {
        let ats = FishingIOSAppConfiguration.appTransportSecurityPlistDictionary
        XCTAssertEqual(ats["NSAllowsArbitraryLoads"] as? Bool, false)
        let domains = ats["NSExceptionDomains"] as? [String: [String: Bool]]
        XCTAssertEqual(domains?["fish-mob.ru"]?["NSExceptionAllowsInsecureHTTPLoads"], true)
        XCTAssertEqual(domains?["chat.fish-mob.ru"]?["NSExceptionAllowsInsecureHTTPLoads"], true)
        XCTAssertEqual(FishingIOSAppConfiguration.chatServerPort, 15701)
    }

    // MARK: - 14. Phase 11 & 12: Persistent `INSTALLATION` UUID (`F0.e.a`), `GameData` Bootstrapper & APK Drawables

    func testInstallationUuidPersistenceAndAppBundleDatabaseBootstrap() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FishingAppBootstrapTest_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let uuid1 = try AppBundleDatabaseBootstrapper.resolveOrCreateInstallationUuid(in: tempDir)
        XCTAssertEqual(uuid1.count, 36)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("INSTALLATION").path))

        let uuid2 = try AppBundleDatabaseBootstrapper.resolveOrCreateInstallationUuid(in: tempDir)
        XCTAssertEqual(uuid1, uuid2)

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
            XCTAssertNotNil(OriginalGameAssetsLoader.resolveDrawableURL(named: "screansaver", gameDataDirectoryURL: gameDataURL))
            XCTAssertNotNil(OriginalGameAssetsLoader.resolveDrawableURL(named: "ic_launcher", gameDataDirectoryURL: gameDataURL))
        }
    }

    @MainActor
    func testVisualFramePersistenceAndReelPullIdempotence() throws {
        let coordinator = try FishingAppCoordinator(databasePath: ":memory:", nowMs: 1_700_000_000_000)
        XCTAssertFalse(coordinator.isDebugOverlayEnabled)

        coordinator.buyAndEquipStarterKit(nowMs: 1_700_000_001_000)

        var rng = ScriptedFishingRandom(
            ints: [10, 3, 10, 100, 50],
            floats: [0.5, 0.5, 0.8, 0.8],
            defaultInt: 50,
            defaultFloat: 0.5
        )
        coordinator.castAt(x: 640, y: 500, nowMs: 1_700_000_002_000, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)
        XCTAssertNotNil(coordinator.renderedBobberPosition)
        XCTAssertEqual(coordinator.renderedBobberPosition?.x, 640)
        XCTAssertEqual(coordinator.renderedBobberPosition?.y, 500)
        XCTAssertEqual(coordinator.stateMachine.lineGeometry?.isCastAnimating, true)
        XCTAssertEqual(coordinator.currentLineCurve?.alpha, 0)

        let baseWallMs: Int64 = 1_700_000_010_000
        for step in 1...15 {
            coordinator.stepVisualFrameTick(wallNowMs: baseWallMs + Int64(step * 65))
        }
        XCTAssertEqual(coordinator.stateMachine.lineGeometry?.isCastAnimating, false)
        XCTAssertEqual(coordinator.currentLineCurve?.alpha, 180)

        let biteTimeMs = coordinator.stateMachine.scheduledBiteTimeMs + 100
        coordinator.stepSimulationTick(nowMs: biteTimeMs, rng: &rng)
        XCTAssertEqual(coordinator.stateMachine.state, .fishFight)
        XCTAssertEqual(coordinator.stateMachine.bobber?.isBiteTexture, true)
        if let bobberY = coordinator.stateMachine.bobber?.y,
           let lineEndY = coordinator.currentLineCurve?.end.y {
            XCTAssertEqual(lineEndY, bobberY, accuracy: 0.001)
        }

        coordinator.setReelPulled(true)
        XCTAssertTrue(coordinator.stateMachine.isPulled)
        XCTAssertFalse(coordinator.stateMachine.isPreHookBobbing)
        let tensionFactorAfterFirstPull = coordinator.stateMachine.lineGeometry?.tensionFactor ?? 0

        // Repeatedly calling setReelPulled(true) (simulating DragGesture.onChanged touch samples) must be a no-op
        coordinator.setReelPulled(true)
        coordinator.setReelPulled(true)
        XCTAssertEqual(coordinator.stateMachine.lineGeometry?.tensionFactor, tensionFactorAfterFirstPull)
    }
}