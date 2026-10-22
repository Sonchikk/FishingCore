import XCTest
@testable import FishingCore
@testable import FishingDatabase

final class FishingDatabaseTests: XCTestCase {
    private var tempDirURL: URL!
    private var dbPath: String!
    private let testUuid = "00000000-0000-0000-0000-000000000000"

    override func setUpWithError() throws {
        try super.setUpWithError()
        let baseTemp = FileManager.default.temporaryDirectory
            .appendingPathComponent("FishingDatabaseTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: baseTemp, withIntermediateDirectories: true)
        self.tempDirURL = baseTemp
        self.dbPath = baseTemp.appendingPathComponent("fishing2_test.db").path
    }

    override func tearDownWithError() throws {
        if let tempDirURL {
            try? FileManager.default.removeItem(at: tempDirURL)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helper: Write minimal or full JSON fixture directory

    private func writeMinimalJSONFixtures(to dir: URL) throws {
        let fishesJSON = """
        {
          "items": [
            {
              "id": 1,
              "name_ru": "Карась",
              "image_res_id": 2131231046,
              "unit_weight_grams": 500,
              "unit_price_coins": 55,
              "strength": 3,
              "stamina": 6,
              "intelligence": 2,
              "aggression": 4
            },
            {
              "id": 2,
              "name_ru": "Карась золотой",
              "image_res_id": 2131231099,
              "unit_weight_grams": 500,
              "unit_price_coins": 77,
              "strength": 3,
              "stamina": 7,
              "intelligence": 3,
              "aggression": 4
            }
          ]
        }
        """
        let baitsJSON = """
        {
          "items": [
            { "id": 1, "name_ru": "червь", "image_res_id": 2131230950, "stock_amount": 30, "price_coins": 30 },
            { "id": 2, "name_ru": "хлеб", "image_res_id": 2131230961, "stock_amount": 40, "price_coins": 50 }
          ]
        }
        """
        let rodsJSON = """
        {
          "items": [
            { "id": 1, "name": "fish small", "max_weight_kg_db": 3, "price_coins": 100 },
            { "id": 2, "name": "kosrep", "max_weight_kg_db": 5, "price_coins": 2000 },
            { "id": 13, "name": "dasf", "max_weight_kg_db": 1900, "price_coins": 0 }
          ]
        }
        """
        let linesJSON = """
        {
          "items": [
            { "id": 1, "name": "small", "max_weight_kg_db": 3, "price_coins": 100, "stock_length_meters": 100 },
            { "id": 16, "name": "big fish", "max_weight_kg_db": 2150, "price_coins": 0, "stock_length_meters": 100 }
          ]
        }
        """
        let coilsJSON = """
        {
          "items": [
            { "id": 1, "name": "gert", "bearing_count": 1, "price_coins": 100 },
            { "id": 10, "name": "wectern", "bearing_count": 10, "price_coins": 0 }
          ]
        }
        """
        let hooksJSON = """
        {
          "items": [
            { "id": 1, "name": "fish 1", "stock_amount": 5, "price_coins": 100 }
          ]
        }
        """
        let couponsJSON = """
        {
          "items": [
            { "id": 1, "name_ru": "Путевой купон", "day_count": 1, "price_coins": 150000, "dn_duration_units": 288 }
          ]
        }
        """
        let achievementsJSON = """
        {
          "items": [
            { "id": 1, "image_res_id": 2131231372, "initial_score": 0, "initial_level": 0, "initial_nag": 0, "nagsize_reward_param": 200 },
            { "id": 2, "image_res_id": 2131231378, "initial_score": 0, "initial_level": 0, "initial_nag": 0, "nagsize_reward_param": 700 }
          ]
        }
        """
        let questsJSON = """
        {
          "items": [
            {
              "id": 1,
              "type": 2,
              "fish_ids_raw": "0",
              "bait_ids_raw": "1,2,12",
              "target_counts_raw": "0",
              "target_weights_raw": "20000",
              "required_category_rank": 0,
              "rewards_raw": "200,150",
              "initial_res": "null",
              "initial_made": 0
            }
          ]
        }
        """
        let pondsJSON = """
        {
          "ponds": [
            {
              "pond_data_id": 0,
              "ui_display_index": 0,
              "chat_pond_id": 1,
              "name_ru": "кедровый остров",
              "name_en": "cedar island",
              "name_de": "Zederinsel",
              "name_es": "isla de cedro",
              "name_pt": "ilha do cedro",
              "required_rank": 0,
              "requires_coupon": false,
              "pond_image_res_id": 2131231519,
              "pond_image_name": "pond_1",
              "big_pond_image_res_id": 2131231532,
              "big_pond_image_name": "pond_1_big",
              "bait_Slots_and_catches": [
                {
                  "bait_slot_index": 0,
                  "bait_index_0based": 0,
                  "bait_db_id": 1,
                  "catchable_fishes": [
                    { "fish_index_0based": 0, "fish_db_id": 1 }
                  ]
                }
              ],
              "species_weights": [
                { "fish_index_0based": 0, "fish_db_id": 1, "min_weight_grams": 50, "max_weight_grams": 2450 }
              ],
              "time_of_day_bite_factors": {
                "morning": [
                  {
                    "bait_slot_index": 0,
                    "bait_index_0based": 0,
                    "fish_probabilities": [
                      { "fish_index_0based": 0, "fish_db_id": 1, "bite_probability_percent": 50 }
                    ]
                  }
                ],
                "afternoon": [],
                "evening": [],
                "night": []
              }
            }
          ]
        }
        """
        let progressionJSON = """
        {
          "rank_progression": [
            { "rank_index_1based": 1, "required_experience": 500 },
            { "rank_index_1based": 2, "required_experience": 1500 }
          ]
        }
        """

        let files: [(String, String)] = [
            ("fishes.json", fishesJSON),
            ("baits.json", baitsJSON),
            ("fishing_rods.json", rodsJSON),
            ("fishing_lines.json", linesJSON),
            ("coils.json", coilsJSON),
            ("hooks.json", hooksJSON),
            ("coupons.json", couponsJSON),
            ("achievements.json", achievementsJSON),
            ("quests.json", questsJSON),
            ("ponds.json", pondsJSON),
            ("progression_and_balance.json", progressionJSON)
        ]
        for (name, content) in files {
            try content.data(using: .utf8)!.write(to: dir.appendingPathComponent(name))
        }
    }

    // MARK: - 1. Empty Database Creation & Schema Migration v21

    func testEmptyDatabaseCreationAndSchemaVersion21() throws {
        let conn = try SQLiteConnection(path: dbPath)
        XCTAssertEqual(try conn.userVersion(), 0)

        try DatabaseSchemaAndMigrations.migrateIfNeeded(on: conn)
        XCTAssertEqual(try conn.userVersion(), 21)

        for refTable in DatabaseSchemaAndMigrations.referenceTableNames {
            XCTAssertTrue(try conn.tableExists(refTable), "Missing reference table \(refTable)")
        }
        for userTable in DatabaseSchemaAndMigrations.playerMutableTableNames {
            XCTAssertTrue(try conn.tableExists(userTable), "Missing player table \(userTable)")
        }

        // Verify legacy records migration (`bait_image` -> `bait_id`)
        let legacyConn = try SQLiteConnection(path: ":memory:")
        try legacyConn.execute("""
        CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fish_name VARCHAR NOT NULL,
            weight INTEGER NOT NULL,
            bait_image INTEGER NOT NULL
        );
        INSERT INTO records (id, fish_name, weight, bait_image) VALUES (1, 'Карась', 1200, 3);
        """)
        try DatabaseSchemaAndMigrations.migrateIfNeeded(on: legacyConn)
        XCTAssertTrue(try legacyConn.columnExists(table: "records", column: "bait_id"))
        XCTAssertEqual(try legacyConn.scalarInt("SELECT weight FROM records WHERE id = 1;"), 1200)
        XCTAssertEqual(try legacyConn.scalarInt("SELECT bait_id FROM records WHERE id = 1;"), 3)
    }

    // MARK: - 2. Reference Data Import & Idempotency on Repeated Launch

    func testReferenceDataImportAndIdempotency() throws {
        try writeMinimalJSONFixtures(to: tempDirURL)

        let conn = try SQLiteConnection(path: dbPath)
        try DatabaseSchemaAndMigrations.migrateIfNeeded(on: conn)

        let catalog = ReferenceCatalogStore(connection: conn, installationUuid: testUuid)
        let repo = PlayerStateRepository(connection: conn, catalog: catalog, installationUuid: testUuid)

        let summary1 = try catalog.importFromJSONDirectory(tempDirURL, nowMs: 0)
        try repo.initializeNewPlayerIfNeeded(nowMs: 0)

        XCTAssertEqual(summary1.fishesCount, 2)
        XCTAssertEqual(summary1.baitsCount, 2)
        XCTAssertEqual(summary1.rodsCount, 3)

        // Verify exact reference MD5 of Fish #1 ('Карась') against fishing2_reference.db
        let fishes = try catalog.loadFishCatalogById()
        XCTAssertEqual(fishes[1]?.name, "Карась")
        XCTAssertTrue(fishes[1]?.md5Valid == true)
        let fish1Md5 = FishingChecksum.fishMd5(
            id: 1,
            unitWeight: 500,
            unitPrice: 55,
            strength: 3,
            stamina: 6,
            intelligence: 2,
            aggression: 4,
            installationUuid: testUuid
        )
        XCTAssertEqual(fish1Md5, "dbff86161e6c460dd3537ed7d7a492d2")

        // Verify initial player profile (`balance = 500`, `experience = 0`, `category = 0`, exact MD5)
        let profile = try repo.loadPlayerProfile()
        XCTAssertEqual(profile.balance, 500)
        XCTAssertEqual(profile.experience, 0)
        XCTAssertEqual(profile.category, 0)
        XCTAssertEqual(profile.md5, "6c7143f2ccfddc7db04663bf0bbfba63")
        XCTAssertTrue(try repo.verifyPlayerProfileIntegrity())

        // Mutate player's record and balance, then re-run import + initializeNewPlayerIfNeeded
        try conn.run("UPDATE records SET weight = 999, bait_id = 1 WHERE id = 1;")
        let summary2 = try catalog.importFromJSONDirectory(tempDirURL, nowMs: 12345)
        try repo.initializeNewPlayerIfNeeded(nowMs: 12345)

        XCTAssertEqual(summary2, summary1)
        XCTAssertEqual(try conn.scalarInt("SELECT COUNT(*) FROM fishes;"), 2)
        XCTAssertEqual(try conn.scalarInt("SELECT COUNT(*) FROM user_data;"), 1)
        XCTAssertEqual(try conn.scalarInt("SELECT COUNT(*) FROM user_tackles;"), 1)
        // Player's personal record must NOT be overwritten by repeated import!
        XCTAssertEqual(try repo.loadPersonalRecord(fishId1Based: 1)?.weightGrams, 999)
    }

    // MARK: - 3. App Restart Persistence (Closing and Reopening SQLite File)

    func testPersistenceAcrossAppRestart() throws {
        try writeMinimalJSONFixtures(to: tempDirURL)

        var purchasedRodId = 0
        var purchasedBaitId = 0

        do {
            let conn1 = try SQLiteConnection(path: dbPath)
            try DatabaseSchemaAndMigrations.migrateIfNeeded(on: conn1)
            let catalog1 = ReferenceCatalogStore(connection: conn1, installationUuid: testUuid)
            let repo1 = PlayerStateRepository(connection: conn1, catalog: catalog1, installationUuid: testUuid)

            try catalog1.importFromJSONDirectory(tempDirURL, nowMs: 1000)
            try repo1.initializeNewPlayerIfNeeded(nowMs: 1000)

            let rod = try repo1.buyFishingRod(baseRodId: 1, nowMs: 2000)
            let line = try repo1.buyFishingLine(baseLineId: 1, nowMs: 2000)
            let coil = try repo1.buyCoil(baseCoilId: 1, nowMs: 2000)
            let hook = try repo1.buyHook(baseHookId: 1)
            let bait = try repo1.buyBait(baseBaitId: 1)

            purchasedRodId = rod.id
            purchasedBaitId = bait.id

            try repo1.saveTackleSlots(
                UserTackleSlotRecord(
                    id: 1,
                    fishingRodId: rod.id,
                    fishingLineId: line.id,
                    coilId: coil.id,
                    hookId: hook.id,
                    baitId: bait.id
                )
            )
            conn1.close()
        }

        // Simulate app restart with a fresh SQLiteConnection on the same file
        let conn2 = try SQLiteConnection(path: dbPath)
        try DatabaseSchemaAndMigrations.migrateIfNeeded(on: conn2)
        let catalog2 = ReferenceCatalogStore(connection: conn2, installationUuid: testUuid)
        let repo2 = PlayerStateRepository(connection: conn2, catalog: catalog2, installationUuid: testUuid)
        try repo2.initializeNewPlayerIfNeeded(nowMs: 5000)

        let profileAfterRestart = try repo2.loadPlayerProfile()
        // 500 - (100 rod + 100 line + 100 coil + 100 hook + 30 bait) = 70 coins
        XCTAssertEqual(profileAfterRestart.balance, 70)
        XCTAssertTrue(try repo2.verifyPlayerProfileIntegrity())

        let tackleAfterRestart = try repo2.loadAssembledTackle()
        XCTAssertTrue(tackleAfterRestart.isComplete)
        XCTAssertEqual(tackleAfterRestart.userRod?.id, purchasedRodId)
        XCTAssertEqual(tackleAfterRestart.userBait?.id, purchasedBaitId)
        XCTAssertEqual(tackleAfterRestart.userBait?.amount, 30)
    }

    // MARK: - 4. Shop, Tackle Wear/Breakage, Catch, and Fish Sale Transactions

    func testShopStackingWearCatchAndSellTransactions() throws {
        try writeMinimalJSONFixtures(to: tempDirURL)

        let conn = try SQLiteConnection(path: dbPath)
        try DatabaseSchemaAndMigrations.migrateIfNeeded(on: conn)
        let catalog = ReferenceCatalogStore(connection: conn, installationUuid: testUuid)
        let repo = PlayerStateRepository(connection: conn, catalog: catalog, installationUuid: testUuid)

        try catalog.importFromJSONDirectory(tempDirURL, nowMs: 1000)
        try repo.initializeNewPlayerIfNeeded(nowMs: 1000)

        // Starter kit purchase
        let rod = try repo.buyFishingRod(baseRodId: 1, nowMs: 1100)
        let line = try repo.buyFishingLine(baseLineId: 1, nowMs: 1100)
        let coil = try repo.buyCoil(baseCoilId: 1, nowMs: 1100)
        let hook = try repo.buyHook(baseHookId: 1)
        let bait1 = try repo.buyBait(baseBaitId: 1)
        // Buying the same bait stacks onto the same `user_baits` row (`30 + 30 = 60`)
        let bait2 = try repo.buyBait(baseBaitId: 1)
        XCTAssertEqual(bait1.id, bait2.id)
        XCTAssertEqual(bait2.amount, 60)
        XCTAssertEqual(try repo.loadPlayerProfile().balance, 40)

        try repo.saveTackleSlots(
            UserTackleSlotRecord(
                id: 1,
                fishingRodId: rod.id,
                fishingLineId: line.id,
                coilId: coil.id,
                hookId: hook.id,
                baitId: bait2.id
            )
        )

        // Simulate catching a 1,000g Crucian Carp ('Карась', unitWeight=500, unitPrice=55 -> price=110 coins)
        let fishes = try catalog.loadFishCatalogById()
        let caughtCarp = CaughtUserFish(
            fish: fishes[1]!,
            weightGrams: 1000,
            pondIndex: 0,
            baitIndex: 0,
            rodWeightKg: 3,
            catchTimeMs: 3000
        )
        let catchResult = try repo.recordCaughtFish(caughtCarp, nowMs: 3000)
        XCTAssertTrue(catchResult.storedInFishnet)
        XCTAssertEqual(catchResult.fishnetCountAfter, 1)
        XCTAssertTrue(catchResult.isNewPersonalRecord)
        XCTAssertEqual(try repo.loadPersonalRecord(fishId1Based: 1)?.weightGrams, 1000)

        // Simulate tackle wear and line breakage (line length drops to 0, rod breaks)
        var tackle = try repo.loadAssembledTackle()
        tackle.userBait?.amount = 59
        tackle.userCoil?.strength = 99
        tackle.userLine?.length = 0 // broken/exhausted line
        tackle.userRod = nil        // broken rod
        try repo.syncAssembledTackleAfterFight(tackle)

        let reloadedTackle = try repo.loadAssembledTackle()
        XCTAssertNil(reloadedTackle.userRod)
        XCTAssertNil(reloadedTackle.userLine)
        XCTAssertEqual(reloadedTackle.userCoil?.strength, 99)
        XCTAssertEqual(reloadedTackle.userBait?.amount, 59)
        XCTAssertEqual(try repo.listUserRods().count, 0)
        XCTAssertEqual(try repo.listUserLines().count, 0)

        // Sell all fish in fishnet
        let saleResult = try repo.sellAllFish(nowMs: 4000)
        XCTAssertEqual(saleResult.soldFishCount, 1)
        XCTAssertEqual(saleResult.coinsEarned, 110)
        XCTAssertEqual(saleResult.newBalance, 150) // 40 + 110
        XCTAssertEqual(try repo.listFishnetEntries().count, 0)
        XCTAssertTrue(try catalog.verifyDataSign(.userFishes))
        XCTAssertTrue(try repo.verifyPlayerProfileIntegrity())
    }

    // MARK: - 5. Transaction Rollback on Error

    func testTransactionRollbackOnFailureLeavesStateUnchanged() throws {
        try writeMinimalJSONFixtures(to: tempDirURL)

        let conn = try SQLiteConnection(path: dbPath)
        try DatabaseSchemaAndMigrations.migrateIfNeeded(on: conn)
        let catalog = ReferenceCatalogStore(connection: conn, installationUuid: testUuid)
        let repo = PlayerStateRepository(connection: conn, catalog: catalog, installationUuid: testUuid)

        try catalog.importFromJSONDirectory(tempDirURL, nowMs: 1000)
        try repo.initializeNewPlayerIfNeeded(nowMs: 1000)

        // 1. Attempt to buy an expensive rod (`id = 2`, price = 2000) with only 500 coins
        XCTAssertThrowsError(try repo.buyFishingRod(baseRodId: 2, nowMs: 2000)) { error in
            XCTAssertEqual(
                error as? PlayerPersistenceError,
                .insufficientBalance(required: 2000, available: 500)
            )
        }
        XCTAssertEqual(try repo.loadPlayerProfile().balance, 500)
        XCTAssertEqual(try repo.listUserRods().count, 0)

        // 2. Attempt a multi-step composite transaction where the second step fails — verify first step is rolled back!
        enum SimulatedCrash: Error { case boom }
        XCTAssertThrowsError(try conn.transaction {
            _ = try repo.buyFishingRod(baseRodId: 1, nowMs: 2500)
            XCTAssertEqual(try repo.loadPlayerProfile().balance, 400)
            XCTAssertEqual(try repo.listUserRods().count, 1)
            throw SimulatedCrash.boom
        })

        // Both the rod insertion and the balance deduction must be completely rolled back!
        XCTAssertEqual(try repo.loadPlayerProfile().balance, 500)
        XCTAssertEqual(try repo.listUserRods().count, 0)
        XCTAssertTrue(try repo.verifyPlayerProfileIntegrity())
    }
}
