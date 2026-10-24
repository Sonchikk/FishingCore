import Foundation
import Combine
import FishingCore
import FishingDatabase

/// Top-level navigation destinations for the iOS port of «Рыбалка для друзей» v1.81.
public enum AppNavigationTab: String, CaseIterable, Sendable, Identifiable {
    case fishingPond = "pond"
    case baseHub = "base"
    case shop = "shop"
    case inventory = "inventory"
    case fishnet = "fishnet"
    case progress = "progress"
    case online = "online"

    public var id: String { rawValue }

    public var titleRu: String {
        switch self {
        case .fishingPond: return "Водоём"
        case .baseHub: return "База"
        case .shop: return "Магазин"
        case .inventory: return "Рюкзак"
        case .fishnet: return "Садок"
        case .progress: return "Прогресс"
        case .online: return "Онлайн"
        }
    }

    public var systemIconName: String {
        switch self {
        case .fishingPond: return "water.waves"
        case .baseHub: return "map.fill"
        case .shop: return "cart.fill"
        case .inventory: return "backpack.fill"
        case .fishnet: return "basket.fill"
        case .progress: return "trophy.fill"
        case .online: return "globe"
        }
    }
}

/// Modal alerts corresponding to `GameView$b` callbacks (`GameActivity` runnables) and shop/catch dialogs (`C0.d`).
public enum FishingModalAlert: Equatable, Sendable, Identifiable {
    case missingTackle(missingComponents: String)
    case catchDialog(
        fish: CaughtUserFish,
        result: CatchTransactionResult,
        isLucky25: Bool,
        isRepdigit: Bool,
        isCleanerTrash: Bool
    )
    case lineBroken
    case rodBroken
    case coilBroken
    case fishEscaped
    case missedBiteDuringSleep
    case exactAlarmPermissionRequired
    case fishSold(result: FishSaleTransactionResult)
    case operationError(message: String)

    public var id: String {
        switch self {
        case .missingTackle(let msg): return "missingTackle_\(msg)"
        case .catchDialog(let f, _, _, _, _): return "catch_\(f.fish.id)_\(f.weightGrams)_\(f.catchTimeMs)"
        case .lineBroken: return "lineBroken"
        case .rodBroken: return "rodBroken"
        case .coilBroken: return "coilBroken"
        case .fishEscaped: return "fishEscaped"
        case .missedBiteDuringSleep: return "missedBiteDuringSleep"
        case .exactAlarmPermissionRequired: return "exactAlarmPermissionRequired"
        case .fishSold(let res): return "fishSold_\(res.soldFishCount)_\(res.newBalance)"
        case .operationError(let msg): return "error_\(msg)"
        }
    }

    public var titleRu: String {
        switch self {
        case .missingTackle: return "Снасть не собрана!"
        case .catchDialog(let fish, let result, _, _, _):
            return result.isNewPersonalRecord ? "Новый рекорд! \(fish.fish.name)" : "Поймана рыба: \(fish.fish.name)"
        case .lineBroken: return "Леска оборвалась"
        case .rodBroken: return "Удочка сломалась"
        case .coilBroken: return "Катушка сломалась"
        case .fishEscaped: return "Рыба сорвалась"
        case .missedBiteDuringSleep: return "Прозевали поклевку"
        case .exactAlarmPermissionRequired: return "Требуется разрешение будильника"
        case .fishSold: return "Улов продан"
        case .operationError: return "Внимание"
        }
    }

    public var messageRu: String {
        switch self {
        case .missingTackle(let missing):
            return "Не хватает: \(missing)"
        case .catchDialog(let fish, let result, let isLucky25, let isRepdigit, let isCleanerTrash):
            var lines: [String] = [
                "Вес: \(fish.weightGrams) г",
                "Оценка: \(fish.sellingPriceCoins) монет",
                "Опыт: +\(result.experienceAwarded) XP (всего \(result.totalExperienceAfter) XP, разряд \(result.categoryRankAfter))",
                result.storedInFishnet
                    ? "В садке: \(result.fishnetCountAfter) / \(PlayerStateRepository.maxFishnetCapacity)"
                    : "Садок полон (50/50)! Рыба отпущена."
            ]
            if result.isNewPersonalRecord {
                lines.append("🏆 Личный рекорд вида обновлён!")
            }
            if isLucky25 {
                lines.append("🍀 Счастливый вес (сумма цифр = 25)!")
            }
            if isRepdigit {
                lines.append("🎰 Редкий вес (одинаковые цифры)!")
            }
            if isCleanerTrash {
                lines.append("🧹 Вклад в достижение «Чистильщик»!")
            }
            return lines.joined(separator: "\n")
        case .lineBroken:
            return "Рыба оборвала леску (-10 м лески, потеряны крючок и наживка)."
        case .rodBroken:
            return "Критический перегруз! Леска оказалась крепче удилища — удочка сломалась."
        case .coilBroken:
            return "Вес рыбы превысил предел прочности механизма — катушка сломалась."
        case .fishEscaped:
            return "Рыба сошла с крючка и съела наживку."
        case .missedBiteDuringSleep:
            return "Слишком позднее пробуждение — рыба уже ушла."
        case .exactAlarmPermissionRequired:
            return "Для режима фонового будильника требуется разрешение точных уведомлений."
        case .fishSold(let res):
            return "Продано рыб: \(res.soldFishCount) шт.\nВыручка: +\(res.coinsEarned) монет\nТекущий баланс: \(res.newBalance) монет"
        case .operationError(let msg):
            return msg
        }
    }
}

/// Main integration coordinator connecting SwiftUI screens with `FishingCore` (`FishingStateMachine`,
/// `GameClockTimer`), `FishingDatabase` (`SQLiteConnection`, `ReferenceCatalogStore`, `PlayerStateRepository`,
/// `QuestAndAchievementEngine`), and the 3-pass Metal water renderer (`WaterMetalRenderer`).
@MainActor
public final class FishingAppCoordinator: ObservableObject {
    public let connection: SQLiteConnection
    public let catalog: ReferenceCatalogStore
    public let repository: PlayerStateRepository
    public let balanceTables: BalanceTables

    private var isLoadingPersistedSettings: Bool = false

    @Published public var selectedTab: AppNavigationTab = .fishingPond {
        didSet {
            audioHaptics.isOnPondScreen = (selectedTab == .fishingPond)
            if selectedTab == .fishingPond {
                audioHaptics.syncAmbientTrack(
                    pondIndex: selectedPondIndex,
                    hour: gameClock.hour,
                    isPondScreenVisible: true
                )
            } else {
                audioHaptics.setReelLooping(false)
            }
        }
    }
    @Published public var selectedPondIndex: Int = 0 {
        didSet {
            if !isLoadingPersistedSettings {
                savePersistedSettingsToDatabase()
            }
        }
    }
    @Published public private(set) var availablePonds: [PondCatalogItem] = []

    /// Corresponds to `SharedPreferences("FFF-ANDROID")["WATER_SHADER"]` (`GameActivity.b0()`).
    @Published public var isWaterShaderEnabled: Bool = true {
        didSet {
            if !isLoadingPersistedSettings {
                savePersistedSettingsToDatabase()
            }
        }
    }
    /// Corresponds to `SharedPreferences("pond_fons_pref")["pond_fon_set_" + pondIndex]` (`GameActivity.b0()`).
    @Published public var pondBackgroundSetIndex: Int = 1 {
        didSet {
            if !isLoadingPersistedSettings {
                savePersistedSettingsToDatabase()
            }
        }
    }

    /// Controls visibility of developer debug tools on the pond screen (hidden by default for normal gameplay).
    @Published public var isDebugOverlayEnabled: Bool = false {
        didSet {
            if !isLoadingPersistedSettings {
                savePersistedSettingsToDatabase()
            }
        }
    }

    /// Corresponds to `SharedPreferences("FFF-ANDROID")["CHECKMODE"]` (`GameView.q` background bite alarm).
    @Published public var checkModeEnabled: Bool = false {
        didSet {
            if !isLoadingPersistedSettings {
                if checkModeEnabled {
                    biteNotificationScheduler.requestAuthorization()
                } else if biteNotificationScheduler.isNotificationPending {
                    biteNotificationScheduler.cancelPendingBiteAlarm()
                }
                savePersistedSettingsToDatabase()
            }
        }
    }

    /// Corresponds to `SharedPreferences("FFF-ANDROID")["ONLINE_MODE"]` (`FishingService$d`).
    @Published public var onlineModeEnabled: Bool = false {
        didSet {
            if !isLoadingPersistedSettings {
                savePersistedSettingsToDatabase()
            }
        }
    }

    /// Persisted online credentials (`user_data.login` & `user_data.password`) for `fish-mob.ru` and `chat.fish-mob.ru`.
    @Published public var savedOnlineLogin: String = "angler_ios" {
        didSet {
            if !isLoadingPersistedSettings {
                saveOnlineCredentialsToDatabase(login: savedOnlineLogin, password: savedOnlinePassword)
            }
        }
    }
    @Published public var savedOnlinePassword: String = "secret123" {
        didSet {
            if !isLoadingPersistedSettings {
                saveOnlineCredentialsToDatabase(login: savedOnlineLogin, password: savedOnlinePassword)
            }
        }
    }

    public let installationUuid: String
    public let liveNetworkClient = FishingLiveNetworkClient()
    public let tcpChatSession = FishingLiveTCPChatSession()
    @Published public var biteNotificationScheduler: FishingBiteNotificationScheduler
    @Published public private(set) var topPlayersRating: [TopPlayerRatingEntry] = []
    @Published public private(set) var worldSpeciesRecords: [WorldSpeciesRecordEntry] = []
    @Published public private(set) var tournamentTimetableLines: [String] = []
    @Published public private(set) var httpActiveTournaments: [OnlineTournamentEntry] = []
    @Published public private(set) var httpCompletedTournaments: [OnlineTournamentEntry] = []
    @Published public private(set) var activeTournamentResults: TournamentResultsSnapshot? = nil
    @Published public private(set) var lastCaughtFishForSync: CaughtUserFish? = nil
    @Published public private(set) var authenticatedChatUserId: Int32 = 1
    @Published public private(set) var isOnlineRequestInFlight: Bool = false
    @Published public private(set) var lastOnlineStatusMessage: String = ""
    @Published public private(set) var chatConnectionState: FishingLiveTCPChatSession.ConnectionState = .disconnected
    private var tcpChatReceiveBuffer = Data()

    /// Exact activation check (`GameActivity.b0()`): `pond_fon_set_<id> > 0 && WATER_SHADER == true`.
    public var isWaterShaderActive: Bool {
        WaterShaderActivationPolicy.shouldActivate(
            pondBackgroundSetIndex: pondBackgroundSetIndex,
            waterShaderSettingEnabled: isWaterShaderEnabled
        )
    }

    /// Corresponds to `SharedPreferences("FFF-ANDROID")["TASKS"]` (`F0.o.b`).
    @Published public var tasksEnabled: Bool = true {
        didSet {
            if !isLoadingPersistedSettings {
                savePersistedSettingsToDatabase()
            }
        }
    }
    /// Active UI / quest evaluation language (`F0.g.b(ctx)`: `"ru"`, `"en"`, `"de"`, `"es"`, `"pt"`).
    @Published public var languageCode: String = "ru" {
        didSet {
            if !isLoadingPersistedSettings {
                savePersistedSettingsToDatabase()
            }
        }
    }

    @Published public private(set) var profile: PlayerProfileRecord = PlayerProfileRecord()
    @Published public private(set) var tackleSlots: UserTackleSlotRecord = UserTackleSlotRecord()
    @Published public private(set) var assembledTackle: AssembledTackle = AssembledTackle()

    @Published public private(set) var ownedRods: [UserRodItem] = []
    @Published public private(set) var ownedCoils: [UserCoilItem] = []
    @Published public private(set) var ownedLines: [UserLineItem] = []
    @Published public private(set) var ownedHooks: [UserHookItem] = []
    @Published public private(set) var ownedBaits: [UserBaitItem] = []
    @Published public private(set) var activeCoupon: UserCouponItem? = nil
    @Published public private(set) var fishnetEntries: [FishnetEntryRecord] = []
    @Published public private(set) var overflowFcount: Int = 0

    @Published public private(set) var achievements: [AchievementRecord] = []
    @Published public private(set) var quests: [QuestRecord] = []
    @Published public private(set) var personalRecords: [PersonalSpeciesRecord] = []

    @Published public private(set) var onlineShopSnapshot: OnlineShopSnapshot? = nil
    @Published public private(set) var chatMessages: [ChatMess] = []
    @Published public private(set) var onlineTours: [ChatTourModel] = []
    @Published public private(set) var onlineUsers: [ChatUserOnline] = []
    /// Reconstructs `com.evados.fishing.chat.Data.userData` (`ChatServerUserData`), populated by `"initialize"`, `"import value"`, and `"transaction"`.
    @Published public private(set) var chatServerUserData: ChatServerUserData = ChatServerUserData()
    public var authLimiter = AuthAttemptLimiter()
    @Published public var audioHaptics = FishingAudioAndHapticsController() {
        didSet {
            if audioHaptics.soundEnabled != oldValue.soundEnabled {
                if !audioHaptics.soundEnabled {
                    audioHaptics.stopAmbientAndReelAudio()
                } else if selectedTab == .fishingPond {
                    audioHaptics.syncAmbientTrack(
                        pondIndex: selectedPondIndex,
                        hour: gameClock.hour,
                        isPondScreenVisible: true
                    )
                }
            }
            if !isLoadingPersistedSettings,
               (audioHaptics.soundEnabled != oldValue.soundEnabled ||
                audioHaptics.vibrationEnabled != oldValue.vibrationEnabled ||
                audioHaptics.vibrationDurationMs != oldValue.vibrationDurationMs) {
                savePersistedSettingsToDatabase()
            }
        }
    }
    @Published public private(set) var activeContract: UserTaskContractRecord? = nil

    public var localeManager: FishingLocaleManager {
        FishingLocaleManager(
            currentLanguage: FishingLanguage(rawValue: languageCode) ?? .ru,
            tasksEnabled: tasksEnabled
        )
    }

    @Published public private(set) var catalogRods: [FishingRodSpec] = []
    @Published public private(set) var catalogCoils: [CoilSpec] = []
    @Published public private(set) var catalogLines: [FishingLineSpec] = []
    @Published public private(set) var catalogHooks: [HookShopCatalogItem] = []
    @Published public private(set) var catalogBaits: [BaitShopCatalogItem] = []
    @Published public private(set) var fishCatalogById: [Int: FishSpecies] = [:]

    @Published public private(set) var gameClock: GameClockTimer
    @Published public private(set) var dayNightLighting: DayNightLighting
    @Published public private(set) var stateMachine: FishingStateMachine
    @Published public private(set) var currentLineCurve: QuadraticBezierCurve? = nil
    /// Smoothly interpolated visual bobber coordinates between 200ms `GameView$c` physics ticks.
    @Published public private(set) var renderedBobberPosition: Point2D? = nil
    @Published public var activeAlert: FishingModalAlert? = nil

    private var previousPhysicsBobberPos: Point2D? = nil
    private var targetPhysicsBobberPos: Point2D? = nil
    private var lastPhysicsTickWallMs: Int64 = 0
    private var lastRippleStepWallMs: Int64 = 0
    private var lastClockTickWallMs: Int64 = 0

    private var systemRng = SystemFishingRandom()
    private var visualRng = SystemFishingRandom()

    public init(
        databasePath: String? = nil,
        jsonDataDirectoryURL: URL? = nil,
        installationUuid: String = "00000000-0000-0000-0000-000000000000",
        initialHour: Int = 6,
        initialMinute: Int = 0,
        viewWidth: Int = 1280,
        viewHeight: Int = 800,
        nowMs: Int64 = 1_700_000_000_000,
        notificationScheduling: any SystemNotificationScheduling = LiveSystemNotifications()
    ) throws {
        let resolvedPath: String
        if let databasePath {
            resolvedPath = databasePath
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = appSupport.appendingPathComponent("FishingForFriends", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            resolvedPath = dir.appendingPathComponent("fishing2.db").path
        }

        let conn = try SQLiteConnection(path: resolvedPath)
        try DatabaseSchemaAndMigrations.migrateIfNeeded(on: conn)

        let cat = ReferenceCatalogStore(connection: conn, installationUuid: installationUuid)
        let bt = BalanceTables()
        let repo = PlayerStateRepository(
            connection: conn,
            catalog: cat,
            installationUuid: installationUuid,
            balanceTables: bt
        )

        if let jsonDir = jsonDataDirectoryURL,
           FileManager.default.fileExists(atPath: jsonDir.appendingPathComponent("fishes.json").path) {
            _ = try cat.importFromJSONDirectory(jsonDir, nowMs: nowMs)
        } else {
            try cat.seedBuiltInStarterCatalogIfEmpty(nowMs: nowMs)
        }

        try repo.initializeNewPlayerIfNeeded(nowMs: nowMs)

        self.installationUuid = installationUuid
        self.biteNotificationScheduler = FishingBiteNotificationScheduler(
            notificationScheduling: notificationScheduling
        )
        self.connection = conn
        self.catalog = cat
        self.repository = repo
        self.balanceTables = bt

        let clock = GameClockTimer(hour: initialHour, minute: initialMinute)
        self.gameClock = clock
        self.dayNightLighting = DayNightLighting.forHour(clock.hour)

        let fishes = try cat.loadFishCatalogById()
        self.fishCatalogById = fishes
        let initialPondData = try cat.loadPondSimulationData(pondIndex: 0)
        let initialTackle = try repo.loadAssembledTackle()

        self.stateMachine = FishingStateMachine(
            viewWidth: viewWidth,
            viewHeight: viewHeight,
            bobberBitmapWidth: 24,
            bobberBitmapHeight: 40,
            animationsEnabled: true,
            balanceTables: bt,
            pondData: initialPondData,
            timeOfDay: BiteTimeOfDay.from(hour: clock.hour, minute: clock.minute),
            fishCatalogById1Based: fishes,
            tackle: initialTackle
        )

        try reloadAllStateFromDatabase()
        self.tcpChatSession.onConnectionStateChanged = { [weak self] newState in
            guard let self else { return }
            self.chatConnectionState = newState
        }
        self.tcpChatSession.onPacketReceived = { [weak self] packetData in
            guard let self else { return }
            self.tcpChatReceiveBuffer.append(packetData)
            let messages = JavaObjectStreamCodec.extractMessagesFromStreamBuffer(&self.tcpChatReceiveBuffer)
            for mess in messages {
                let outcome = self.applyDecodedChatMessage(mess, currentUserId: self.authenticatedChatUserId)
                if case .sendHeartbeatReply(let pongMess) = outcome {
                    self.tcpChatSession.sendMess(pongMess)
                } else if case .sendInitializeRequest(let initMess) = outcome {
                    self.tcpChatSession.sendMess(initMess)
                }
            }
        }
    }

    // MARK: - State Synchronization with SQLite

    public func reloadAllStateFromDatabase() throws {
        profile = try repository.loadPlayerProfile()
        tackleSlots = try repository.loadTackleSlots()
        assembledTackle = try repository.loadAssembledTackle()

        ownedRods = try repository.listUserRods()
        ownedCoils = try repository.listUserCoils()
        ownedLines = try repository.listUserLines()
        ownedHooks = try repository.listUserHooks()
        ownedBaits = try repository.listUserBaits()
        activeCoupon = try repository.loadActiveCoupon()
        fishnetEntries = try repository.listFishnetEntries()
        overflowFcount = try repository.loadOverflowFcount()

        achievements = try repository.listAchievements()
        quests = try repository.listQuests()
        personalRecords = try repository.listPersonalRecords(onlyCaught: false)
        activeContract = try repository.loadActiveUserTaskContract()

        catalogRods = try catalog.listAllRodSpecs().filter { $0.price > 0 && $0.weight <= 179 }
        catalogCoils = try catalog.listAllCoilSpecs().filter { $0.price > 0 && $0.bearingCount <= 7 }
        catalogLines = try catalog.listAllLineSpecs().filter { $0.price > 0 && $0.stockLength <= 100 && $0.weight <= 376 }
        catalogHooks = try catalog.listAllHookCatalogItems().filter { $0.stockAmount <= 5 }
        catalogBaits = try catalog.listAllBaitCatalogItems()
        availablePonds = try catalog.listAllPonds()
        fishCatalogById = try catalog.loadFishCatalogById()

        stateMachine.tackle = assembledTackle
        stateMachine.fishCatalogById1Based = fishCatalogById
        loadPersistedSettingsFromDatabase()
        audioHaptics.syncAmbientTrack(
            pondIndex: selectedPondIndex,
            hour: gameClock.hour,
            isPondScreenVisible: selectedTab == .fishingPond
        )
    }

    /// Saves all user settings (`WATER_SHADER`, `TASKS`, `SOUND`, `VIBRATION`, `CHECKMODE`, `ONLINE_MODE`, `DEV`,
    /// `LANGUAGE`, `POND_INDEX`, and `HOUR`/`MINUTE`) into `player_runtime_counters` in SQLite (`fishing2.db`).
    public func savePersistedSettingsToDatabase() {
        guard !isLoadingPersistedSettings else { return }
        let langIndex: Int
        switch languageCode {
        case "en": langIndex = 1
        case "de": langIndex = 2
        case "es": langIndex = 3
        case "pt": langIndex = 4
        default: langIndex = 0
        }
        let entries: [(String, Int)] = [
            ("pref_water_shader", isWaterShaderEnabled ? 1 : 0),
            ("pref_pond_fon_set", pondBackgroundSetIndex),
            ("pref_debug_overlay", isDebugOverlayEnabled ? 1 : 0),
            ("pref_check_mode", checkModeEnabled ? 1 : 0),
            ("pref_online_mode", onlineModeEnabled ? 1 : 0),
            ("pref_tasks_enabled", tasksEnabled ? 1 : 0),
            ("pref_language_index", langIndex),
            ("pref_sound_enabled", audioHaptics.soundEnabled ? 1 : 0),
            ("pref_vibration_enabled", audioHaptics.vibrationEnabled ? 1 : 0),
            ("pref_vibration_duration_ms", audioHaptics.vibrationDurationMs),
            ("pref_selected_pond_index", selectedPondIndex),
            ("pref_clock_hour", gameClock.hour),
            ("pref_clock_minute", gameClock.minute)
        ]
        for (key, value) in entries {
            _ = try? connection.run("""
            INSERT INTO player_runtime_counters (counter_key, counter_value)
            VALUES (?, ?)
            ON CONFLICT(counter_key) DO UPDATE SET counter_value = excluded.counter_value;
            """, bindings: [.text(key), .integer(Int64(value))])
        }
    }

    /// Loads saved user settings from `player_runtime_counters` and online credentials from `user_data`.
    public func loadPersistedSettingsFromDatabase() {
        isLoadingPersistedSettings = true
        defer { isLoadingPersistedSettings = false }

        if !profile.login.isEmpty {
            savedOnlineLogin = profile.login
        }
        if !profile.password.isEmpty {
            savedOnlinePassword = profile.password
        }

        guard let rows = try? connection.query("""
        SELECT counter_key, counter_value FROM player_runtime_counters
        WHERE counter_key LIKE 'pref_%';
        """), !rows.isEmpty else {
            return
        }

        var map: [String: Int] = [:]
        for row in rows {
            map[row.string("counter_key")] = row.int("counter_value")
        }

        if let v = map["pref_water_shader"] { isWaterShaderEnabled = (v != 0) }
        if let v = map["pref_pond_fon_set"] { pondBackgroundSetIndex = v }
        if let v = map["pref_debug_overlay"] { isDebugOverlayEnabled = (v != 0) }
        if let v = map["pref_check_mode"] { checkModeEnabled = (v != 0) }
        if let v = map["pref_online_mode"] { onlineModeEnabled = (v != 0) }
        if let v = map["pref_tasks_enabled"] { tasksEnabled = (v != 0) }
        if let v = map["pref_language_index"] {
            switch v {
            case 1: languageCode = "en"
            case 2: languageCode = "de"
            case 3: languageCode = "es"
            case 4: languageCode = "pt"
            default: languageCode = "ru"
            }
        }
        if let v = map["pref_sound_enabled"] { audioHaptics.soundEnabled = (v != 0) }
        if let v = map["pref_vibration_enabled"] { audioHaptics.vibrationEnabled = (v != 0) }
        if let v = map["pref_vibration_duration_ms"], v > 0 { audioHaptics.vibrationDurationMs = v }
        if let v = map["pref_selected_pond_index"],
           v >= 0,
           v < availablePonds.count,
           v != selectedPondIndex,
           let pond = try? catalog.loadPondSimulationData(pondIndex: v) {
            selectedPondIndex = v
            stateMachine.pondData = pond
            audioHaptics.syncAmbientTrack(
                pondIndex: v,
                hour: gameClock.hour,
                isPondScreenVisible: selectedTab == .fishingPond
            )
        }
    }

    /// Persists online login and password into `user_data` (`id = 1`) without altering `UserDataMd5`.
    public func saveOnlineCredentialsToDatabase(login: String, password: String) {
        let trimmedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLogin.isEmpty else { return }
        _ = try? connection.run("""
        UPDATE user_data SET login = ?, password = ? WHERE id = 1;
        """, bindings: [.text(trimmedLogin), .text(password)])
        if let updated = try? repository.loadPlayerProfile() {
            self.profile = updated
        }
    }

    public var currentPondItem: PondCatalogItem? {
        availablePonds.first(where: { $0.id == selectedPondIndex }) ?? availablePonds.first
    }

    public func selectPond(pondIndex: Int) {
        do {
            let pond = try catalog.loadPondSimulationData(pondIndex: pondIndex)
            if let meta = availablePonds.first(where: { $0.id == pondIndex }) {
                if profile.category < meta.requiredRank {
                    activeAlert = .operationError(
                        message: "Для водоёма «\(meta.nameRu)» требуется разряд \(meta.requiredRank) (ваш: \(profile.category))."
                    )
                    return
                }
                if meta.requiresCoupon && activeCoupon == nil {
                    activeAlert = .operationError(
                        message: "Для водоёма «\(meta.nameRu)» необходим активный путевой купон."
                    )
                    return
                }
            }
            selectedPondIndex = pondIndex
            _ = stateMachine.resetToIdle()
            stateMachine.pondData = pond
            currentLineCurve = nil
            renderedBobberPosition = nil
            previousPhysicsBobberPos = nil
            targetPhysicsBobberPos = nil
        } catch {
            activeAlert = .operationError(message: "Не удалось загрузить водоём #\(pondIndex): \(error)")
        }
    }

    // MARK: - Shop & Starter Kit Actions

    public func buyAndEquipStarterKit(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        do {
            try connection.transaction {
                let rod: UserRodItem
                if let existing = try repository.listUserRods().first {
                    rod = existing
                } else {
                    rod = try repository.buyFishingRod(baseRodId: 1, nowMs: nowMs)
                }

                let line: UserLineItem
                if let existing = try repository.listUserLines().first {
                    line = existing
                } else {
                    line = try repository.buyFishingLine(baseLineId: 1, nowMs: nowMs)
                }

                let coil: UserCoilItem
                if let existing = try repository.listUserCoils().first {
                    coil = existing
                } else {
                    coil = try repository.buyCoil(baseCoilId: 1, nowMs: nowMs)
                }

                let hook: UserHookItem
                if let existing = try repository.listUserHooks().first {
                    hook = existing
                } else {
                    hook = try repository.buyHook(baseHookId: 1)
                }

                let bait: UserBaitItem
                if let existing = try repository.listUserBaits().first {
                    bait = existing
                } else {
                    bait = try repository.buyBait(baseBaitId: 1)
                }

                try repository.saveTackleSlots(
                    UserTackleSlotRecord(
                        id: 1,
                        fishingRodId: rod.id,
                        fishingLineId: line.id,
                        coilId: coil.id,
                        hookId: hook.id,
                        baitId: bait.id
                    )
                )
            }
            try reloadAllStateFromDatabase()
        } catch let error as PlayerPersistenceError {
            activeAlert = .operationError(message: describePersistenceError(error))
        } catch {
            activeAlert = .operationError(message: "Ошибка покупки стартового набора: \(error)")
        }
    }

    public func buyRod(baseRodId: Int, nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        do {
            let item = try repository.buyFishingRod(baseRodId: baseRodId, nowMs: nowMs)
            var slots = try repository.loadTackleSlots()
            if slots.fishingRodId <= 0 {
                slots.fishingRodId = item.id
                try repository.saveTackleSlots(slots)
            }
            try reloadAllStateFromDatabase()
        } catch let err as PlayerPersistenceError {
            activeAlert = .operationError(message: describePersistenceError(err))
        } catch {
            activeAlert = .operationError(message: "\(error)")
        }
    }

    public func buyCoil(baseCoilId: Int, nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        do {
            let item = try repository.buyCoil(baseCoilId: baseCoilId, nowMs: nowMs)
            var slots = try repository.loadTackleSlots()
            if slots.coilId <= 0 {
                slots.coilId = item.id
                try repository.saveTackleSlots(slots)
            }
            try reloadAllStateFromDatabase()
        } catch let err as PlayerPersistenceError {
            activeAlert = .operationError(message: describePersistenceError(err))
        } catch {
            activeAlert = .operationError(message: "\(error)")
        }
    }

    public func buyLine(baseLineId: Int, nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        do {
            let item = try repository.buyFishingLine(baseLineId: baseLineId, nowMs: nowMs)
            var slots = try repository.loadTackleSlots()
            if slots.fishingLineId <= 0 {
                slots.fishingLineId = item.id
                try repository.saveTackleSlots(slots)
            }
            try reloadAllStateFromDatabase()
        } catch let err as PlayerPersistenceError {
            activeAlert = .operationError(message: describePersistenceError(err))
        } catch {
            activeAlert = .operationError(message: "\(error)")
        }
    }

    public func buyHook(baseHookId: Int) {
        do {
            let item = try repository.buyHook(baseHookId: baseHookId)
            var slots = try repository.loadTackleSlots()
            if slots.hookId <= 0 {
                slots.hookId = item.id
                try repository.saveTackleSlots(slots)
            }
            try reloadAllStateFromDatabase()
        } catch let err as PlayerPersistenceError {
            activeAlert = .operationError(message: describePersistenceError(err))
        } catch {
            activeAlert = .operationError(message: "\(error)")
        }
    }

    public func buyBait(baseBaitId: Int) {
        do {
            let item = try repository.buyBait(baseBaitId: baseBaitId)
            var slots = try repository.loadTackleSlots()
            if slots.baitId <= 0 {
                slots.baitId = item.id
                try repository.saveTackleSlots(slots)
            }
            try reloadAllStateFromDatabase()
        } catch let err as PlayerPersistenceError {
            activeAlert = .operationError(message: describePersistenceError(err))
        } catch {
            activeAlert = .operationError(message: "\(error)")
        }
    }

    // MARK: - Inventory Equipping Actions (`BackpackActivity`)

    public func equipRod(rowId: Int?) {
        updateSlots { $0.fishingRodId = rowId ?? UserTackleSlotRecord.unequippedSentinel }
    }

    public func equipCoil(rowId: Int?) {
        updateSlots { $0.coilId = rowId ?? UserTackleSlotRecord.unequippedSentinel }
    }

    public func equipLine(rowId: Int?) {
        updateSlots { $0.fishingLineId = rowId ?? UserTackleSlotRecord.unequippedSentinel }
    }

    public func equipHook(rowId: Int?) {
        updateSlots { $0.hookId = rowId ?? UserTackleSlotRecord.unequippedSentinel }
    }

    public func equipBait(rowId: Int?) {
        updateSlots { $0.baitId = rowId ?? UserTackleSlotRecord.unequippedSentinel }
    }

    private func updateSlots(_ transform: (inout UserTackleSlotRecord) -> Void) {
        do {
            var slots = try repository.loadTackleSlots()
            transform(&slots)
            try repository.saveTackleSlots(slots)
            try reloadAllStateFromDatabase()
        } catch {
            activeAlert = .operationError(message: "Не удалось обновить слоты снасти: \(error)")
        }
    }

    // MARK: - Fishnet Sale Action (`MainActivity$e`)

    public func sellAllFishInFishnet(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        do {
            let result = try repository.sellAllFish(nowMs: nowMs)
            try repository.evaluateAchievementOnFishSale(
                soldFishCount: result.soldFishCount,
                newBalance: result.newBalance,
                nowMs: nowMs
            )
            try reloadAllStateFromDatabase()
            let hasOnlineCreds = !savedOnlineLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !savedOnlinePassword.isEmpty
            if onlineModeEnabled || hasOnlineCreds {
                syncAchievementsAndQuestsLive(includeQuests: false, silent: true)
                if let lastFish = lastCaughtFishForSync {
                    submitCaughtFishLive(lastFish)
                }
            }
            activeAlert = .fishSold(result: result)
        } catch let err as PlayerPersistenceError {
            activeAlert = .operationError(message: describePersistenceError(err))
        } catch {
            activeAlert = .operationError(message: "Ошибка продажи рыбы: \(error)")
        }
    }

    // MARK: - Fishing Gameplay Loop (`GameView` + `GameView$c` + `GameView$a`)

    public func updateViewportSize(width: Int, height: Int) {
        guard width > 100, height > 100 else { return }
        let expectedDims = RodSpriteState.scaledRodDimensions(forViewWidth: width, viewHeight: height)
        if stateMachine.viewWidth != width
            || stateMachine.viewHeight != height
            || stateMachine.rodSprite.width != expectedDims.width
            || stateMachine.rodSprite.height != expectedDims.height {
            stateMachine.updateViewportSize(width: width, height: height)
            if stateMachine.bobber != nil {
                refreshLineGeometry(stepRipplesAndCast: false)
            }
        }
    }

    public func castAt(
        x: Float,
        y: Float,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        castAt(x: x, y: y, nowMs: nowMs, rng: &systemRng)
    }

    public func castAt(
        x: Float,
        y: Float,
        nowMs: Int64,
        rng: inout some FishingRandomGenerator
    ) {
        try? reloadAllStateFromDatabase()
        let events = stateMachine.cast(
            x: x,
            y: y,
            nowMs: nowMs,
            currentHour: gameClock.hour,
            currentMinute: gameClock.minute,
            checkModeEnabled: checkModeEnabled,
            canScheduleExactAlarms: biteNotificationScheduler.authorizationGranted,
            rng: &rng
        )
        lastPhysicsTickWallMs = nowMs
        lastRippleStepWallMs = nowMs
        if stateMachine.state == .waitingForBite, let bobber = stateMachine.bobber {
            let pt = Point2D(x: bobber.x, y: bobber.y)
            previousPhysicsBobberPos = pt
            targetPhysicsBobberPos = pt
            renderedBobberPosition = pt
            audioHaptics.recordCastScheduledBite(beginTimeMs: nowMs)
            if checkModeEnabled {
                let pondTitle = currentPondItem.map { localeManager.pondName(for: $0) } ?? "Водоём"
                biteNotificationScheduler.scheduleBiteAlarm(
                    scheduledBiteTimeMs: stateMachine.scheduledBiteTimeMs,
                    nowMs: nowMs,
                    pondTitle: pondTitle
                )
            }
        } else {
            previousPhysicsBobberPos = nil
            targetPhysicsBobberPos = nil
            renderedBobberPosition = nil
        }
        refreshLineGeometry(stepRipplesAndCast: true)
        handleFishingUIEvents(events, nowMs: nowMs)

        if stateMachine.state == .missingTackleHold || stateMachine.state == .alarmPermissionHold {
            let followUp = stateMachine.stepTick(
                nowMs: nowMs,
                fishnetCount: fishnetEntries.count,
                overflowFcount: overflowFcount,
                rng: &rng
            )
            handleFishingUIEvents(followUp, nowMs: nowMs)
        }
    }

    public func resetCastToIdle() {
        let events = stateMachine.resetToIdle()
        audioHaptics.setReelLooping(false)
        if biteNotificationScheduler.isNotificationPending {
            biteNotificationScheduler.cancelPendingBiteAlarm()
        }
        currentLineCurve = nil
        renderedBobberPosition = nil
        previousPhysicsBobberPos = nil
        targetPhysicsBobberPos = nil
        handleFishingUIEvents(events, nowMs: Int64(Date().timeIntervalSince1970 * 1000))
    }

    public func setReelPulled(_ pulled: Bool) {
        // Avoid redundant @Published mutations when DragGesture.onChanged fires continuously during a hold
        guard stateMachine.isPulled != pulled || (pulled && stateMachine.isPreHookBobbing) else {
            return
        }
        stateMachine.setPulled(pulled)
        audioHaptics.setReelLooping(pulled && stateMachine.state == .fishFight)
        refreshLineGeometry(stepRipplesAndCast: false)
    }

    /// Unified real-time game loop dispatcher driven by a single `@State` timer in `FishingRootView`
    /// so view re-evaluations never cancel or starve the `200 ms` `GameView$c` physics loop.
    public func stepRealtimeLoop(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        // 1. Game clock (`FishingService$a`: 1 game minute every 2000 ms)
        if lastClockTickWallMs == 0 || nowMs < lastClockTickWallMs {
            lastClockTickWallMs = nowMs
        } else if (nowMs - lastClockTickWallMs) >= GameClockTimer.tickIntervalMs {
            lastClockTickWallMs = nowMs
            stepGameClockMinute()
        }

        // 2. Active fishing loop (`GameView$c` 200ms/300ms physics + `GameView$a` visual frame)
        guard stateMachine.state != .idle else { return }

        if lastPhysicsTickWallMs == 0 || nowMs < lastPhysicsTickWallMs {
            lastPhysicsTickWallMs = nowMs
        }
        let physicsIntervalMs: Int64 = (stateMachine.state == .fishFight) ? 200 : 300
        if (nowMs - lastPhysicsTickWallMs) >= physicsIntervalMs {
            stepSimulationTick(nowMs: nowMs)
        } else {
            stepVisualFrameTick(wallNowMs: nowMs)
        }
    }

    public func stepSimulationTick(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        stepSimulationTick(nowMs: nowMs, rng: &systemRng)
    }

    public func stepSimulationTick(
        nowMs: Int64,
        rng: inout some FishingRandomGenerator
    ) {
        let startBobberPos = renderedBobberPosition ?? stateMachine.bobber.map { Point2D(x: $0.x, y: $0.y) }

        let events = stateMachine.stepTick(
            nowMs: nowMs,
            fishnetCount: fishnetEntries.count,
            overflowFcount: overflowFcount,
            rng: &rng
        )
        handleFishingUIEvents(events, nowMs: nowMs)

        switch stateMachine.state {
        case .fishCaught, .lineBroken, .rodBroken, .coilBroken, .fishEscaped:
            audioHaptics.setReelLooping(false)
            try? repository.syncAssembledTackleAfterFight(stateMachine.tackle)
            let terminalEvents = stateMachine.stepTick(
                nowMs: nowMs,
                fishnetCount: fishnetEntries.count,
                overflowFcount: overflowFcount,
                rng: &rng
            )
            handleFishingUIEvents(terminalEvents, nowMs: nowMs)
            try? reloadAllStateFromDatabase()
            currentLineCurve = nil
            renderedBobberPosition = nil
            previousPhysicsBobberPos = nil
            targetPhysicsBobberPos = nil
        default:
            lastPhysicsTickWallMs = nowMs
            lastRippleStepWallMs = nowMs
            _ = stateMachine.stepVisualFrame(
                stepRipplesAndCast: true,
                displayBobberPosition: nil,
                rng: &visualRng
            )
            if let bobber = stateMachine.bobber {
                let newTarget = Point2D(x: bobber.x, y: bobber.y)
                previousPhysicsBobberPos = startBobberPos ?? newTarget
                targetPhysicsBobberPos = newTarget
                if stateMachine.state != .fishFight {
                    renderedBobberPosition = newTarget
                }
            } else {
                previousPhysicsBobberPos = nil
                targetPhysicsBobberPos = nil
                renderedBobberPosition = nil
            }
            refreshLineGeometry(stepRipplesAndCast: false)
        }
    }

    /// High-frequency visual frame update (`~30 FPS`) reproducing `GameView$a`'s `60 ms` canvas loop
    /// and smoothly interpolating the displayed bobber and fishing line between `200 ms` `GameView$c` physics ticks.
    public func stepVisualFrameTick(wallNowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        guard stateMachine.state != .idle, stateMachine.bobber != nil else { return }

        if wallNowMs < lastPhysicsTickWallMs {
            lastPhysicsTickWallMs = wallNowMs
        }

        if stateMachine.state == .fishFight,
           let prev = previousPhysicsBobberPos,
           let target = targetPhysicsBobberPos {
            let elapsed = Float(max(0, wallNowMs - lastPhysicsTickWallMs))
            let t = min(1.0, elapsed / 200.0)
            let smoothX = prev.x + (target.x - prev.x) * t
            let smoothY = prev.y + (target.y - prev.y) * t
            renderedBobberPosition = Point2D(x: smoothX, y: smoothY)
        } else if let bobber = stateMachine.bobber {
            renderedBobberPosition = Point2D(x: bobber.x, y: bobber.y)
        }

        // Step `D0.a.l()` ripples and `D0.b.c()` cast progress at the original 60ms cadence (`GameView$a`)
        let shouldStep60ms = (wallNowMs - lastRippleStepWallMs) >= 60 || wallNowMs < lastRippleStepWallMs
        if shouldStep60ms {
            lastRippleStepWallMs = wallNowMs
        }
        refreshLineGeometry(stepRipplesAndCast: shouldStep60ms)
    }

    public func fastForwardToScheduledBite(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        guard stateMachine.state == .waitingForBite else { return }
        stateMachine.rescheduleBiteToNow(nowMs: nowMs)
        for attempt in 0..<12 where stateMachine.state == .waitingForBite {
            stepSimulationTick(nowMs: nowMs + Int64(attempt), rng: &systemRng)
        }
    }

    public func stepGameClockMinute() {
        let isPaidPond = (selectedTab == .fishingPond) && (currentPondItem?.requiresCoupon ?? false)
        var couponTicks: Int? = activeCoupon.map { max(1, $0.remainingTimeUnits) }
        gameClock.tickOneGameMinute(isPaidPond: isPaidPond, activeCouponRemainingTicks: &couponTicks)
        dayNightLighting = DayNightLighting.forHour(gameClock.hour)
        stateMachine.timeOfDay = BiteTimeOfDay.from(hour: gameClock.hour, minute: gameClock.minute)
        audioHaptics.syncAmbientTrack(
            pondIndex: selectedPondIndex,
            hour: gameClock.hour,
            isPondScreenVisible: selectedTab == .fishingPond
        )
        savePersistedSettingsToDatabase()
    }

    // MARK: - Internal Helpers

    private func refreshLineGeometry(stepRipplesAndCast: Bool = true) {
        guard stateMachine.bobber != nil else {
            currentLineCurve = nil
            renderedBobberPosition = nil
            return
        }
        currentLineCurve = stateMachine.stepVisualFrame(
            stepRipplesAndCast: stepRipplesAndCast,
            displayBobberPosition: renderedBobberPosition,
            rng: &visualRng
        )
    }

    private func handleFishingUIEvents(_ events: [FishingUIEvent], nowMs: Int64) {
        for event in events {
            switch event {
            case .missingTackle(let missing):
                activeAlert = .missingTackle(missingComponents: missing)

            case .tensionChanged:
                break

            case .biteTriggered:
                if biteNotificationScheduler.isNotificationPending {
                    biteNotificationScheduler.cancelPendingBiteAlarm()
                }
                audioHaptics.handleBiteSignalWhat0(
                    nowMs: nowMs,
                    fishWeightGrams: max(50, stateMachine.activeFishWeightGrams)
                )

            case .fishCaught(let caughtFish):
                audioHaptics.handleCatchSignalWhat1(nowMs: nowMs)
                do {
                    let result = try repository.recordCaughtFish(caughtFish, nowMs: nowMs)
                    try repository.evaluateAchievementsOnCatch(caughtFish, nowMs: nowMs)
                    _ = try repository.evaluateQuestsOnCatch(
                        caughtFish,
                        playerCategory: result.categoryRankAfter,
                        tasksEnabled: tasksEnabled,
                        languageCode: languageCode,
                        nowMs: nowMs
                    )
                    _ = try repository.evaluateUserTaskOnCatch(
                        caughtFish,
                        isLanguageSupported: localeManager.areQuestsAndTasksActive,
                        nowMs: nowMs
                    )
                    lastCaughtFishForSync = caughtFish
                    try reloadAllStateFromDatabase()
                    activeAlert = .catchDialog(
                        fish: caughtFish,
                        result: result,
                        isLucky25: ProgressionCalculator.isLuckyWeight25(caughtFish.weightGrams),
                        isRepdigit: ProgressionCalculator.isRepdigitWeight(caughtFish.weightGrams),
                        isCleanerTrash: ProgressionCalculator.isCleanerTrashCatch(fishId1Based: caughtFish.fish.id)
                    )
                    let hasOnlineCreds = !savedOnlineLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !savedOnlinePassword.isEmpty
                    if onlineModeEnabled || hasOnlineCreds {
                        submitCaughtFishLive(caughtFish)
                        syncAchievementsAndQuestsLive(includeQuests: false, silent: true)
                    }
                } catch {
                    activeAlert = .operationError(message: "Ошибка сохранения улова: \(error)")
                }

            case .lineBroken:
                audioHaptics.playSoundEffect(.lineBreak)
                try? reloadAllStateFromDatabase()
                activeAlert = .lineBroken

            case .rodBroken:
                audioHaptics.playSoundEffect(.rodBreak)
                try? repository.evaluateAchievementOnRodBroken(nowMs: nowMs)
                try? reloadAllStateFromDatabase()
                if onlineModeEnabled {
                    syncAchievementsAndQuestsLive(includeQuests: false, silent: true)
                }
                activeAlert = .rodBroken

            case .coilBroken:
                audioHaptics.playSoundEffect(.coilBreak)
                try? reloadAllStateFromDatabase()
                activeAlert = .coilBroken

            case .fishEscaped:
                audioHaptics.playSoundEffect(.fishSplash)
                try? reloadAllStateFromDatabase()
                activeAlert = .fishEscaped

            case .missedBiteDuringSleep:
                activeAlert = .missedBiteDuringSleep

            case .exactAlarmPermissionRequired:
                activeAlert = .exactAlarmPermissionRequired
            }
        }
    }

    private func describePersistenceError(_ error: PlayerPersistenceError) -> String {
        switch error {
        case .itemNotFoundInCatalog(let table, let id):
            return "Предмет #\(id) не найден в таблице \(table)."
        case .inventorySlotLimitReached(let maxSlots):
            return "Достигнут лимит слотов в рюкзаке (максимум \(maxSlots))."
        case .insufficientBalance(let required, let available):
            return "Недостаточно монет: требуется \(required), у вас \(available)."
        case .insufficientCategoryRank(let required, let current):
            return "Недостаточный разряд: требуется \(required), ваш разряд \(current)."
        case .onlineShopItemOnly:
            return "Этот предмет продаётся только в онлайн-магазине за жемчуг."
        case .activeCouponAlreadyExists:
            return "У вас уже есть активный путевой купон."
        case .integrityCheckFailed(let detail):
            return "Ошибка проверки целостности данных: \(detail)"
        case .invalidInventoryItem(let detail):
            return "Ошибка инвентаря: \(detail)"
        }
    }

    // MARK: - Online Profile Restore (`C0.a.l`), Online Shop (`MainActivity$d.c`) & TCP Chat (`0xACED0005`)

    @discardableResult
    public func restoreFromOnlineAuthResponse(
        _ response: String,
        login: String,
        password: String,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> AuthRestoreSummary {
        let nowSec = nowMs / 1000
        if let waitSec = authLimiter.registerAttempt(nowSeconds: nowSec) {
            throw PlayerPersistenceError.invalidInventoryItem("Подождите \(waitSec) сек. перед следующей попыткой входа.")
        }
        let summary = try repository.restoreProfileFromAuthResponse(
            response,
            login: login,
            password: password,
            nowMs: nowMs
        )
        authLimiter.resetOnSuccess()
        try reloadAllStateFromDatabase()
        return summary
    }

    @discardableResult
    public func syncOnlineShopFromCSV(
        _ csv: String,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> OnlineShopSnapshot {
        let snapshot = try repository.applyOnlineShopCSV(csv, nowMs: nowMs)
        self.onlineShopSnapshot = snapshot
        try reloadAllStateFromDatabase()
        return snapshot
    }

    @discardableResult
    public func receiveChatStreamPacket(
        _ packetData: Data,
        currentUserId: Int32 = 1
    ) throws -> ChatSelectorOutcome {
        let mess = try JavaObjectStreamCodec.decodeMess(from: packetData)
        return applyDecodedChatMessage(mess, currentUserId: currentUserId)
    }

    @discardableResult
    public func applyDecodedChatMessage(
        _ mess: ChatMess,
        currentUserId: Int32 = 1
    ) -> ChatSelectorOutcome {
        let effectiveLogin = !savedOnlineLogin.isEmpty ? savedOnlineLogin : (profile.login.isEmpty ? "Player" : profile.login)
        let outcome = ChatProtocolSelector.handleIncomingMess(
            mess,
            currentUserId: currentUserId,
            currentLogin: effectiveLogin,
            currentPond: Int32(selectedPondIndex)
        )
        switch outcome {
        case .initialized(let initObj):
            self.onlineTours = initObj.tours
            if let ud = initObj.userData {
                self.chatServerUserData = ud
            }
        case .serverUserDataUpdated(let ud):
            self.chatServerUserData = ud
        case .transactionCompleted(_, let updatedInit):
            if let updatedInit {
                self.onlineTours = updatedInit.tours
                if let ud = updatedInit.userData {
                    self.chatServerUserData = ud
                }
            }
        case .userListReceived(let all, _):
            self.onlineUsers = all
        case .toursUpdated(let tours):
            self.onlineTours = tours
        case .chatMessageReceived(let msg):
            self.chatMessages.append(msg)
        default:
            break
        }
        return outcome
    }

    // MARK: - Phase 9: Server Rewards (`reaward.php`), Fisherman Contracts (`user_task`) & Language Switching

    public func setLanguage(_ language: FishingLanguage) {
        self.languageCode = language.rawValue
    }

    @discardableResult
    public func claimServerRewards(
        _ response: String,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> ServerRewardClaimSummary {
        let summary = try repository.claimServerRewardsResponse(response, nowMs: nowMs)
        try reloadAllStateFromDatabase()
        return summary
    }

    @discardableResult
    public func assignFishermanContract(
        taskType: Int,
        targetFishId: Int,
        targetBaitId: Int = 0,
        requiredCount: Int,
        requiredWeightGrams: Int,
        bonusExperience: Int,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) throws -> UserTaskContractRecord {
        let record = try repository.assignUserTaskContract(
            taskType: taskType,
            targetFishId: targetFishId,
            targetBaitId: targetBaitId,
            requiredCount: requiredCount,
            requiredWeightGrams: requiredWeightGrams,
            bonusExperience: bonusExperience,
            nowMs: nowMs
        )
        try reloadAllStateFromDatabase()
        return record
    }

    // MARK: - Phase 10: Sleep-Mode Clock Catch-Up (`GameActivity.onResume`) & Tournament `tourType` Resolution

    /// Reconstructs `GameActivity.onResume` (`pc=0014..00b0`, `MECHANICS.md` Section 7.1):
    /// Fast-forwards `HOUR:MINUTE` after returning from sleep during `.waitingForBite` or `.fishFight`
    /// if `0 < (nowMs - beginTimeMs) / 2000 < 120` game minutes and drift exceeds `> 2` minutes.
    @discardableResult
    public func handleResumeAfterSleep(
        beginTimeMs: Int64,
        beginHour: Int,
        beginMinute: Int,
        nowMs: Int64
    ) -> Bool {
        let didCatchUp = gameClock.catchUpAfterSleepIfNeeded(
            stateCode: stateMachine.state.rawValue,
            beginTimeMs: beginTimeMs,
            beginHour: beginHour,
            beginMinute: beginMinute,
            nowMs: nowMs
        )
        if didCatchUp {
            dayNightLighting = DayNightLighting.forHour(gameClock.hour)
            stateMachine.timeOfDay = BiteTimeOfDay.from(hour: gameClock.hour, minute: gameClock.minute)
            audioHaptics.syncAmbientTrack(
            pondIndex: selectedPondIndex,
            hour: gameClock.hour,
            isPondScreenVisible: selectedTab == .fishingPond
        )
        }
        return didCatchUp
    }

    /// Resolves `tourType` (`0`, `1`, or `2`) for `X-Fish-Folp` (`FishingService$d.a`, `NETWORK.md` Section 3.1).
    public func resolveCurrentCatchTourType(hasActiveIndividualTour: Bool = false) -> Int {
        if onlineTours.contains(where: { $0.active == 1 }) {
            return 2
        }
        if hasActiveIndividualTour {
            return 1
        }
        return 0
    }

    // MARK: - Phase 15/16: Background Bite Alarm (`CHECKMODE`) & Live Network Operations

    /// Called when the app transitions to background/inactive (`scenePhase != .active`).
    /// Arms `stateMachine.castActiveFlag = 1` (`GameView.u = 1` wake-up alarm flag) and schedules the local notification.
    public func handleAppDidEnterBackground(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        guard stateMachine.state == .waitingForBite else { return }
        if checkModeEnabled {
            stateMachine.castActiveFlag = 1
            let pondTitle = currentPondItem.map { localeManager.pondName(for: $0) } ?? "Водоём"
            biteNotificationScheduler.scheduleBiteAlarm(
                scheduledBiteTimeMs: stateMachine.scheduledBiteTimeMs,
                nowMs: nowMs,
                pondTitle: pondTitle
            )
        }
    }

    /// Called when the app returns to foreground (`scenePhase == .active`, `GameActivity.onResume`).
    /// Catches up the game clock and evaluates any bite that occurred while the device was asleep.
    public func handleAppDidBecomeActive(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        if biteNotificationScheduler.isNotificationPending {
            biteNotificationScheduler.cancelPendingBiteAlarm()
        }

        if let meta = stateMachine.lastCastMetadata {
            _ = handleResumeAfterSleep(
                beginTimeMs: meta.beginTimeMs,
                beginHour: meta.beginHour,
                beginMinute: meta.beginMinute,
                nowMs: nowMs
            )
        }

        guard stateMachine.state == .waitingForBite, nowMs > stateMachine.scheduledBiteTimeMs else {
            return
        }

        let events = stateMachine.stepTick(
            nowMs: nowMs,
            checkModeEnabled: checkModeEnabled,
            spDateMs: nowMs,
            fishnetCount: fishnetEntries.count,
            overflowFcount: overflowFcount,
            rng: &systemRng
        )
        handleFishingUIEvents(events, nowMs: nowMs)

        if stateMachine.state == .idle {
            currentLineCurve = nil
            renderedBobberPosition = nil
            previousPhysicsBobberPos = nil
            targetPhysicsBobberPos = nil
        } else {
            lastPhysicsTickWallMs = nowMs
            lastRippleStepWallMs = nowMs
            if let bobber = stateMachine.bobber {
                let pt = Point2D(x: bobber.x, y: bobber.y)
                previousPhysicsBobberPos = pt
                targetPhysicsBobberPos = pt
                renderedBobberPosition = pt
            }
            refreshLineGeometry(stepRipplesAndCast: false)
        }
    }

    /// Performs live HTTP profile authentication against `http://fish-mob.ru/fff/auth.php` (`C0.a$h.b`).
    public func authenticateOnlineProfileLive(login: String, password: String) {
        let trimmedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLogin.isEmpty, !password.isEmpty else {
            activeAlert = .operationError(message: "Введите логин и пароль для входа.")
            return
        }
        savedOnlineLogin = trimmedLogin
        savedOnlinePassword = password
        saveOnlineCredentialsToDatabase(login: trimmedLogin, password: password)
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Подключение к серверу..."

        let client = self.liveNetworkClient
        let uuid = self.installationUuid
        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            do {
                let rawResponse = try await client.authenticateProfile(
                    login: trimmedLogin,
                    password: password,
                    installationUuid: uuid
                )
                let summary = try restoreFromOnlineAuthResponse(
                    rawResponse,
                    login: trimmedLogin,
                    password: password
                )
                self.onlineModeEnabled = true
                self.lastOnlineStatusMessage = "Профиль синхронизирован: опыт \(summary.experience), баланс \(summary.balanceCoins) руб."
                self.syncAchievementsAndQuestsLive(
                    login: trimmedLogin,
                    password: password,
                    includeQuests: false,
                    silent: true
                )
            } catch {
                self.lastOnlineStatusMessage = "Сервер временно недоступен (\(error.localizedDescription))."
            }
        }
    }

    /// Requests server rewards from `http://fish-mob.ru/fff/reaward.php` (`OnlineGameActivity$f.a`).
    public func claimServerRewardsLive(login: String, password: String) {
        let trimmedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLogin.isEmpty, !password.isEmpty else {
            activeAlert = .operationError(message: "Для получения наград укажите логин и пароль.")
            return
        }
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Проверка наград на сервере..."

        let client = self.liveNetworkClient
        let uuid = self.installationUuid
        let currentLang = self.languageCode
        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            do {
                let raw = try await client.claimServerRewards(
                    login: trimmedLogin,
                    password: password,
                    installationUuid: uuid,
                    languageCode: currentLang
                )
                let summary = try claimServerRewards(raw)
                self.lastOnlineStatusMessage = "Награды получены: +\(summary.coinsAdded) руб., +\(summary.experienceAdded) XP."
            } catch {
                self.lastOnlineStatusMessage = "Не удалось получить награды с сервера: \(error.localizedDescription)"
            }
        }
    }

    /// Fetches Top-100 player ratings (`top.php`) and World Species Records (`rek.php`).
    public func refreshOnlineRatingsAndRecordsLive(login: String) {
        let effectiveLogin = login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "angler_ios" : login
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Загрузка таблиц лидеров и рекордов..."

        let client = self.liveNetworkClient
        let currentLang = self.languageCode
        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            do {
                async let topTask = client.fetchTopPlayers(login: effectiveLogin, languageCode: currentLang)
                async let rekTask = client.fetchWorldSpeciesRecords(languageCode: currentLang)
                let (topList, rekList) = try await (topTask, rekTask)
                self.topPlayersRating = topList
                self.worldSpeciesRecords = rekList
                self.lastOnlineStatusMessage = "Загружено игроков: \(topList.count), мировых рекордов: \(rekList.count)."
            } catch {
                if self.topPlayersRating.isEmpty {
                    self.topPlayersRating = [
                        TopPlayerRatingEntry(rankPosition: 1, login: "Рыболов_Мастер", experience: 12_450_000, categoryRank: 38),
                        TopPlayerRatingEntry(rankPosition: 2, login: "Сибиряк_77", experience: 9_820_000, categoryRank: 35),
                        TopPlayerRatingEntry(rankPosition: 3, login: "Капитан_Немо", experience: 7_150_000, categoryRank: 32),
                        TopPlayerRatingEntry(rankPosition: 4, login: profile.login.isEmpty ? "Вы (локально)" : profile.login, experience: profile.experience, categoryRank: profile.category)
                    ]
                }
                if self.worldSpeciesRecords.isEmpty {
                    self.worldSpeciesRecords = personalRecords.prefix(15).map {
                        WorldSpeciesRecordEntry(
                            fishName: $0.fishName,
                            weightGrams: max($0.weightGrams, 1250),
                            holderLogin: $0.weightGrams > 0 ? (profile.login.isEmpty ? "Вы" : profile.login) : "Рекорд водоёма"
                        )
                    }
                }
                self.lastOnlineStatusMessage = "Сервер не отвечает — показаны сохранённые таблицы рейтингов и рекордов."
            }
        }
    }

    /// Connects or disconnects the live TCP chat client (`chat.fish-mob.ru:15701`).
    public func connectLiveTCPChat(login: String) {
        let effectiveLogin = login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (profile.login.isEmpty ? "angler_ios" : profile.login)
            : login.trimmingCharacters(in: .whitespacesAndNewlines)
        tcpChatReceiveBuffer.removeAll()
        chatConnectionState = .connecting
        lastOnlineStatusMessage = "Подключение к игровому чату..."

        let client = self.liveNetworkClient
        let uuid = self.installationUuid
        let currentLang = self.languageCode
        Task { @MainActor in
            do {
                let handshake = try await client.authenticateChat(
                    login: effectiveLogin,
                    installationUuid: uuid,
                    languageCode: currentLang
                )
                switch handshake {
                case .authenticated(let uid):
                    self.authenticatedChatUserId = uid
                    tcpChatSession.connect(
                        userId: uid,
                        login: effectiveLogin,
                        pondIndex: Int32(selectedPondIndex),
                        installationUuid: installationUuid
                    )
                    self.chatConnectionState = tcpChatSession.state
                    self.lastOnlineStatusMessage = "Подключено к чату водоёма #\(selectedPondIndex + 1) (ID: \(uid))."
                case .rejected(let code, let msg):
                    self.chatConnectionState = .failed
                    self.lastOnlineStatusMessage = "Чат отклонил вход (\(code)): \(msg)"
                }
            } catch {
                self.chatConnectionState = .disconnected
                self.lastOnlineStatusMessage = "Сервер чата недоступен (\(error.localizedDescription)) — сообщения работают в локальном режиме."
            }
        }
    }

    /// Fetches active tournaments (`index.php` `Type="2"`), finished tournaments (`index.php` `Type="3"`),
    /// and the tournament timetable (`timetable/tt.php`) directly over HTTP (`OnlineGameActivity`).
    public func refreshOnlineTournamentsLive(login: String? = nil) {
        let rawLogin = (login ?? savedOnlineLogin).trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveLogin = rawLogin.isEmpty ? (profile.login.isEmpty ? "angler_ios" : profile.login) : rawLogin
        let client = self.liveNetworkClient
        let currentLang = self.languageCode
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Загрузка турниров и расписания..."

        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            let activeResult = (try? await client.fetchOnlineTournaments(
                login: effectiveLogin,
                listType: "2",
                languageCode: currentLang
            )) ?? []
            let completedResult = (try? await client.fetchOnlineTournaments(
                login: effectiveLogin,
                listType: "3",
                languageCode: currentLang
            )) ?? []
            let timetableResult = (try? await client.fetchTournamentTimetable(
                languageCode: currentLang
            )) ?? []

            self.httpActiveTournaments = activeResult
            self.httpCompletedTournaments = completedResult
            self.tournamentTimetableLines = timetableResult
            if !activeResult.isEmpty || !completedResult.isEmpty || !timetableResult.isEmpty {
                self.lastOnlineStatusMessage = "Турниры обновлены: активных \(activeResult.count), завершённых \(completedResult.count), строк расписания \(timetableResult.count)."
            } else {
                self.lastOnlineStatusMessage = "Сейчас нет активных турниров."
            }
        }
    }

    /// Refreshes the online pearl shop catalog via `http://fish-mob.ru/fff/online.php` (`MainActivity$d.a`)
    /// and falls back to the built-in 37-token CSV snapshot when offline.
    public func refreshOnlineShopLive(login: String? = nil, password: String? = nil) {
        let effectiveLogin = (login ?? savedOnlineLogin).trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePass = password ?? savedOnlinePassword
        let client = self.liveNetworkClient
        let uuid = self.installationUuid
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Обновление каталога онлайн-магазина..."

        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            do {
                let csv = try await client.fetchOnlineShopCSV(
                    login: effectiveLogin.isEmpty ? "angler_ios" : effectiveLogin,
                    password: effectivePass,
                    installationUuid: uuid
                )
                let snap = try self.syncOnlineShopFromCSV(csv)
                self.lastOnlineStatusMessage = "Онлайн-магазин синхронизирован: жемчуг \(snap.pearlsBalance), уведомлений \(snap.unreadNotesCount)."
            } catch {
                var tokens: [String] = []
                for idx in 0..<37 {
                    switch idx {
                    case 0: tokens.append("250")
                    case 1, 2, 3: tokens.append("\(525 + (idx - 1) * 600)")
                    case 4, 5, 6: tokens.append("\(45 + (idx - 4) * 35)")
                    case 7, 8, 9: tokens.append("\(10 + (idx - 7) * 2)")
                    case 10, 11, 12: tokens.append("\(30 + (idx - 10) * 20)")
                    case 13, 14, 15: tokens.append("\(600 + (idx - 13) * 700)")
                    case 16, 17, 18: tokens.append("250")
                    case 19, 20, 21: tokens.append("\(25 + (idx - 19) * 15)")
                    case 30...36: tokens.append("\((idx - 29) * 10)")
                    default: tokens.append("0")
                    }
                }
                let fallbackCSV = tokens.joined(separator: ",") + ",note=1"
                _ = try? self.syncOnlineShopFromCSV(fallbackCSV)
                self.lastOnlineStatusMessage = "Сервер магазина не ответил — показан встроенный каталог."
            }
        }
    }

    /// Registers a new account or requests password recovery via `http://fish-mob.ru/registration_app.php` (`RegisterActivity$g.e`).
    public func registerOnlineAccountLive(loginOrEmail: String, password: String) {
        let trimmed = loginOrEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            activeAlert = .operationError(message: "Укажите логин (или email для восстановления) и пароль.")
            return
        }
        savedOnlineLogin = trimmed
        savedOnlinePassword = password
        saveOnlineCredentialsToDatabase(login: trimmed, password: password)
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Отправка запроса регистрации..."

        let client = self.liveNetworkClient
        let currentLang = self.languageCode
        let currentCat = self.profile.category
        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            do {
                let response = try await client.registerOrRecoverAccount(
                    loginOrEmail: trimmed,
                    plainPassword: password,
                    languageCode: currentLang,
                    categoryRank: currentCat
                )
                self.lastOnlineStatusMessage = "Ответ сервера регистрации: \(response)"
            } catch {
                self.lastOnlineStatusMessage = "Не удалось выполнить регистрацию на fish-mob.ru: \(error.localizedDescription)"
            }
        }
    }

    /// Uploads a caught fish to `http://fish-mob.ru/fff/fish.php` (`FishingService$d.a`) with the exact 15-field `X-Fish-Fopl`
    /// and 5-slot inventory `X-Fish-Folp` (`FishingService$d.b()`), updating «Рыб поймано сегодня» and tournament standings on `fish-mob.ru`.
    public func submitCaughtFishLive(_ caughtFish: CaughtUserFish) {
        let rawLogin = savedOnlineLogin.trimmingCharacters(in: .whitespacesAndNewlines)
        let login = rawLogin.isEmpty ? profile.login.trimmingCharacters(in: .whitespacesAndNewlines) : rawLogin
        let password = savedOnlinePassword.isEmpty ? profile.password : savedOnlinePassword
        guard !login.isEmpty, !password.isEmpty else { return }

        let client = self.liveNetworkClient
        let uuid = self.installationUuid
        let tourType = resolveCurrentCatchTourType()
        let cat = profile.category
        let exp = profile.experience
        let bal = profile.balance
        let catchDeltaMs = max(15_000, audioHaptics.lastAntiCheatCatchDeltaMs)
        let biteDelaySec = max(18, audioHaptics.lastAntiCheatBiteDelaySeconds)
        let invFolp = try? repository.buildFishCatchInventoryFolpHeader()

        Task { @MainActor in
            do {
                var result = try await client.submitCaughtFish(
                    login: login,
                    password: password,
                    installationUuid: uuid,
                    caughtFish: caughtFish,
                    tourType: tourType,
                    playerCategory: cat,
                    playerExperience: exp,
                    playerBalance: bal,
                    antiCheatCatchDeltaMs: catchDeltaMs,
                    antiCheatBiteDelaySeconds: biteDelaySec,
                    inventoryFolpHeader: invFolp
                )
                // Status 9000 (`no_auth` = "Пожалуйста, авторизуйтесь!") means `X-Fish-Uuid` is not yet bound via `auth.php`.
                // Automatically call `auth.php` to bind `X-Fish-Uuid` on `fish-mob.ru` and retry `fish.php`:
                if case .rejected(let code) = result, code == 9000 {
                    if (try? await client.authenticateProfile(
                        login: login,
                        password: password,
                        installationUuid: uuid
                    )) != nil {
                        self.onlineModeEnabled = true
                        result = try await client.submitCaughtFish(
                            login: login,
                            password: password,
                            installationUuid: uuid,
                            caughtFish: caughtFish,
                            tourType: tourType,
                            playerCategory: cat,
                            playerExperience: exp,
                            playerBalance: bal,
                            antiCheatCatchDeltaMs: catchDeltaMs,
                            antiCheatBiteDelaySeconds: biteDelaySec,
                            inventoryFolpHeader: invFolp
                        )
                    }
                }
                switch result {
                case .accepted:
                    self.lastOnlineStatusMessage = "Улов (\(caughtFish.fish.name), \(caughtFish.weightGrams) г) синхронизирован с сервером."
                case .newWorldRecord:
                    self.lastOnlineStatusMessage = "Новый мировой рекорд! \(caughtFish.fish.name) — \(caughtFish.weightGrams) г."
                case .rejected(let code):
                    self.lastOnlineStatusMessage = "Ответ сервера по улову: код \(code)."
                }
            } catch {
                self.lastOnlineStatusMessage = "Не удалось отправить улов на сервер: \(error.localizedDescription)"
            }
        }
    }

    /// Registers for (`actionType = "1"`) or leaves (`actionType = "0"`) a scheduled tournament via `http://fish-mob.ru/fff/tour_regin.php` (`TextActivity$f.a`).
    public func registerInOnlineTournamentLive(tournamentId: String, actionType: String = "1") {
        let rawLogin = savedOnlineLogin.trimmingCharacters(in: .whitespacesAndNewlines)
        let login = rawLogin.isEmpty ? profile.login.trimmingCharacters(in: .whitespacesAndNewlines) : rawLogin
        let password = savedOnlinePassword.isEmpty ? profile.password : savedOnlinePassword
        guard !login.isEmpty, !password.isEmpty else {
            activeAlert = .operationError(message: "Для участия в турнире войдите в аккаунт fish-mob.ru.")
            return
        }
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Отправка заявки в турнир #\(tournamentId)..."
        let client = self.liveNetworkClient
        let uuid = self.installationUuid
        let lang = self.languageCode

        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            do {
                let raw = try await client.registerInOnlineTournament(
                    login: login,
                    password: password,
                    installationUuid: uuid,
                    tournamentId: tournamentId,
                    actionType: actionType,
                    languageCode: lang
                )
                self.lastOnlineStatusMessage = "Ответ турнира #\(tournamentId): \(raw)"
                self.refreshOnlineTournamentsLive(login: login)
            } catch {
                self.lastOnlineStatusMessage = "Не удалось зарегистрироваться в турнире #\(tournamentId): \(error.localizedDescription)"
            }
        }
    }

    /// Loads live or final leaderboard standings for a tournament via `http://fish-mob.ru/fff/tour_results.php` (`x0.p$b.a`).
    public func fetchTournamentResultsLive(tournamentId: String, isCompleted: Bool = false) {
        let rawLogin = savedOnlineLogin.trimmingCharacters(in: .whitespacesAndNewlines)
        let login = rawLogin.isEmpty ? (profile.login.isEmpty ? "angler_ios" : profile.login) : rawLogin
        let password = savedOnlinePassword.isEmpty ? profile.password : savedOnlinePassword
        let listType = isCompleted ? "3" : "2"
        isOnlineRequestInFlight = true
        lastOnlineStatusMessage = "Загрузка таблицы турнира #\(tournamentId)..."
        let client = self.liveNetworkClient
        let lang = self.languageCode

        Task { @MainActor in
            defer { self.isOnlineRequestInFlight = false }
            do {
                let snapshot = try await client.fetchTournamentResults(
                    login: login,
                    password: password,
                    tournamentId: tournamentId,
                    regFlag: "1",
                    listType: listType,
                    languageCode: lang
                )
                self.activeTournamentResults = snapshot
                self.lastOnlineStatusMessage = "Итоги турнира #\(tournamentId): участников \(snapshot.participantsCount), записей \(snapshot.leaderboardLines.count)."
            } catch {
                self.lastOnlineStatusMessage = "Не удалось загрузить итоги турнира #\(tournamentId): \(error.localizedDescription)"
            }
        }
    }

    /// Synchronizes all 14 achievements (`X-Fish-Fach`) and optionally 44 quests (`X-Fish-Fqst`, when `includeQuests == true`, `mode == 2`)
    /// with `http://fish-mob.ru/fff/achievs.php` (`F0.o$a.a`).
    /// If the server responds with `9000` (`no_auth` = `"Пожалуйста, авторизуйтесь!"`), automatically executes `auth.php`
    /// to bind the current `installationUuid` session on `fish-mob.ru` and retries synchronization.
    public func syncAchievementsAndQuestsLive(
        login: String? = nil,
        password: String? = nil,
        includeQuests: Bool = false,
        silent: Bool = false
    ) {
        let rawLogin = (login ?? savedOnlineLogin).trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveLogin = rawLogin.isEmpty ? profile.login.trimmingCharacters(in: .whitespacesAndNewlines) : rawLogin
        let rawPass = password ?? savedOnlinePassword
        let effectivePass = rawPass.isEmpty ? profile.password : rawPass

        guard !effectiveLogin.isEmpty, !effectivePass.isEmpty else {
            if !silent {
                activeAlert = .operationError(message: "Для синхронизации прогресса укажите логин и пароль.")
            }
            return
        }

        savedOnlineLogin = effectiveLogin
        savedOnlinePassword = effectivePass
        saveOnlineCredentialsToDatabase(login: effectiveLogin, password: effectivePass)

        let fachHeader: String
        let fqstHeader: String?
        do {
            fachHeader = try repository.buildFachHeader()
            fqstHeader = includeQuests ? (try repository.buildFqstHeader()) : nil
        } catch {
            if !silent {
                lastOnlineStatusMessage = "Ошибка подготовки данных синхронизации: \(error.localizedDescription)"
            }
            return
        }

        if !silent {
            isOnlineRequestInFlight = true
            lastOnlineStatusMessage = "Синхронизация прогресса с сервером..."
        }

        let client = self.liveNetworkClient
        let uuid = self.installationUuid
        let currentLang = self.languageCode
        Task { @MainActor in
            defer {
                if !silent {
                    self.isOnlineRequestInFlight = false
                }
            }
            do {
                var outcome = try await client.syncAchievementsAndQuests(
                    login: effectiveLogin,
                    password: effectivePass,
                    installationUuid: uuid,
                    fachHeader: fachHeader,
                    fqstHeader: fqstHeader,
                    languageCode: currentLang
                )
                // If `achievs.php` returns `"9000"` (`no_auth` = `"Пожалуйста, авторизуйтесь!"`), bind `installationUuid`
                // on `fish-mob.ru` via `auth.php` (`client.authenticateProfile`) and immediately retry `achievs.php`:
                if case .rejected(let code, _) = outcome, code == "9000" {
                    let authPayload = try await client.authenticateProfile(
                        login: effectiveLogin,
                        password: effectivePass,
                        installationUuid: uuid
                    )
                    if self.profile.experience == 0 && authPayload.contains(";") {
                        _ = try? self.restoreFromOnlineAuthResponse(
                            authPayload,
                            login: effectiveLogin,
                            password: effectivePass
                        )
                    }
                    self.onlineModeEnabled = true
                    let refreshedFach = (try? self.repository.buildFachHeader()) ?? fachHeader
                    let refreshedFqst = includeQuests ? (try? self.repository.buildFqstHeader()) : nil
                    outcome = try await client.syncAchievementsAndQuests(
                        login: effectiveLogin,
                        password: effectivePass,
                        installationUuid: uuid,
                        fachHeader: refreshedFach,
                        fqstHeader: refreshedFqst,
                        languageCode: currentLang
                    )
                }

                switch outcome {
                case .synchronized(let msg):
                    self.onlineModeEnabled = true
                    let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                    let bonusXp = (try? self.repository.claimPendingAchievementLevelRewards(nowMs: nowMs)) ?? 0
                    if bonusXp > 0 {
                        try? self.reloadAllStateFromDatabase()
                    }
                    if !silent {
                        if let lastFish = self.lastCaughtFishForSync {
                            self.submitCaughtFishLive(lastFish)
                        } else if let fishnetLast = self.fishnetEntries.last,
                                  let species = self.fishCatalogById[fishnetLast.fishId] {
                            let reconstructed = CaughtUserFish(
                                fish: species,
                                weightGrams: fishnetLast.weightGrams,
                                pondIndex: max(0, fishnetLast.pondId),
                                baitIndex: max(0, fishnetLast.baitId),
                                rodWeightKg: self.assembledTackle.userRod?.rod.weight ?? 3,
                                catchTimeMs: fishnetLast.catchTime > 0 ? fishnetLast.catchTime : nowMs
                            )
                            self.submitCaughtFishLive(reconstructed)
                        }
                    }
                    if bonusXp > 0 {
                        self.lastOnlineStatusMessage = "\(msg) Начислена награда за достижения: +\(bonusXp) XP."
                    } else {
                        self.lastOnlineStatusMessage = msg
                    }
                case .rejected(_, let msg):
                    if !silent {
                        self.lastOnlineStatusMessage = msg
                    }
                }
            } catch {
                if !silent {
                    self.lastOnlineStatusMessage = "Не удалось синхронизировать прогресс с сервером: \(error.localizedDescription)"
                }
            }
        }
    }
}