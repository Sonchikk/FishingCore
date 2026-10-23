import Foundation
import FishingCore
import FishingDatabase

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
        viewWidth: Int = 1280,
        viewHeight: Int = 800,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
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
            nowMs: nowMs
        )
    }
}