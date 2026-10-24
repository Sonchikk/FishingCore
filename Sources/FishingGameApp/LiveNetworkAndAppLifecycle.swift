import Foundation
import FishingCore
import FishingDatabase
#if canImport(Network)
import Network
#endif

// MARK: - 1. Complete `URLRequest` Factory for All 17 `fish-mob.ru` & `chat.fish-mob.ru` Endpoints (`NETWORK.md` Section 2)

public enum FishingHttpRequestBuilder: Sendable {

    /// Builds `GET http://fish-mob.ru/fff/auth.php` (`C0.a$h.b`).
    public static func makeAuthProfileRequest(
        login: String,
        password: String,
        installationUuid: String
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.authProfile.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(
            FishingNetworkCrypto.makeAuthOrAchievsFoplHeader(
                login: login,
                password: password,
                installationUuid: installationUuid
            ),
            forHTTPHeaderField: "X-Fish-Fopl"
        )
        req.setValue(FishingNetworkCrypto.installationUuidMd5(installationUuid), forHTTPHeaderField: "X-Fish-Uuid")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        return req
    }

    /// Builds `GET http://chat.fish-mob.ru/auth_chat.php` (`SplashScreenActivity$d.a`).
    public static func makeChatAuthRequest(
        login: String,
        installationUuid: String,
        languageCode: String = "ru"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.authChat.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(
            FishingNetworkCrypto.makeChatAuthFoplHeader(
                login: login,
                installationUuid: installationUuid
            ),
            forHTTPHeaderField: "X-Fish-Fopl"
        )
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-Lng")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/fish.php` (`FishingService$d.a`).
    public static func makeSubmitFishCatchRequest(
        login: String,
        password: String,
        installationUuid: String,
        caughtFish: CaughtUserFish,
        tourType: Int = 0
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.submitFishCatch.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(
            FishingNetworkCrypto.makeFishCatchFoplHeader(
                login: login,
                password: password,
                installationUuid: installationUuid
            ),
            forHTTPHeaderField: "X-Fish-Fopl"
        )
        req.setValue(FishingNetworkCrypto.installationUuidMd5(installationUuid), forHTTPHeaderField: "X-Fish-Uuid")
        req.setValue(String(caughtFish.catchTimeMs), forHTTPHeaderField: "X-Fish-Date")
        req.setValue(
            FishingNetworkCrypto.makeFishCatchFolpHeader(
                pondId0Based: caughtFish.pondIndex,
                baitId0Based: caughtFish.baitIndex,
                fishId0Based: max(0, caughtFish.fish.id - 1),
                weightGrams: caughtFish.weightGrams,
                tourType: tourType
            ),
            forHTTPHeaderField: "X-Fish-Folp"
        )
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/buyballs.php` (`BuyGoods$b.a` & `RewardedGoods$b.a`, `NETWORK.md` Section 2 #8).
    public static func makeBuyPearlsRequest(
        login: String,
        password: String,
        pearlsAmount: Int,
        receiptSignData: String,
        receiptSignature: String
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.buyPearls.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4Y2Q, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        req.setValue(FishingNetworkCrypto.doubleMd5Password(password), forHTTPHeaderField: "X-Fish-Pass")
        req.setValue(FishingNetworkCrypto.keyBuyBalls, forHTTPHeaderField: "X-Fish-KeyBuy")
        req.setValue(String(pearlsAmount), forHTTPHeaderField: "X-Fish-Balls")
        req.setValue(receiptSignData, forHTTPHeaderField: "X-Fish-SignData")
        req.setValue(receiptSignature, forHTTPHeaderField: "X-Fish-Sign")
        return req
    }

    /// Builds `GET http://fish-mob.ru/registration_app.php` (`RegisterActivity$g.e`, `NETWORK.md` Section 1.2 & Section 2 #9).
    /// Preserves the confirmed bytecode behavior: `X-Fish-Pass` is URL-encoded plain text (NOT double-MD5),
    /// and `X-Fish-regType` is `"1"` if the identifier contains `"@"` (password recovery), else `"0"` (new registration).
    public static func makeAccountRegistrationOrRecoveryRequest(
        loginOrEmail: String,
        plainPassword: String,
        sex: String = "1",
        displayName: String = "",
        email: String = "",
        about: String = "",
        languageCode: String = "ru",
        categoryRank: Int = 0
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.registerAccount.rawValue)!)
        req.httpMethod = "GET"
        let encodedPass = plainPassword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? plainPassword
        let regType = loginOrEmail.contains("@") ? "1" : "0"

        req.setValue(FishingNetworkCrypto.versionMeeks4Y2Q, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(loginOrEmail, forHTTPHeaderField: "X-Fish-Login")
        req.setValue(encodedPass, forHTTPHeaderField: "X-Fish-Pass")
        req.setValue(FishingNetworkCrypto.keyRegister, forHTTPHeaderField: "X-Fish-KeyReg")
        req.setValue(sex, forHTTPHeaderField: "X-Fish-Sex")
        req.setValue(displayName, forHTTPHeaderField: "X-Fish-Name")
        req.setValue(email, forHTTPHeaderField: "X-Fish-Email")
        req.setValue(about, forHTTPHeaderField: "X-Fish-About")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        req.setValue(String(categoryRank), forHTTPHeaderField: "X-Fish-Category")
        req.setValue(regType, forHTTPHeaderField: "X-Fish-regType")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/timetable/tt.php` (`OnlineGameActivity$d.a`, `NETWORK.md` Section 2 #13).
    public static func makeTournamentTimetableRequest(
        languageCode: String = "ru",
        utcOffsetSeconds: Int = TimeZone.current.secondsFromGMT()
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.tournamentTimetable.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4_15, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        req.setValue(String(utcOffsetSeconds), forHTTPHeaderField: "X-Fish-OffsetUTC")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/online.php` (`MainActivity$d.a`, `NETWORK.md` Section 2 #5).
    public static func makeOnlineShopRequest(
        login: String,
        password: String,
        installationUuid: String
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.onlineShopCatalog.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4Y2Q, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        req.setValue(FishingNetworkCrypto.doubleMd5Password(password), forHTTPHeaderField: "X-Fish-Pass")
        req.setValue(FishingNetworkCrypto.installationUuidMd5(installationUuid), forHTTPHeaderField: "X-Fish-Uuid")
        req.setValue("1", forHTTPHeaderField: "X-Fish-Notes")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/reaward.php` (`OnlineGameActivity$f.a`, `NETWORK.md` Section 2 #7).
    public static func makeServerRewardsRequest(
        login: String,
        password: String,
        installationUuid: String,
        languageCode: String = "ru"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.claimRewards.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4Y2Q, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        req.setValue(FishingNetworkCrypto.doubleMd5Password(password), forHTTPHeaderField: "X-Fish-Pass")
        req.setValue("1", forHTTPHeaderField: "X-Fish-Notes")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        req.setValue(FishingNetworkCrypto.appSignConstant, forHTTPHeaderField: "X-Fish-AppSign")
        req.setValue(FishingNetworkCrypto.installationUuidMd5(installationUuid), forHTTPHeaderField: "X-Fish-Uuid")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/top.php` (`OnlineGameActivity$b.a`, `NETWORK.md` Section 2 #15).
    public static func makeTopPlayersRequest(
        login: String,
        languageCode: String = "ru"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.topPlayersRating.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4_15, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/rek.php` (`OnlineGameActivity$c.a`, `NETWORK.md` Section 2 #16).
    public static func makeWorldRecordsRequest(
        languageCode: String = "ru"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.worldSpeciesRecords.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4_15, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        return req
    }
}

// MARK: - 2. Parsers for `auth_chat.php`, `fish.php`, `top.php` & `rek.php`

public enum ChatAuthHandshakeResult: Sendable, Equatable {
    case authenticated(userId: Int32)
    case rejected(statusCode: Int, message: String)
}

public enum FishCatchUploadResult: Sendable, Equatable {
    case accepted                       // status=1000
    case newWorldRecord                 // status=1100
    case rejected(statusCode: Int)
}

public struct TopPlayerRatingEntry: Sendable, Equatable, Identifiable {
    public let rankPosition: Int
    public let login: String
    public let experience: Int
    public let categoryRank: Int

    public var id: String { "\(rankPosition)_\(login)" }

    public init(rankPosition: Int, login: String, experience: Int, categoryRank: Int) {
        self.rankPosition = rankPosition
        self.login = login
        self.experience = experience
        self.categoryRank = categoryRank
    }
}

public struct WorldSpeciesRecordEntry: Sendable, Equatable, Identifiable {
    public let fishName: String
    public let weightGrams: Int
    public let holderLogin: String

    public var id: String { "\(fishName)_\(holderLogin)_\(weightGrams)" }

    public init(fishName: String, weightGrams: Int, holderLogin: String) {
        self.fishName = fishName
        self.weightGrams = weightGrams
        self.holderLogin = holderLogin
    }
}

public enum FishingOnlineResponseParser: Sendable {

    /// Parses `auth_chat.php` response (`SplashScreenActivity$d.a`, `NETWORK.md` Section 2 #2):
    /// `"1:<userId>"` on success, `"0:..."` or `"2:..."..`"9:..."` on rejection.
    public static func parseChatAuthResponse(_ raw: String) -> ChatAuthHandshakeResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let code = Int(parts[0]) else {
            return .rejected(statusCode: -1, message: trimmed)
        }
        if code == 1, let uid = Int32(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
            return .authenticated(userId: uid)
        }
        return .rejected(statusCode: code, message: parts[1])
    }

    /// Parses `fish.php` response (`FishingService$d.a`, `NETWORK.md` Section 2 #3):
    /// `"status=1000"` -> `.accepted`, `"status=1100"` -> `.newWorldRecord`.
    public static func parseFishCatchUploadResponse(_ raw: String) -> FishCatchUploadResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for token in trimmed.components(separatedBy: CharacterSet(charactersIn: ",;&\n\r")) {
            let kv = token.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if kv.count == 2, kv[0] == "status", let code = Int(kv[1]) {
                switch code {
                case 1000: return .accepted
                case 1100: return .newWorldRecord
                default: return .rejected(statusCode: code)
                }
            }
        }
        return .rejected(statusCode: -1)
    }

    /// Parses `top.php` top players lines (`login:exp:category` or `rank:login:exp:category`).
    public static func parseTopPlayersResponse(_ raw: String) -> [TopPlayerRatingEntry] {
        var result: [TopPlayerRatingEntry] = []
        for (idx, line) in raw.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let cols = trimmed.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if cols.count >= 4,
               let rank = Int(cols[0]),
               let exp = Int(cols[2]),
               let cat = Int(cols[3]) {
                result.append(TopPlayerRatingEntry(rankPosition: rank, login: cols[1], experience: exp, categoryRank: cat))
            } else if cols.count == 3,
                      let exp = Int(cols[1]),
                      let cat = Int(cols[2]) {
                result.append(TopPlayerRatingEntry(rankPosition: idx + 1, login: cols[0], experience: exp, categoryRank: cat))
            }
        }
        return result
    }

    /// Parses `rek.php` world species records (`fishName:weightGrams:holderLogin`).
    public static func parseWorldSpeciesRecordsResponse(_ raw: String) -> [WorldSpeciesRecordEntry] {
        var result: [WorldSpeciesRecordEntry] = []
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let cols = trimmed.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cols.count >= 3, let weight = Int(cols[1]) else { continue }
            result.append(WorldSpeciesRecordEntry(fishName: cols[0], weightGrams: weight, holderLogin: cols[2]))
        }
        return result
    }
}

// MARK: - 3. iOS 18+ App Transport Security (`Info.plist`) Configuration (`NETWORK.md` Section 7.1 #5)

public enum FishingIOSAppConfiguration: Sendable {
    public static let bundleIdentifier = "com.evados.fishing.ios"
    public static let marketingVersion = "1.81"
    public static let buildVersionCode = "203"
    public static let chatServerHost = "chat.fish-mob.ru"
    public static let chatServerPort: UInt16 = 15701
    public static let chatConnectTimeoutSeconds: TimeInterval = 30.0
    public static let chatReadTimeoutSeconds: TimeInterval = 60.0

    /// Generates the `NSAppTransportSecurity` exception dictionary required on iOS 18+
    /// to allow cleartext HTTP requests to `fish-mob.ru` and `chat.fish-mob.ru`.
    public static var appTransportSecurityPlistDictionary: [String: Any] {
        [
            "NSAllowsArbitraryLoads": false,
            "NSExceptionDomains": [
                "fish-mob.ru": [
                    "NSIncludesSubdomains": true,
                    "NSExceptionAllowsInsecureHTTPLoads": true
                ],
                "chat.fish-mob.ru": [
                    "NSIncludesSubdomains": true,
                    "NSExceptionAllowsInsecureHTTPLoads": true
                ]
            ]
        ]
    }
}

// MARK: - 4. Executable iOS App Bundle & `INSTALLATION` UUID Bootstrapper (`F0.e.a`, `NETWORK.md` Section 1.1)

/// Reconstructs `F0.e` (`InstallationIdProvider`: persistent `<FilesDir>/INSTALLATION` UUID v4)
/// and bootstraps `Application Support/FishingForFriends/fishing2.db` from the `.app` bundle's `GameData`
/// directory on first launch while keeping subsequent app startups instantaneous.
public enum AppBundleDatabaseBootstrapper: Sendable {
    public static let appSupportSubdirectoryName = "FishingForFriends"
    public static let installationFilename = "INSTALLATION"
    public static let databaseFilename = "fishing2.db"
    public static let bundledGameDataFolderName = "GameData"
    public static let fullCatalogFishSpeciesCount = 141

    /// Default `Application Support/FishingForFriends` directory URL on iOS / macOS.
    public static func defaultAppSupportDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appSupportSubdirectoryName, isDirectory: true)
    }

    /// Exact reconstruction of `F0.e.a(Context)` (`NETWORK.md` Section 1.1):
    /// Reads `<directoryURL>/INSTALLATION` if present and non-empty; otherwise generates a lowercased
    /// UUID v4 string (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) and writes it atomically in UTF-8.
    public static func resolveOrCreateInstallationUuid(in directoryURL: URL) throws -> String {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let installationFileURL = directoryURL.appendingPathComponent(installationFilename, isDirectory: false)
        if FileManager.default.fileExists(atPath: installationFileURL.path),
           let existingData = try? Data(contentsOf: installationFileURL),
           let existingString = String(data: existingData, encoding: .utf8)?
               .trimmingCharacters(in: .whitespacesAndNewlines),
           !existingString.isEmpty {
            return existingString
        }

        let generatedUuid = UUID().uuidString.lowercased()
        guard let utf8Data = generatedUuid.data(using: .utf8) else {
            return generatedUuid
        }
        try utf8Data.write(to: installationFileURL, options: .atomic)
        return generatedUuid
    }

    /// Locates the bundled `GameData` directory containing the 13 reference JSON files (`fishes.json`, etc.).
    public static func resolveBundledGameDataURL(
        explicitURL: URL? = nil,
        bundle: Bundle = .main
    ) -> URL? {
        var candidates: [URL] = []
        if let explicitURL {
            candidates.append(explicitURL)
        }
        if let bundleGameData = bundle.url(forResource: bundledGameDataFolderName, withExtension: nil) {
            candidates.append(bundleGameData)
        }
        if let resourceRoot = bundle.resourceURL {
            candidates.append(resourceRoot.appendingPathComponent(bundledGameDataFolderName, isDirectory: true))
            candidates.append(resourceRoot)
        }

        for candidate in candidates {
            let fishesJSONPath = candidate.appendingPathComponent("fishes.json").path
            if FileManager.default.fileExists(atPath: fishesJSONPath) {
                return candidate
            }
        }
        return nil
    }

    /// Checks whether the SQLite database at `databasePath` already contains the full 141-species reference catalog.
    public static func isFullReferenceCatalogPopulated(atDatabasePath databasePath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: databasePath),
              let conn = try? SQLiteConnection(path: databasePath) else {
            return false
        }
        let fishCount = (try? conn.scalarInt("SELECT COUNT(*) FROM fishes;")) ?? 0
        let pondCount = (try? conn.scalarInt("SELECT COUNT(*) FROM ref_ponds;")) ?? 0
        return fishCount >= fullCatalogFishSpeciesCount && pondCount >= 15
    }

    /// Bootstraps `FishingAppCoordinator` for the standalone iOS application (`FishingIOSApp.app`):
    /// 1. Ensures `Application Support/FishingForFriends` exists.
    /// 2. Loads or creates the persistent `INSTALLATION` UUID (`F0.e.a`).
    /// 3. On first launch (or if `< 141` fish species exist in `fishing2.db`), imports all 13 reference JSON files
    ///    from `GameData` and signs every row with `installationUuid`.
    /// 4. On subsequent launches, opens `fishing2.db` directly without re-importing static JSONs.
    @MainActor
    public static func bootstrapAppCoordinator(
        appSupportDirectory: URL? = nil,
        bundledGameDataURL: URL? = nil,
        initialHour: Int = 6,
        initialMinute: Int = 0,
        viewWidth: Int = 393,
        viewHeight: Int = 600,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        notificationScheduling: any SystemNotificationScheduling = LiveSystemNotifications()
    ) throws -> FishingAppCoordinator {
        let supportDir = appSupportDirectory ?? defaultAppSupportDirectoryURL()
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        let installationUuid = try resolveOrCreateInstallationUuid(in: supportDir)
        let dbPath = supportDir.appendingPathComponent(databaseFilename, isDirectory: false).path
        let resolvedGameDataURL = resolveBundledGameDataURL(explicitURL: bundledGameDataURL)

        let jsonDirForInit: URL?
        if isFullReferenceCatalogPopulated(atDatabasePath: dbPath) {
            jsonDirForInit = nil
        } else {
            jsonDirForInit = resolvedGameDataURL
        }

        return try FishingAppCoordinator(
            databasePath: dbPath,
            jsonDataDirectoryURL: jsonDirForInit,
            installationUuid: installationUuid,
            initialHour: initialHour,
            initialMinute: initialMinute,
            viewWidth: viewWidth,
            viewHeight: viewHeight,
            nowMs: nowMs,
            notificationScheduling: notificationScheduling
        )
    }
}

// MARK: - 5. Background Bite Alarm Notification Scheduler (`CHECKMODE` / `AlarmManagerBroadcastReceiver`, `MECHANICS.md` Sections 2.2 & 3.1)

/// Reconstructs Android's `AlarmManager` + `AlarmManagerBroadcastReceiver` scheduled by `GameView.q(x, y)`
/// at `BEGINTIME` (`scheduledBiteTimeMs`) when `CHECKMODE` («Фоновый будильник поклёвки») is active.
public struct FishingBiteNotificationScheduler: Sendable, Equatable {
    public static let biteAlarmNotificationIdentifier = "com.evados.fishing.bite_alarm"

    public var authorizationGranted: Bool
    public private(set) var scheduledBiteTimeMs: Int64? = nil
    public private(set) var scheduledPondTitle: String? = nil
    public private(set) var scheduledCount: Int = 0
    public private(set) var cancelledCount: Int = 0
    private let notificationScheduling: any SystemNotificationScheduling

    public init(
        authorizationGranted: Bool = true,
        notificationScheduling: any SystemNotificationScheduling = LiveSystemNotifications()
    ) {
        self.authorizationGranted = authorizationGranted
        self.notificationScheduling = notificationScheduling
    }

    public static func == (lhs: FishingBiteNotificationScheduler, rhs: FishingBiteNotificationScheduler) -> Bool {
        lhs.authorizationGranted == rhs.authorizationGranted
            && lhs.scheduledBiteTimeMs == rhs.scheduledBiteTimeMs
            && lhs.scheduledPondTitle == rhs.scheduledPondTitle
            && lhs.scheduledCount == rhs.scheduledCount
            && lhs.cancelledCount == rhs.cancelledCount
    }

    public var isNotificationPending: Bool {
        scheduledBiteTimeMs != nil
    }

    /// Requests system notification permission via injected `SystemNotificationScheduling`.
    public func requestAuthorization() {
        notificationScheduling.requestAuthorization()
    }

    /// Schedules a local iOS notification for `scheduledBiteTimeMs` (`BEGINTIME`).
    public mutating func scheduleBiteAlarm(
        scheduledBiteTimeMs: Int64,
        nowMs: Int64,
        pondTitle: String
    ) {
        guard authorizationGranted else { return }
        self.scheduledBiteTimeMs = scheduledBiteTimeMs
        self.scheduledPondTitle = pondTitle
        self.scheduledCount += 1

        let delaySeconds = max(1.0, Double(scheduledBiteTimeMs - nowMs) / 1000.0)
        notificationScheduling.scheduleLocal(
            id: Self.biteAlarmNotificationIdentifier,
            title: "Рыбалка для друзей",
            body: "Клюёт на водоёме «\(pondTitle)»! Скорее подсекайте!",
            delaySeconds: delaySeconds
        )
    }

    /// Cancels a pending local bite notification if one was scheduled.
    public mutating func cancelPendingBiteAlarm() {
        guard scheduledBiteTimeMs != nil else { return }
        scheduledBiteTimeMs = nil
        scheduledPondTitle = nil
        cancelledCount += 1
        notificationScheduling.removePending(id: Self.biteAlarmNotificationIdentifier)
    }

    /// Removes all pending and delivered local notifications via injected `SystemNotificationScheduling`.
    public mutating func removeAllPendingBiteAlarms() {
        if scheduledBiteTimeMs != nil {
            scheduledBiteTimeMs = nil
            scheduledPondTitle = nil
            cancelledCount += 1
        }
        notificationScheduling.removeAllPending()
    }
}

// MARK: - 6. Live Async HTTP Network Client for `fish-mob.ru` & `chat.fish-mob.ru` (`NETWORK.md` Section 2)

public enum FishingLiveNetworkError: Error, LocalizedError, Sendable, Equatable {
    case invalidServerResponse(statusCode: Int)
    case emptyPayload
    case serverStatusRejected(code: String)
    case transportError(description: String)

    public var errorDescription: String? {
        switch self {
        case .invalidServerResponse(let code):
            return "Сервер вернул код HTTP \(code)."
        case .emptyPayload:
            return "Пустой ответ от сервера fish-mob.ru."
        case .serverStatusRejected(let code):
            return "Сервер отклонил запрос (код: \(code))."
        case .transportError(let desc):
            return "Сервер недоступен: \(desc)"
        }
    }
}

public struct FishingLiveNetworkClient: Sendable {
    public let timeoutInterval: TimeInterval

    public init(timeoutInterval: TimeInterval = 12.0) {
        self.timeoutInterval = timeoutInterval
    }

    public func executeStringRequest(_ request: URLRequest) async throws -> String {
        var configured = request
        configured.timeoutInterval = timeoutInterval
        do {
            let (data, response) = try await URLSession.shared.data(for: configured)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw FishingLiveNetworkError.invalidServerResponse(statusCode: http.statusCode)
            }
            guard let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                throw FishingLiveNetworkError.emptyPayload
            }
            return text
        } catch let err as FishingLiveNetworkError {
            throw err
        } catch {
            throw FishingLiveNetworkError.transportError(description: error.localizedDescription)
        }
    }

    public func authenticateProfile(
        login: String,
        password: String,
        installationUuid: String
    ) async throws -> String {
        let req = FishingHttpRequestBuilder.makeAuthProfileRequest(
            login: login,
            password: password,
            installationUuid: installationUuid
        )
        let raw = try await executeStringRequest(req)
        // Check if server returned a numeric rejection status `2000..7000` instead of a 7-section `;` payload
        if !raw.contains(";") {
            throw FishingLiveNetworkError.serverStatusRejected(code: raw)
        }
        return raw
    }

    public func authenticateChat(
        login: String,
        installationUuid: String,
        languageCode: String = "ru"
    ) async throws -> ChatAuthHandshakeResult {
        let req = FishingHttpRequestBuilder.makeChatAuthRequest(
            login: login,
            installationUuid: installationUuid,
            languageCode: languageCode
        )
        let raw = try await executeStringRequest(req)
        return FishingOnlineResponseParser.parseChatAuthResponse(raw)
    }

    public func fetchOnlineShopCSV(
        login: String,
        password: String,
        installationUuid: String
    ) async throws -> String {
        let req = FishingHttpRequestBuilder.makeOnlineShopRequest(
            login: login,
            password: password,
            installationUuid: installationUuid
        )
        return try await executeStringRequest(req)
    }

    public func claimServerRewards(
        login: String,
        password: String,
        installationUuid: String,
        languageCode: String = "ru"
    ) async throws -> String {
        let req = FishingHttpRequestBuilder.makeServerRewardsRequest(
            login: login,
            password: password,
            installationUuid: installationUuid,
            languageCode: languageCode
        )
        return try await executeStringRequest(req)
    }

    public func submitCaughtFish(
        login: String,
        password: String,
        installationUuid: String,
        caughtFish: CaughtUserFish,
        tourType: Int
    ) async throws -> FishCatchUploadResult {
        let req = FishingHttpRequestBuilder.makeSubmitFishCatchRequest(
            login: login,
            password: password,
            installationUuid: installationUuid,
            caughtFish: caughtFish,
            tourType: tourType
        )
        let raw = try await executeStringRequest(req)
        return FishingOnlineResponseParser.parseFishCatchUploadResponse(raw)
    }

    public func fetchTopPlayers(
        login: String,
        languageCode: String = "ru"
    ) async throws -> [TopPlayerRatingEntry] {
        let req = FishingHttpRequestBuilder.makeTopPlayersRequest(login: login, languageCode: languageCode)
        let raw = try await executeStringRequest(req)
        return FishingOnlineResponseParser.parseTopPlayersResponse(raw)
    }

    public func fetchWorldSpeciesRecords(
        languageCode: String = "ru"
    ) async throws -> [WorldSpeciesRecordEntry] {
        let req = FishingHttpRequestBuilder.makeWorldRecordsRequest(languageCode: languageCode)
        let raw = try await executeStringRequest(req)
        return FishingOnlineResponseParser.parseWorldSpeciesRecordsResponse(raw)
    }

    public func fetchTournamentTimetable(
        languageCode: String = "ru"
    ) async throws -> [String] {
        let req = FishingHttpRequestBuilder.makeTournamentTimetableRequest(languageCode: languageCode)
        let raw = try await executeStringRequest(req)
        return raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - 7. Live TCP Chat Session (`chat.fish-mob.ru:15701`, `Client` & `Handler`, `NETWORK.md` Section 5)

@MainActor
public final class FishingLiveTCPChatSession {
    public enum ConnectionState: String, Sendable, Equatable {
        case disconnected = "Отключён"
        case connecting = "Подключение..."
        case connected = "В сети (15701)"
        case failed = "Ошибка сети"
    }

    public private(set) var state: ConnectionState = .disconnected
    public var onPacketReceived: ((Data) -> Void)?

    #if canImport(Network)
    private var connection: NWConnection?
    #endif

    public init() {}

    public func connect(
        host: String = FishingIOSAppConfiguration.chatServerHost,
        port: UInt16 = FishingIOSAppConfiguration.chatServerPort,
        userId: Int32,
        login: String,
        pondIndex: Int32,
        installationUuid: String
    ) {
        disconnect()
        state = .connecting

        #if canImport(Network)
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            state = .failed
            return
        }
        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .connected
                    self.sendInitialHandshake(
                        userId: userId,
                        login: login,
                        pondIndex: pondIndex,
                        installationUuid: installationUuid
                    )
                    self.receiveNextChunk()
                case .failed, .cancelled:
                    self.state = .failed
                default:
                    break
                }
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
        #else
        state = .failed
        #endif
    }

    public func disconnect() {
        #if canImport(Network)
        connection?.cancel()
        connection = nil
        #endif
        state = .disconnected
    }

    public func sendMess(_ mess: ChatMess) {
        let packet = JavaObjectStreamCodec.encodeMess(mess)
        #if canImport(Network)
        connection?.send(content: packet, completion: .contentProcessed { _ in })
        #endif
    }

    private func sendInitialHandshake(
        userId: Int32,
        login: String,
        pondIndex: Int32,
        installationUuid: String
    ) {
        let openMess = ChatProtocolSelector.makeOpenHandshakeMess(
            userId: userId,
            login: login,
            pondRoom: pondIndex,
            installationUuid: installationUuid
        )
        sendMess(openMess)

        let initMess = ChatProtocolSelector.makeSystemMess(
            command: "initialize",
            userId: userId,
            login: login,
            pondRoom: pondIndex
        )
        sendMess(initMess)

        let usersMess = ChatProtocolSelector.makeSystemMess(
            command: "getUserList3",
            userId: userId,
            login: login,
            pondRoom: pondIndex
        )
        sendMess(usersMess)

        let toursMess = ChatProtocolSelector.makeSystemMess(
            command: "tours",
            userId: userId,
            login: login,
            pondRoom: pondIndex
        )
        sendMess(toursMess)
    }

    #if canImport(Network)
    private func receiveNextChunk() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.onPacketReceived?(data)
                }
                if isComplete || error != nil {
                    self.state = .disconnected
                } else {
                    self.receiveNextChunk()
                }
            }
        }
    }
    #endif
}
