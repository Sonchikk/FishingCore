import Foundation

/// Manages SQLite DDL creation, separation between immutable reference catalog tables and
/// mutable player state tables, and idempotent schema migrations up to version 21
/// (`DatabaseHelper.DATABASE_VERSION = 21`).
public enum DatabaseSchemaAndMigrations: Sendable {
    public static let currentSchemaVersion: Int = 21

    public static let referenceTableNames: [String] = [
        "fishes",
        "baits",
        "fishing_rods",
        "fishing_lines",
        "coils",
        "hooks",
        "coupons",
        "ref_ponds",
        "ref_pond_bait_catches",
        "ref_pond_species_weights",
        "ref_pond_time_factors",
        "ref_rank_thresholds"
    ]

    public static let playerMutableTableNames: [String] = [
        "user_data",
        "user_tackles",
        "user_fishing_rods",
        "user_coils",
        "user_fishing_lines",
        "user_hooks",
        "user_baits",
        "user_coupon",
        "user_fishes",
        "user_task",
        "user_task_data",
        "user_quest_data",
        "user_tours",
        "records",
        "achievements",
        "quests",
        "data_signs",
        "player_runtime_counters"
    ]

    /// Creates or migrates all reference and player tables idempotently inside an atomic transaction.
    public static func migrateIfNeeded(on connection: SQLiteConnection) throws {
        try connection.transaction {
            let existingVersion = try connection.userVersion()

            try createReferenceTables(on: connection)
            try createPlayerStateTables(on: connection)
            try applySchemaUpgrades(fromVersion: existingVersion, on: connection)

            if existingVersion < currentSchemaVersion {
                try connection.setUserVersion(currentSchemaVersion)
            }
        }
    }

    // MARK: - 1. Immutable Reference Catalog Tables

    public static func createReferenceTables(on connection: SQLiteConnection) throws {
        try connection.execute("""
        CREATE TABLE IF NOT EXISTS fishes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR NOT NULL,
            image INTEGER NOT NULL,
            unit_weight INTEGER NOT NULL,
            unit_price INTEGER NOT NULL,
            strength INTEGER NOT NULL,
            stamina INTEGER NOT NULL,
            intelligence INTEGER NOT NULL,
            aggression INTEGER NOT NULL,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS baits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR NOT NULL,
            image INTEGER NOT NULL,
            stock_amount INTEGER NOT NULL,
            price INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS fishing_rods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR NOT NULL,
            weight INTEGER NOT NULL,
            price INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS fishing_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR NOT NULL,
            weight INTEGER NOT NULL,
            price INTEGER NOT NULL,
            stock_length INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS coils (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR NOT NULL,
            bearing_count INTEGER NOT NULL,
            price INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS hooks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR NOT NULL,
            stock_amount INTEGER NOT NULL,
            price INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS coupons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR NOT NULL,
            day_count INTEGER NOT NULL,
            price INTEGER NOT NULL,
            dn INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ref_ponds (
            pond_data_id INTEGER PRIMARY KEY,
            ui_display_index INTEGER NOT NULL,
            chat_pond_id INTEGER NOT NULL,
            name_ru TEXT NOT NULL,
            name_en TEXT NOT NULL,
            name_de TEXT NOT NULL,
            name_es TEXT NOT NULL,
            name_pt TEXT NOT NULL,
            required_rank INTEGER NOT NULL,
            requires_coupon INTEGER NOT NULL,
            pond_image_res_id INTEGER NOT NULL,
            pond_image_name TEXT NOT NULL,
            big_pond_image_res_id INTEGER NOT NULL,
            big_pond_image_name TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS ref_pond_bait_catches (
            pond_data_id INTEGER NOT NULL,
            bait_slot_index INTEGER NOT NULL,
            bait_index_0based INTEGER NOT NULL,
            bait_db_id INTEGER NOT NULL,
            catch_order_index INTEGER NOT NULL,
            fish_index_0based INTEGER NOT NULL,
            fish_db_id INTEGER NOT NULL,
            PRIMARY KEY (pond_data_id, bait_slot_index, catch_order_index)
        );

        CREATE TABLE IF NOT EXISTS ref_pond_species_weights (
            pond_data_id INTEGER NOT NULL,
            fish_index_0based INTEGER NOT NULL,
            fish_db_id INTEGER NOT NULL,
            min_weight_grams INTEGER NOT NULL,
            max_weight_grams INTEGER NOT NULL,
            PRIMARY KEY (pond_data_id, fish_index_0based)
        );

        CREATE TABLE IF NOT EXISTS ref_pond_time_factors (
            pond_data_id INTEGER NOT NULL,
            day_period TEXT NOT NULL,
            bait_slot_index INTEGER NOT NULL,
            bait_index_0based INTEGER NOT NULL,
            entry_index INTEGER NOT NULL,
            fish_index_0based INTEGER NOT NULL,
            fish_db_id INTEGER NOT NULL,
            probability_percent INTEGER NOT NULL,
            PRIMARY KEY (pond_data_id, day_period, bait_slot_index, entry_index)
        );

        CREATE TABLE IF NOT EXISTS ref_rank_thresholds (
            rank_index_1based INTEGER PRIMARY KEY,
            required_experience INTEGER NOT NULL
        );
        """)
    }

    // MARK: - 2. Mutable Player State Tables

    public static func createPlayerStateTables(on connection: SQLiteConnection) throws {
        try connection.execute("""
        CREATE TABLE IF NOT EXISTS user_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            login VARCHAR NOT NULL DEFAULT '',
            password VARCHAR NOT NULL DEFAULT '',
            balance INTEGER NOT NULL DEFAULT 500,
            experience INTEGER NOT NULL DEFAULT 0,
            category INTEGER NOT NULL DEFAULT 0,
            date BIGINT NOT NULL DEFAULT 0,
            md5 VARCHAR NOT NULL DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS user_tackles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fishing_rod_id INTEGER NOT NULL DEFAULT -2147483648,
            fishing_line_id INTEGER NOT NULL DEFAULT -2147483648,
            coil_id INTEGER NOT NULL DEFAULT -2147483648,
            hook_id INTEGER NOT NULL DEFAULT -2147483648,
            bait_id INTEGER NOT NULL DEFAULT -2147483648
        );

        CREATE TABLE IF NOT EXISTS user_fishing_rods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fishing_rod INTEGER NOT NULL,
            strength INTEGER NOT NULL,
            date BIGINT NOT NULL,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_coils (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            coil INTEGER NOT NULL,
            strength INTEGER NOT NULL,
            date BIGINT NOT NULL,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_fishing_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fishing_line INTEGER NOT NULL,
            length INTEGER NOT NULL,
            date BIGINT NOT NULL,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_hooks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hook INTEGER NOT NULL,
            amount INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_baits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bait INTEGER NOT NULL,
            amount INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_coupon (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            coupon INTEGER NOT NULL,
            time INTEGER NOT NULL,
            date BIGINT NOT NULL,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_fishes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fish INTEGER NOT NULL,
            weight INTEGER NOT NULL,
            bait_index INTEGER NOT NULL DEFAULT 0,
            pond_index INTEGER NOT NULL DEFAULT 0,
            rod_weight INTEGER NOT NULL DEFAULT 0,
            catch_time BIGINT NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS user_task (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type INTEGER NOT NULL,
            fish INTEGER NOT NULL,
            bait INTEGER NOT NULL DEFAULT 0,
            num INTEGER NOT NULL,
            weight INTEGER NOT NULL,
            total_weight INTEGER NOT NULL DEFAULT 0,
            date BIGINT NOT NULL DEFAULT 0,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_task_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task INTEGER NOT NULL DEFAULT 0,
            num INTEGER NOT NULL,
            weight INTEGER NOT NULL,
            made INTEGER NOT NULL DEFAULT 0,
            date BIGINT NOT NULL DEFAULT 0,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_quest_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task INTEGER NOT NULL,
            num VARCHAR NOT NULL,
            weight VARCHAR NOT NULL,
            made INTEGER NOT NULL,
            date BIGINT NOT NULL,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS user_tours (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tour INTEGER NOT NULL DEFAULT 0,
            type VARCHAR NOT NULL DEFAULT '',
            "begin" BIGINT NOT NULL DEFAULT 0,
            finish BIGINT NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fish_name VARCHAR NOT NULL,
            weight INTEGER NOT NULL DEFAULT 0,
            bait_id INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS achievements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image INTEGER NOT NULL,
            score INTEGER NOT NULL DEFAULT 0,
            level INTEGER NOT NULL DEFAULT 0,
            nag INTEGER NOT NULL DEFAULT 0,
            nagsize INTEGER NOT NULL,
            date BIGINT NOT NULL DEFAULT 0,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS quests (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type INTEGER NOT NULL,
            fish VARCHAR NOT NULL,
            bait VARCHAR NOT NULL,
            num VARCHAR NOT NULL,
            weight VARCHAR NOT NULL,
            cat INTEGER NOT NULL,
            nag VARCHAR NOT NULL,
            res VARCHAR NOT NULL DEFAULT 'null',
            made INTEGER NOT NULL DEFAULT 0,
            date BIGINT NOT NULL DEFAULT 0,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS data_signs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date BIGINT NOT NULL DEFAULT 0,
            md5 VARCHAR NOT NULL
        );

        CREATE TABLE IF NOT EXISTS player_runtime_counters (
            counter_key TEXT PRIMARY KEY,
            counter_value INTEGER NOT NULL DEFAULT 0
        );
        """)
    }

    // MARK: - 3. Schema Upgrades & Compatibility Migrations (DatabaseHelper.onUpgrade + Reference DB)

    private static func applySchemaUpgrades(fromVersion: Int, on connection: SQLiteConnection) throws {
        // 1. Original DatabaseHelper.onUpgrade migration: records.bait_image -> records.bait_id
        if try connection.tableExists("records"),
           !(try connection.columnExists(table: "records", column: "bait_id")),
           (try connection.columnExists(table: "records", column: "bait_image")) {
            try connection.execute("""
            ALTER TABLE records RENAME TO ffftemp;
            CREATE TABLE records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                fish_name VARCHAR NOT NULL,
                weight INTEGER NOT NULL DEFAULT 0,
                bait_id INTEGER NOT NULL DEFAULT 0
            );
            INSERT INTO records (fish_name, bait_id, weight, id)
                SELECT fish_name, bait_image, weight, id FROM ffftemp;
            DROP TABLE IF EXISTS ffftemp;
            """)
        }

        // 2. Ensure `user_fishes` has all 6 OrmLite UserFish columns (`bait_index`, `pond_index`, `rod_weight`, `catch_time`)
        // in case the database was initialized from the earlier Phase 2 reference schema.
        let userFishExtraColumns: [(String, String)] = [
            ("bait_index", "INTEGER NOT NULL DEFAULT 0"),
            ("pond_index", "INTEGER NOT NULL DEFAULT 0"),
            ("rod_weight", "INTEGER NOT NULL DEFAULT 0"),
            ("catch_time", "BIGINT NOT NULL DEFAULT 0")
        ]
        for (colName, colDef) in userFishExtraColumns {
            if !(try connection.columnExists(table: "user_fishes", column: colName)) {
                try connection.execute("ALTER TABLE user_fishes ADD COLUMN \(colName) \(colDef);")
            }
        }

        // 3. Compatibility bridge for camelCase columns in Phase 2 `fishing2_reference.db`
        try migrateColumnIfNeeded(
            on: connection,
            table: "fishes",
            legacyColumn: "unitWeight",
            targetColumn: "unit_weight",
            colType: "INTEGER NOT NULL DEFAULT 0"
        )
        try migrateColumnIfNeeded(
            on: connection,
            table: "fishes",
            legacyColumn: "unitPrice",
            targetColumn: "unit_price",
            colType: "INTEGER NOT NULL DEFAULT 0"
        )
        try migrateColumnIfNeeded(
            on: connection,
            table: "baits",
            legacyColumn: "stockAmount",
            targetColumn: "stock_amount",
            colType: "INTEGER NOT NULL DEFAULT 0"
        )
        try migrateColumnIfNeeded(
            on: connection,
            table: "coils",
            legacyColumn: "bearingCount",
            targetColumn: "bearing_count",
            colType: "INTEGER NOT NULL DEFAULT 1"
        )
        try migrateColumnIfNeeded(
            on: connection,
            table: "coupons",
            legacyColumn: "dayCount",
            targetColumn: "day_count",
            colType: "INTEGER NOT NULL DEFAULT 1"
        )
        try migrateColumnIfNeeded(
            on: connection,
            table: "fishing_lines",
            legacyColumn: "stockLength",
            targetColumn: "stock_length",
            colType: "INTEGER NOT NULL DEFAULT 100"
        )
        try migrateColumnIfNeeded(
            on: connection,
            table: "hooks",
            legacyColumn: "stockAmount",
            targetColumn: "stock_amount",
            colType: "INTEGER NOT NULL DEFAULT 5"
        )
    }

    private static func migrateColumnIfNeeded(
        on connection: SQLiteConnection,
        table: String,
        legacyColumn: String,
        targetColumn: String,
        colType: String
    ) throws {
        let hasTarget = try connection.columnExists(table: table, column: targetColumn)
        let hasLegacy = try connection.columnExists(table: table, column: legacyColumn)
        if !hasTarget && hasLegacy {
            try connection.execute("ALTER TABLE \(table) ADD COLUMN \(targetColumn) \(colType);")
            try connection.execute("UPDATE \(table) SET \(targetColumn) = \(legacyColumn);")
        }
    }
}
