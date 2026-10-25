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
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
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
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
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
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
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
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
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
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
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
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
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

        let shopReq = FishingHttpRequestBuilder.makeOnlineShopRequest(
            login: "angler_one",
            password: "secret",
            installationUuid: uuid
        )
        XCTAssertEqual(shopReq.url?.absoluteString, FishingHttpEndpoint.onlineShopCatalog.rawValue)

        let rewardReq = FishingHttpRequestBuilder.makeServerRewardsRequest(
            login: "angler_one",
            password: "secret",
            installationUuid: uuid,
            languageCode: "ru"
        )
        XCTAssertEqual(rewardReq.url?.absoluteString, FishingHttpEndpoint.claimRewards.rawValue)
        XCTAssertEqual(rewardReq.value(forHTTPHeaderField: "X-Fish-AppSign"), FishingNetworkCrypto.appSignConstant)

        let topReq = FishingHttpRequestBuilder.makeTopPlayersRequest(login: "angler_one", languageCode: "ru")
        XCTAssertEqual(topReq.url?.absoluteString, FishingHttpEndpoint.topPlayersRating.rawValue)

        let rekReq = FishingHttpRequestBuilder.makeWorldRecordsRequest(languageCode: "ru")
        XCTAssertEqual(rekReq.url?.absoluteString, FishingHttpEndpoint.worldSpeciesRecords.rawValue)

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
        XCTAssertEqual(fishReq.value(forHTTPHeaderField: "X-Fish-Date"), FishingNetworkCrypto.formatJavaDateToString(epochMs: 1_700_000_123_000))
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
            nowMs: 1_000_000,
            notificationScheduling: NoopSystemNotifications()
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
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
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
            nowMs: 1_700_000_002_000,
            notificationScheduling: NoopSystemNotifications()
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
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
        )
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

        // Stepping unified 30 FPS realtime loop every 33ms during fishFight with reel pulled
        // must trigger 200ms physics ticks, increase tension bar, and pull bobber downward
        let initialFightBobberY = coordinator.stateMachine.bobber?.y ?? 0
        for frame in 1...10 {
            coordinator.stepRealtimeLoop(nowMs: biteTimeMs + Int64(frame * 34))
        }
        XCTAssertGreaterThan(coordinator.stateMachine.tension, 0)
        XCTAssertGreaterThan(coordinator.stateMachine.bobber?.y ?? 0, initialFightBobberY)
    }

    @MainActor
    func testFastForwardToScheduledBiteUsesCurrentWallTimeAndAllowsReeling() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
        )
        coordinator.buyAndEquipStarterKit(nowMs: 1_700_000_001_000)

        let castWallMs: Int64 = 1_700_000_002_000
        coordinator.castAt(x: 640, y: 450, nowMs: castWallMs)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)

        let fastForwardWallMs: Int64 = castWallMs + 500
        coordinator.fastForwardToScheduledBite(nowMs: fastForwardWallMs)
        XCTAssertEqual(coordinator.stateMachine.state, .fishFight)
        // Bite timestamp must not be pushed 15..84 seconds into the future
        XCTAssertLessThanOrEqual(coordinator.stateMachine.biteStartTimeMs, fastForwardWallMs + 20)

        coordinator.setReelPulled(true)
        for frame in 1...8 {
            coordinator.stepRealtimeLoop(nowMs: fastForwardWallMs + 20 + Int64(frame * 35))
        }
        XCTAssertGreaterThan(coordinator.stateMachine.tension, 0)
    }

    @MainActor
    func testPortraitViewportRodAndLinePlacementOnRightSide() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
        )
        coordinator.buyAndEquipStarterKit(nowMs: 1_700_000_001_000)

        // Simulate portrait iPhone pond canvas size (393 x 600)
        coordinator.updateViewportSize(width: 393, height: 600)
        let rod = coordinator.stateMachine.rodSprite
        XCTAssertEqual(rod.height, 300)
        XCTAssertEqual(rod.width, 117)
        // Right edge of rod butt is at (393 / 5) * 4 = 312, originX = 312 - 117 = 195 (well inside 0..<393)
        XCTAssertEqual(rod.originX, 195, accuracy: 0.01)
        XCTAssertEqual(rod.originY, 300, accuracy: 0.01)
        XCTAssertLessThan(rod.originX + Float(rod.width), 393)

        coordinator.castAt(x: 180, y: 360, nowMs: 1_700_000_002_000)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)

        let expectedTip = FishingLineGeometry.rodTipPoint(for: rod)
        XCTAssertNotNil(coordinator.currentLineCurve)
        if let start = coordinator.currentLineCurve?.start {
            XCTAssertEqual(start.x, expectedTip.x, accuracy: 0.01)
            XCTAssertEqual(start.y, expectedTip.y, accuracy: 0.01)
            XCTAssertLessThan(start.x, 393)
            XCTAssertGreaterThan(start.x, 195)
        }
    }

    @MainActor
    func testCheckModeBiteNotificationAndSleepWakeup() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
        )
        coordinator.buyAndEquipStarterKit(nowMs: 1_700_000_001_000)
        coordinator.updateViewportSize(width: 393, height: 600)
        coordinator.checkModeEnabled = true

        let castMs: Int64 = 1_700_000_010_000
        coordinator.castAt(x: 200, y: 380, nowMs: castMs)
        XCTAssertEqual(coordinator.stateMachine.state, .waitingForBite)
        XCTAssertTrue(coordinator.biteNotificationScheduler.isNotificationPending)
        XCTAssertEqual(
            coordinator.biteNotificationScheduler.scheduledBiteTimeMs,
            coordinator.stateMachine.scheduledBiteTimeMs
        )

        // Enter background -> arms castActiveFlag = 1 (`GameView.u = 1`)
        coordinator.handleAppDidEnterBackground(nowMs: castMs + 1_000)
        XCTAssertEqual(coordinator.stateMachine.castActiveFlag, 1)

        // Return to foreground 15 seconds after scheduledBiteTimeMs (> 11s CHECKMODE limit) -> missedBiteDuringSleep
        let lateWakeMs = coordinator.stateMachine.scheduledBiteTimeMs + 15_000
        coordinator.handleAppDidBecomeActive(nowMs: lateWakeMs)
        XCTAssertFalse(coordinator.biteNotificationScheduler.isNotificationPending)
        XCTAssertEqual(coordinator.stateMachine.state, .idle)
        XCTAssertEqual(coordinator.activeAlert, .missedBiteDuringSleep)
    }

    @MainActor
    func testSettingsAndOnlineCredentialsPersistenceAcrossRestarts() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FishingSettingsPersistTest_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let coordinator1 = try AppBundleDatabaseBootstrapper.bootstrapAppCoordinator(
            appSupportDirectory: tempDir,
            initialHour: 14,
            initialMinute: 25,
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
        )
        coordinator1.isWaterShaderEnabled = false
        coordinator1.pondBackgroundSetIndex = 3
        coordinator1.tasksEnabled = false
        coordinator1.audioHaptics.soundEnabled = false
        coordinator1.audioHaptics.vibrationEnabled = false
        coordinator1.checkModeEnabled = true
        coordinator1.onlineModeEnabled = true
        coordinator1.isDebugOverlayEnabled = true
        coordinator1.languageCode = "en"
        coordinator1.savedOnlineLogin = "persisted_angler"
        coordinator1.savedOnlinePassword = "persisted_secret"
        coordinator1.stepGameClockMinute()

        // Re-launch coordinator on the same Application Support directory
        let coordinator2 = try AppBundleDatabaseBootstrapper.bootstrapAppCoordinator(
            appSupportDirectory: tempDir,
            initialHour: 6,
            initialMinute: 0,
            nowMs: 1_700_000_010_000,
            notificationScheduling: NoopSystemNotifications()
        )
        XCTAssertFalse(coordinator2.isWaterShaderEnabled)
        XCTAssertEqual(coordinator2.pondBackgroundSetIndex, 3)
        XCTAssertFalse(coordinator2.tasksEnabled)
        XCTAssertFalse(coordinator2.audioHaptics.soundEnabled)
        XCTAssertFalse(coordinator2.audioHaptics.vibrationEnabled)
        XCTAssertTrue(coordinator2.checkModeEnabled)
        XCTAssertTrue(coordinator2.onlineModeEnabled)
        XCTAssertTrue(coordinator2.isDebugOverlayEnabled)
        XCTAssertEqual(coordinator2.languageCode, "en")
        XCTAssertEqual(coordinator2.savedOnlineLogin, "persisted_angler")
        XCTAssertEqual(coordinator2.savedOnlinePassword, "persisted_secret")
        XCTAssertEqual(coordinator2.profile.login, "persisted_angler")
        XCTAssertEqual(coordinator2.profile.password, "persisted_secret")
        XCTAssertEqual(coordinator2.gameClock.hour, 14)
        XCTAssertEqual(coordinator2.gameClock.minute, 26)
    }

    // MARK: - 18. Phase 17: Real `fish-mob.ru` Online Parsers (`top.php`, `rek.php`, `index.php`), TCP Stream Framing & Audio Engine

    func testRealFishMobOnlineParsersAndStreamFraming() throws {
        // 1. Real `top.php` format from `Lx0/p` (`LINK=4`): header line + `"1. Login - 12450000"`
        let rawTop = "Рейтинг игроков\n1. Мастер_Дона - 72500000\n2. Сибиряк_77 - 12450000\n"
        let topEntries = FishingOnlineResponseParser.parseTopPlayersResponse(rawTop)
        XCTAssertEqual(topEntries.count, 2)
        XCTAssertEqual(topEntries[0].rankPosition, 1)
        XCTAssertEqual(topEntries[0].login, "Мастер_Дона")
        XCTAssertEqual(topEntries[0].experience, 72_500_000)
        XCTAssertGreaterThan(topEntries[0].categoryRank, 0)
        XCTAssertEqual(topEntries[1].rankPosition, 2)
        XCTAssertEqual(topEntries[1].login, "Сибиряк_77")

        // 2. Real `rek.php` format from `Lx0/p` (`LINK=6`): `"1. HolderLogin - FishName - 2950 г."`
        let rawRek = "Таблица рекордов\n1. Рыболов_Про - Белуга - 1450000 г.\n2. Капитан - Щука - 24800 г.\n"
        let rekEntries = FishingOnlineResponseParser.parseWorldSpeciesRecordsResponse(rawRek)
        XCTAssertEqual(rekEntries.count, 2)
        XCTAssertEqual(rekEntries[0].holderLogin, "Рыболов_Про")
        XCTAssertEqual(rekEntries[0].fishName, "Белуга")
        XCTAssertEqual(rekEntries[0].weightGrams, 1_450_000)
        XCTAssertEqual(rekEntries[1].fishName, "Щука")
        XCTAssertEqual(rekEntries[1].weightGrams, 24_800)

        // 3. Real `index.php` tournament list (`LINK=2` active & `LINK=3` completed)
        let rawActiveTours = "Вечерний кубок--Максимальный вес: Карась--Кедровый остров--20:00 - 21:00--1--1045#Ночной турнир--Сумма веса: Сом--Дон--22:00 - 23:00--0--1046#"
        let activeTours = FishingOnlineResponseParser.parseTournamentIndexResponse(rawActiveTours, isCompleted: false)
        XCTAssertEqual(activeTours.count, 2)
        XCTAssertEqual(activeTours[0].id, "1045")
        XCTAssertEqual(activeTours[0].title, "Вечерний кубок")
        XCTAssertFalse(activeTours[0].isCompleted)

        let rawDoneTours = "Дневной блиц (Победитель: Рыбак_1)--18:00--1040#"
        let doneTours = FishingOnlineResponseParser.parseTournamentIndexResponse(rawDoneTours, isCompleted: true)
        XCTAssertEqual(doneTours.count, 1)
        XCTAssertEqual(doneTours[0].id, "1040")
        XCTAssertTrue(doneTours[0].isCompleted)

        // 4. `auth_chat.php` single-digit rejection code without colon
        let rejectedNoColon = FishingOnlineResponseParser.parseChatAuthResponse("0")
        XCTAssertEqual(rejectedNoColon, .rejected(statusCode: 0, message: "Доступ к чату временно закрыт (код 0)."))

        // 5. Multi-message TCP stream buffer with single `0xACED0005` header + `TC_RESET (0x79)` on subsequent messages
        let m1 = ChatProtocolSelector.makeOpenHandshakeMess(
            userId: 42,
            login: "angler_ios",
            pondRoom: 0,
            installationUuid: "11111111-2222-3333-4444-555555555555"
        )
        let m2 = ChatProtocolSelector.makeSystemMess(
            command: "initialize",
            userId: 42,
            login: "angler_ios",
            pondRoom: 0
        )
        var combinedStream = JavaObjectStreamCodec.encodeMess(m1, includeStreamHeader: true)
        combinedStream.append(
            JavaObjectStreamCodec.encodeMess(
                m2,
                includeStreamHeader: false,
                prependResetWhenNoHeader: true
            )
        )
        let decodedMany = JavaObjectStreamCodec.extractMessagesFromStreamBuffer(&combinedStream)
        XCTAssertEqual(decodedMany.count, 2)
        XCTAssertEqual(decodedMany[0].text, "open")
        XCTAssertEqual(decodedMany[1].text, "initialize")
        XCTAssertTrue(combinedStream.isEmpty)
    }

    @MainActor
    func testChatServerUserDataPremSyncInCoordinator() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
        )
        XCTAssertEqual(coordinator.chatServerUserData.prem, 0)

        let serverUD = ChatServerUserData(
            bcap: 50,
            curLevelXP: 1000,
            fbcap: 50,
            lv: 12,
            mbcap: 50,
            money: 25000,
            prem: 3,
            rmoney: 15,
            toNextlv: 2000,
            xp: 18500
        )
        let initMess = ChatMess(
            fromID: -1,
            prem: 0,
            room: 0,
            from: ChatMess.systemPeer,
            object: .initObject(ChatInitObject(tours: [], userData: serverUD)),
            text: "initialize",
            timeEpochMs: nil,
            to: "angler_ios"
        )
        let packet = JavaObjectStreamCodec.encodeMess(initMess)
        _ = try coordinator.receiveChatStreamPacket(packet, currentUserId: 42)
        XCTAssertEqual(coordinator.chatServerUserData.prem, 3)
        XCTAssertEqual(coordinator.chatServerUserData.rmoney, 15)
    }

    func testWaterHorizonClampAndNativeAudioEngineData() throws {
        // Verify bobber never steps above `viewHeight / 4 + halfBobberHeight` during fish fight escape
        let bt = BalanceTables()
        let pondData = PondSimulationData(
            pondIndex: 0,
            activeBaitIndices0Based: [0],
            catchableFishByBaitSlot: [[0]],
            fishWeightRanges: [
                PondFishWeightRange(fishIndex0Based: 0, minWeightGrams: 100, maxWeightGrams: 3000)
            ],
            factorsMorning: [
                [PondFishBiteFactor(fishIndex0Based: 0, probabilityPercent: 100)]
            ],
            factorsAfternoon: [
                [PondFishBiteFactor(fishIndex0Based: 0, probabilityPercent: 100)]
            ],
            factorsEvening: [
                [PondFishBiteFactor(fishIndex0Based: 0, probabilityPercent: 100)]
            ],
            factorsNight: [
                [PondFishBiteFactor(fishIndex0Based: 0, probabilityPercent: 100)]
            ]
        )
        let fish = FishSpecies(
            id: 1,
            name: "Карась",
            unitWeight: 500,
            unitPrice: 55,
            strength: 10,
            stamina: 10,
            intelligence: 10,
            aggression: 10,
            md5Valid: true
        )
        let tackle = AssembledTackle(
            userRod: UserRodItem(id: 1, rod: FishingRodSpec(id: 1, name: "Rod", weight: 25, price: 100), strength: 100),
            userLine: UserLineItem(id: 1, line: FishingLineSpec(id: 1, name: "Line", weight: 25, stockLength: 100, price: 100), length: 100),
            userCoil: UserCoilItem(id: 1, coil: CoilSpec(id: 1, name: "Coil", bearingCount: 3, price: 100), strength: 100),
            userHook: UserHookItem(id: 1, hook: HookSpec(id: 1, name: "Hook"), amount: 5),
            userBait: UserBaitItem(id: 1, bait: BaitSpec(id: 1, name: "Bait"), amount: 20)
        )
        var sm = FishingStateMachine(
            viewWidth: 400,
            viewHeight: 600,
            bobberBitmapWidth: 24,
            bobberBitmapHeight: 40,
            animationsEnabled: true,
            balanceTables: bt,
            pondData: pondData,
            timeOfDay: .morning,
            fishCatalogById1Based: [1: fish],
            tackle: tackle
        )
        var rng = ScriptedFishingRandom(ints: [5, 0, 10, 500, 100], floats: [0.99], defaultInt: 2, defaultFloat: 0.99)
        _ = sm.cast(x: 200, y: 185, nowMs: 1_000, rng: &rng)
        XCTAssertEqual(sm.state, FishingState.waitingForBite)

        let biteMs = sm.scheduledBiteTimeMs + 100
        let biteEvents = sm.stepTick(nowMs: biteMs, rng: &rng)
        XCTAssertEqual(sm.state, FishingState.fishFight)
        XCTAssertEqual(biteEvents, [FishingUIEvent.biteTriggered])

        // Transition out of pre-hook bobbing into active fight, then release reel so the fish swims away (`isPulled == false`)
        sm.setPulled(true)
        sm.setPulled(false)
        XCTAssertFalse(sm.isPreHookBobbing)
        XCTAssertFalse(sm.isPulled)

        // Let the fish pull away (`isPulled == false`) for 40 ticks: bobber must stay >= 600/4 + 20 = 170
        let rod = sm.tackle.userRod!.rod
        let minAllowedWaterY = Float(600 / 4) + Float(40 / 2)
        for tick in 1...40 {
            sm.stepBobberMovement(rod: rod, nowMs: biteMs + Int64(tick * 200), rng: &rng)
            XCTAssertGreaterThanOrEqual(sm.bobber?.y ?? 0, minAllowedWaterY)
        }
        // Verify bobber actually reached and stayed clamped at the upper water horizon (170.0)
        XCTAssertEqual(sm.bobber?.y ?? 0, minAllowedWaterY, accuracy: 0.01)

        // Verify Phase 17 audio engine embedded `.m4a` and procedural `.wav` assets are non-empty and valid
        let engine = LiveAudioPlaybackEngine.shared
        let klevData = engine.resolvedAudioData(forKey: "klev")
        let twData = engine.resolvedAudioData(forKey: "tw")
        XCTAssertGreaterThan(klevData.count, 1000)
        XCTAssertGreaterThan(twData.count, 1000)

        for sfx in FishingSoundEffect.allCases {
            let wavData = engine.resolvedAudioData(forKey: "sfx_\(sfx.rawValue)")
            XCTAssertGreaterThan(wavData.count, 1000)
            let headerPrefix = String(decoding: wavData.prefix(4), as: UTF8.self)
            XCTAssertEqual(headerPrefix, "RIFF")
        }

        // Verify per-pond ambient loops (`pond0_day` .. `pond14_night`) are valid RIFF WAV and distinct across ponds
        let pond0Day = engine.resolvedAudioData(forKey: "pond0_day")
        let pond1Day = engine.resolvedAudioData(forKey: "pond1_day")
        let pond0Night = engine.resolvedAudioData(forKey: "pond0_night")
        XCTAssertEqual(String(decoding: pond0Day.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: pond1Day.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: pond0Night.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertNotEqual(pond0Day, pond1Day)
        XCTAssertNotEqual(pond0Day, pond0Night)
    }

    @MainActor
    func testSoundTogglePondScreenVisibilityWeightScaledBiteHapticsAndAchievsSync() throws {
        let coordinator = try FishingAppCoordinator(
            databasePath: ":memory:",
            nowMs: 1_700_000_000_000,
            notificationScheduling: NoopSystemNotifications()
        )
        XCTAssertEqual(coordinator.selectedTab, .fishingPond)
        XCTAssertTrue(coordinator.audioHaptics.isOnPondScreen)

        // Switching to BaseHub immediately marks `isOnPondScreen = false` and stops reel loop
        coordinator.selectedTab = .baseHub
        XCTAssertFalse(coordinator.audioHaptics.isOnPondScreen)
        XCTAssertFalse(coordinator.audioHaptics.isReelLoopPlaying)

        // Returning to FishingPond restores `isOnPondScreen = true`
        coordinator.selectedTab = .fishingPond
        XCTAssertTrue(coordinator.audioHaptics.isOnPondScreen)

        // Disabling `soundEnabled` immediately stops reel loop
        coordinator.audioHaptics.setReelLooping(true)
        XCTAssertTrue(coordinator.audioHaptics.isReelLoopPlaying)
        coordinator.audioHaptics.soundEnabled = false
        XCTAssertFalse(coordinator.audioHaptics.isReelLoopPlaying)
        coordinator.audioHaptics.soundEnabled = true

        // Verify weight-scaled bite haptic profiles (`<500g`, `500..2999g`, `3000..14999g`, `>=15000g`)
        coordinator.audioHaptics.handleBiteSignalWhat0(nowMs: 1_000, fishWeightGrams: 180)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile, .lightNibbler)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile.pulseCount, 1)

        coordinator.audioHaptics.handleBiteSignalWhat0(nowMs: 2_000, fishWeightGrams: 1_450)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile, .mediumStrike)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile.pulseCount, 1)

        coordinator.audioHaptics.handleBiteSignalWhat0(nowMs: 3_000, fishWeightGrams: 6_200)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile, .heavyPull)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile.pulseCount, 2)

        coordinator.audioHaptics.handleBiteSignalWhat0(nowMs: 4_000, fishWeightGrams: 28_000)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile, .trophyGiant)
        XCTAssertEqual(coordinator.audioHaptics.lastBiteHapticProfile.pulseCount, 3)

        // Verify `doubleMd5Password` idempotence on already-hashed 32-char lowercase hex passwords
        let plainPass = "my_secret_pass"
        let firstDoubleHash = FishingNetworkCrypto.doubleMd5Password(plainPass)
        XCTAssertTrue(FishingNetworkCrypto.isHexMd5Digest(firstDoubleHash))
        let secondCallOnHash = FishingNetworkCrypto.doubleMd5Password(firstDoubleHash)
        XCTAssertEqual(firstDoubleHash, secondCallOnHash)

        // Verify `makeSyncAchievementsAndQuestsRequest` & `parseAchievementsQuestsSyncResponse` (`achievs.php`)
        let fach = try coordinator.repository.buildFachHeader()
        let fqst = try coordinator.repository.buildFqstHeader()
        let req = FishingHttpRequestBuilder.makeSyncAchievementsAndQuestsRequest(
            login: "angler_ios",
            password: firstDoubleHash,
            installationUuid: coordinator.installationUuid,
            fachHeader: fach,
            fqstHeader: fqst,
            languageCode: "ru"
        )
        XCTAssertEqual(req.url?.absoluteString, "http://fish-mob.ru/fff/achievs.php")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Fish-Fach"), fach)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Fish-Fqst"), fqst)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Fish-Lng"), "ru")
        XCTAssertNotNil(req.value(forHTTPHeaderField: "X-Fish-Fopl"))

        let okSync = FishingOnlineResponseParser.parseAchievementsQuestsSyncResponse("status=1000,message=OK")
        XCTAssertEqual(okSync, .synchronized(serverMessage: "OK"))
        let realOkSync = FishingOnlineResponseParser.parseAchievementsQuestsSyncResponse("1000,status=0,message=")
        XCTAssertEqual(realOkSync, .synchronized(serverMessage: "Прогресс синхронизирован с сервером (код 1000)."))
        let errSync = FishingOnlineResponseParser.parseAchievementsQuestsSyncResponse("2000")
        XCTAssertEqual(errSync, .rejected(statusCode: "2000", message: "Неверный логин или пароль (код 2000)."))
        let err9000 = FishingOnlineResponseParser.parseAchievementsQuestsSyncResponse("9000,status=0,message=")
        XCTAssertEqual(err9000, .rejected(statusCode: "9000", message: "Пожалуйста, авторизуйтесь в профиле (код 9000)."))
        let err6000 = FishingOnlineResponseParser.parseAchievementsQuestsSyncResponse("6000,status=0,message=125")
        XCTAssertEqual(err6000, .rejected(statusCode: "6000", message: "Попробуйте через: 2 мин. 5 сек. (код 6000)."))
        XCTAssertEqual(FishingOnlineResponseParser.formatCooldownDuration(seconds: 3665), "1 ч. 1 мин. 5 сек.")
        XCTAssertEqual(FishingOnlineResponseParser.parseFishCatchUploadResponse("1000,status=0,message="), .accepted)
        XCTAssertEqual(FishingOnlineResponseParser.parseFishCatchUploadResponse("9000,status=0,message="), .rejected(statusCode: 9000))

        // Verify Dalvik-exact 15-field `X-Fish-Fopl` and 5-slot inventory `X-Fish-Folp` for `fish.php` (`FishingService$d.a` / `b()`)
        let sampleFish = CaughtUserFish(
            fish: FishSpecies(
                id: 1,
                name: "Карась",
                unitWeight: 500,
                unitPrice: 55,
                strength: 2,
                stamina: 2,
                intelligence: 2,
                aggression: 2,
                md5Valid: true
            ),
            weightGrams: 750,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 5,
            catchTimeMs: 1_700_000_050_000
        )
        let invFolp = try coordinator.repository.buildFishCatchInventoryFolpHeader()
        XCTAssertEqual(invFolp.components(separatedBy: ";").count, 3)

        let fishReq = FishingHttpRequestBuilder.makeSubmitFishCatchRequest(
            login: "angler_ios",
            password: firstDoubleHash,
            installationUuid: coordinator.installationUuid,
            caughtFish: sampleFish,
            tourType: 0,
            playerCategory: 5,
            playerExperience: 12000,
            playerBalance: 4500,
            antiCheatCatchDeltaMs: -250,
            antiCheatBiteDelaySeconds: 18,
            inventoryFolpHeader: invFolp
        )
        XCTAssertEqual(fishReq.value(forHTTPHeaderField: "X-Fish-Folp"), invFolp)
        XCTAssertTrue(fishReq.value(forHTTPHeaderField: "X-Fish-Date")?.contains("GMT") == true)
        let foplB64 = fishReq.value(forHTTPHeaderField: "X-Fish-Fopl") ?? ""
        let foplDecoded = String(data: Data(base64Encoded: foplB64) ?? Data(), encoding: .utf8) ?? ""
        let foplFields = foplDecoded.components(separatedBy: ":")
        XCTAssertEqual(foplFields.count, 15)
        XCTAssertEqual(foplFields[0], "angler_ios")
        XCTAssertEqual(foplFields[1], firstDoubleHash)
        XCTAssertEqual(foplFields[2], "fishmob YmQ=")
        // Field 3 is 0-based `fish.id - 1` (`0` for `id: 1`), obfuscated via `(v ^ 209) << 2`:
        XCTAssertEqual(foplFields[3], FishingNetworkCrypto.obfuscateFishPhpHexField(0))
        XCTAssertEqual(foplFields[3], "344") // (0 ^ 209) << 2 == 836 == 0x344
        XCTAssertEqual(foplFields[4], FishingNetworkCrypto.obfuscateFishPhpHexField(750))
        XCTAssertEqual(foplFields[4], "8fc") // (750 ^ 209) << 2 == 2300 == 0x8fc

        // Verify `tour_regin.php` & `tour_results.php` builders and parser
        let regReq = FishingHttpRequestBuilder.makeTournamentRegistrationRequest(
            login: "angler_ios",
            password: firstDoubleHash,
            installationUuid: coordinator.installationUuid,
            tournamentId: "1045",
            actionType: "1",
            languageCode: "ru"
        )
        XCTAssertEqual(regReq.url?.absoluteString, "http://fish-mob.ru/fff/tour_regin.php")
        XCTAssertEqual(regReq.value(forHTTPHeaderField: "X-Fish-Id"), "1045")

        let parsedResults = FishingOnlineResponseParser.parseTournamentResultsResponse(
            "--regin=1,left=900,start=0,users=12,tour=1045--1. Рыбак_1 - 3450 г\n2. Рыбак_2 - 2800 г",
            tournamentId: "1045"
        )
        XCTAssertEqual(parsedResults.participantsCount, 12)
        XCTAssertEqual(parsedResults.secondsLeft, 900)
        XCTAssertTrue(parsedResults.isRegistered)
        XCTAssertEqual(parsedResults.leaderboardLines.count, 2)
    }
}