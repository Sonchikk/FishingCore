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
        req.setValue("close", forHTTPHeaderField: "Connection")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("text/plain", forHTTPHeaderField: "Accept")
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

    /// Builds `GET http://fish-mob.ru/fff/fish.php` (`FishingService$d.a`, `pc=0043..0265` in `classes.dex`).
    public static func makeSubmitFishCatchRequest(
        login: String,
        password: String,
        installationUuid: String,
        caughtFish: CaughtUserFish,
        tourType: Int = 0,
        playerCategory: Int = 0,
        playerExperience: Int = 0,
        playerBalance: Int = 0,
        antiCheatCatchDeltaMs: Int64 = -1000,
        antiCheatBiteDelaySeconds: Int64 = 20,
        inventoryFolpHeader: String? = nil
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.submitFishCatch.rawValue)!)
        req.httpMethod = "GET"
        req.setValue("close", forHTTPHeaderField: "Connection")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("text/plain", forHTTPHeaderField: "Accept")
        req.setValue(
            FishingNetworkCrypto.makeFishCatchFoplHeader(
                login: login,
                password: password,
                installationUuid: installationUuid,
                caughtFish: caughtFish,
                playerCategory: playerCategory,
                playerExperience: playerExperience,
                playerBalance: playerBalance,
                antiCheatCatchDeltaMs: antiCheatCatchDeltaMs,
                antiCheatBiteDelaySeconds: antiCheatBiteDelaySeconds
            ),
            forHTTPHeaderField: "X-Fish-Fopl"
        )
        req.setValue(FishingNetworkCrypto.installationUuidMd5(installationUuid), forHTTPHeaderField: "X-Fish-Uuid")
        req.setValue(FishingNetworkCrypto.formatJavaDateToString(epochMs: caughtFish.catchTimeMs), forHTTPHeaderField: "X-Fish-Date")
        let folpValue = inventoryFolpHeader ?? FishingNetworkCrypto.makeFishCatchFolpHeader(
            pondId0Based: caughtFish.pondIndex,
            baitId0Based: caughtFish.baitIndex,
            fishId0Based: max(0, caughtFish.fish.id - 1),
            weightGrams: caughtFish.weightGrams,
            tourType: tourType
        )
        req.setValue(folpValue, forHTTPHeaderField: "X-Fish-Folp")
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

    /// Builds `GET http://fish-mob.ru/fff/index.php` (`OnlineGameActivity$e.a`, `NETWORK.md` Section 2 #14).
    /// `listType`: `"2"` = active tournaments, `"3"` = completed tournaments, `"7"` = server news.
    public static func makeTournamentIndexRequest(
        login: String,
        listType: String = "2",
        languageCode: String = "ru",
        utcOffsetSeconds: Int = TimeZone.current.secondsFromGMT(),
        regFlag: String = "1"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.tournamentIndex.rawValue)!)
        req.httpMethod = "GET"
        req.setValue("close", forHTTPHeaderField: "Connection")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("text/plain", forHTTPHeaderField: "Accept")
        req.setValue(FishingNetworkCrypto.versionMeeks4_15, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        req.setValue(listType, forHTTPHeaderField: "X-Fish-Type")
        req.setValue(String(utcOffsetSeconds), forHTTPHeaderField: "X-Fish-OffsetUTC")
        req.setValue(regFlag, forHTTPHeaderField: "X-Fish-Reg")
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

    /// Builds `GET http://fish-mob.ru/fff/achievs.php` (`F0.o$a.a`, `NETWORK.md` Section 2 #4 & Section 3.2):
    /// Synchronizes all 14 achievements (`X-Fish-Fach`) and optionally all 44 quests (`X-Fish-Fqst`, when `fqstHeader != nil`) with `fish-mob.ru`.
    public static func makeSyncAchievementsAndQuestsRequest(
        login: String,
        password: String,
        installationUuid: String,
        fachHeader: String,
        fqstHeader: String? = nil,
        languageCode: String = "ru"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.syncAchievementsAndQuests.rawValue)!)
        req.httpMethod = "GET"
        req.setValue("close", forHTTPHeaderField: "Connection")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("text/plain", forHTTPHeaderField: "Accept")
        req.setValue(
            FishingNetworkCrypto.makeAuthOrAchievsFoplHeader(
                login: login,
                password: password,
                installationUuid: installationUuid
            ),
            forHTTPHeaderField: "X-Fish-Fopl"
        )
        req.setValue(FishingNetworkCrypto.installationUuidMd5(installationUuid), forHTTPHeaderField: "X-Fish-Uuid")
        req.setValue(fachHeader, forHTTPHeaderField: "X-Fish-Fach")
        req.setValue(fqstHeader ?? "", forHTTPHeaderField: "X-Fish-Fqst")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-Lng")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/tour_regin.php` (`TextActivity$f.a`, `NETWORK.md` Section 2 #11):
    /// Registers for (`actionType = "1"`) or unregisters from (`actionType = "0"`) an online tournament by `tournamentId`.
    public static func makeTournamentRegistrationRequest(
        login: String,
        password: String,
        installationUuid: String,
        tournamentId: String,
        actionType: String = "1",
        languageCode: String = "ru"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.tournamentRegistration.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4Y2Q, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        req.setValue(FishingNetworkCrypto.doubleMd5Password(password), forHTTPHeaderField: "X-Fish-Pass")
        req.setValue(FishingNetworkCrypto.installationUuidMd5(installationUuid), forHTTPHeaderField: "X-Fish-Imei")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        req.setValue(actionType, forHTTPHeaderField: "X-Fish-Type")
        req.setValue(tournamentId, forHTTPHeaderField: "X-Fish-Id")
        return req
    }

    /// Builds `GET http://fish-mob.ru/fff/tour_results.php` (`x0.p$b.a`, `NETWORK.md` Section 2 #12):
    /// Fetches live or final leaderboard standings for `tournamentId`.
    public static func makeTournamentResultsRequest(
        login: String,
        password: String,
        tournamentId: String,
        regFlag: String = "1",
        listType: String = "2",
        languageCode: String = "ru"
    ) -> URLRequest {
        var req = URLRequest(url: URL(string: FishingHttpEndpoint.tournamentResults.rawValue)!)
        req.httpMethod = "GET"
        req.setValue(FishingNetworkCrypto.versionMeeks4_15, forHTTPHeaderField: "X-Fish-Version")
        req.setValue(login, forHTTPHeaderField: "X-Fish-Login")
        req.setValue(regFlag, forHTTPHeaderField: "X-Fish-Reg")
        req.setValue(FishingNetworkCrypto.doubleMd5Password(password), forHTTPHeaderField: "X-Fish-Pass")
        req.setValue(languageCode, forHTTPHeaderField: "X-Fish-SetLng")
        req.setValue(listType, forHTTPHeaderField: "X-Fish-Type")
        req.setValue(tournamentId, forHTTPHeaderField: "X-Fish-Id")
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
    case newWorldRecord                 // status=1100 or 1300
    case rejected(statusCode: Int)
}

public struct TournamentResultsSnapshot: Sendable, Equatable {
    public let tournamentId: String
    public let participantsCount: Int
    public let secondsLeft: Int
    public let secondsToStart: Int
    public let isRegistered: Bool
    public let leaderboardLines: [String]

    public init(
        tournamentId: String,
        participantsCount: Int = 0,
        secondsLeft: Int = 0,
        secondsToStart: Int = 0,
        isRegistered: Bool = false,
        leaderboardLines: [String] = []
    ) {
        self.tournamentId = tournamentId
        self.participantsCount = participantsCount
        self.secondsLeft = secondsLeft
        self.secondsToStart = secondsToStart
        self.isRegistered = isRegistered
        self.leaderboardLines = leaderboardLines
    }
}

public enum AchievementsQuestsSyncResult: Sendable, Equatable {
    case synchronized(serverMessage: String)
    case rejected(statusCode: String, message: String)
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

/// Tournament entry parsed from `http://fish-mob.ru/fff/index.php` (`Lx0/p.onActivityCreated`, `LINK=2` / `LINK=3`).
public struct OnlineTournamentEntry: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let details: String
    public let dateInfo: String
    public let registrationState: String
    public let isCompleted: Bool

    public init(
        id: String,
        title: String,
        details: String,
        dateInfo: String = "",
        registrationState: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dateInfo = dateInfo
        self.registrationState = registrationState
        self.isCompleted = isCompleted
    }
}

public enum FishingOnlineResponseParser: Sendable {

    /// Parses `auth_chat.php` response (`SplashScreenActivity$d.a`, `NETWORK.md` Section 2 #2):
    /// `"1:<userId>"` on success, `"0"` or `"2"`..`"9"` (with or without `":..."`) on rejection.
    public static func parseChatAuthResponse(_ raw: String) -> ChatAuthHandshakeResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard let first = parts.first,
              let code = Int(first.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return .rejected(statusCode: -1, message: trimmed)
        }
        if code == 1, parts.count == 2,
           let uid = Int32(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
            return .authenticated(userId: uid)
        }
        let message: String
        if parts.count >= 2 {
            message = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            switch code {
            case 0: message = "Доступ к чату временно закрыт (код 0)."
            case 2: message = "Устаревшая версия клиента чата (код 2)."
            case 3: message = "Аккаунт заблокирован в чате (код 3)."
            case 4: message = "Слишком частые подключения к чату (код 4)."
            case 5: message = "Требуется повторная авторизация профиля (код 5)."
            default: message = "Код ответа сервера чата: \(code)"
            }
        }
        return .rejected(statusCode: code, message: message)
    }

    /// Parses `fish.php` response (`FishingService$d.a`, `NETWORK.md` Section 2 #3):
    /// `"status=1000"` -> `.accepted`, `"status=1100"` -> `.newWorldRecord`.
    public static func parseFishCatchUploadResponse(_ raw: String) -> FishCatchUploadResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directCode = Int(trimmed) {
            switch directCode {
            case 1000: return .accepted
            case 1100, 1300: return .newWorldRecord
            default: return .rejected(statusCode: directCode)
            }
        }
        for token in trimmed.components(separatedBy: CharacterSet(charactersIn: ",;&\n\r")) {
            let kv = token.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if kv.count == 2, kv[0] == "status", let code = Int(kv[1]) {
                switch code {
                case 1000: return .accepted
                case 1100, 1300: return .newWorldRecord
                default: return .rejected(statusCode: code)
                }
            }
        }
        return .rejected(statusCode: -1)
    }

    /// Parses `achievs.php` response (`F0.o$a.a`, `pc=01c3..029b` in `classes.dex`):
    /// `"1000"` or `"status=1000,message=..."` -> `.synchronized`, `"2000".."9000"` / `"error"` -> `.rejected`.
    public static func parseAchievementsQuestsSyncResponse(_ raw: String) -> AchievementsQuestsSyncResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .rejected(statusCode: "empty", message: "Пустой ответ от сервера синхронизации")
        }
        if trimmed == "1000" || trimmed == "1100" {
            return .synchronized(serverMessage: "Прогресс достижений и квестов синхронизирован (код \(trimmed)).")
        }
        if trimmed.contains("status") {
            var codeStr = "1000"
            var msgStr = ""
            for token in trimmed.components(separatedBy: CharacterSet(charactersIn: ",;&\n\r")) {
                let piece = token.trimmingCharacters(in: .whitespacesAndNewlines)
                if piece.hasPrefix("status=") {
                    codeStr = String(piece.dropFirst("status=".count))
                } else if piece.hasPrefix("message=") {
                    msgStr = String(piece.dropFirst("message=".count))
                }
            }
            if codeStr == "1000" || codeStr == "1100" {
                let text = msgStr.isEmpty ? "Прогресс синхронизирован с сервером (код \(codeStr))." : msgStr
                return .synchronized(serverMessage: text)
            }
            return .rejected(statusCode: codeStr, message: msgStr.isEmpty ? "Код ответа сервера: \(codeStr)" : msgStr)
        }
        switch trimmed {
        case "2000":
            return .rejected(statusCode: "2000", message: "Неверный логин или пароль (код 2000).")
        case "3000":
            return .rejected(statusCode: "3000", message: "Аккаунт заблокирован (код 3000).")
        case "4000":
            return .rejected(statusCode: "4000", message: "Несовпадение UUID устройства (код 4000).")
        case "5000":
            return .rejected(statusCode: "5000", message: "Устаревшая версия протокола (код 5000).")
        case "6000", "7000", "9000", "error":
            return .rejected(statusCode: trimmed, message: "Сервер отклонил синхронизацию (код \(trimmed)).")
        default:
            return .synchronized(serverMessage: trimmed)
        }
    }

    /// Parses `top.php` top players lines (`Lx0/p.onActivityCreated`, `LINK=4` in `classes.dex`):
    /// Supports both the real `fish-mob.ru` format (`"1. Login - 12450000"`, with optional header line 0)
    /// and colon-delimited lines (`"rank:login:exp:category"` or `"login:exp:category"`).
    public static func parseTopPlayersResponse(_ raw: String) -> [TopPlayerRatingEntry] {
        var result: [TopPlayerRatingEntry] = []
        for (idx, line) in raw.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 1. Check real `fish-mob.ru` `top.php` format from `Lx0/p` (`LINK=4`): `"1. Login - 12450000"`
            if trimmed.contains(" - ") {
                let dotSplit = trimmed.components(separatedBy: ". ")
                let rankFromPrefix = dotSplit.count >= 2 ? Int(dotSplit[0].trimmingCharacters(in: .whitespaces)) : nil
                let remainder = dotSplit.count >= 2 ? dotSplit.dropFirst().joined(separator: ". ") : trimmed
                let dashCols = remainder.components(separatedBy: " - ").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if dashCols.count >= 2 {
                    let digitsOnly = dashCols[1].filter { $0.isNumber }
                    if let exp = Int(digitsOnly) {
                        let rank = rankFromPrefix ?? (result.count + 1)
                        let cat: Int
                        if dashCols.count >= 3, let explicitCat = Int(dashCols[2].filter({ $0.isNumber })) {
                            cat = explicitCat
                        } else {
                            cat = ProgressionCalculator.categoryForExperience(
                                exp,
                                balanceTables: BalanceTables()
                            )
                        }
                        result.append(
                            TopPlayerRatingEntry(
                                rankPosition: rank,
                                login: dashCols[0],
                                experience: exp,
                                categoryRank: cat
                            )
                        )
                        continue
                    }
                }
            }

            // 2. Fallback colon-delimited format (`rank:login:exp:category` or `login:exp:category`)
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

    /// Parses `rek.php` world species records (`Lx0/p.onActivityCreated`, `LINK=6` in `classes.dex`):
    /// Supports both the real `fish-mob.ru` format (`"1. HolderLogin - FishName - 2950 г."`)
    /// and colon-delimited lines (`"fishName:weightGrams:holderLogin"`).
    public static func parseWorldSpeciesRecordsResponse(_ raw: String) -> [WorldSpeciesRecordEntry] {
        var result: [WorldSpeciesRecordEntry] = []
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 1. Check real `fish-mob.ru` `rek.php` format from `Lx0/p` (`LINK=6`): `"1. HolderLogin - FishName - 2950"`
            if trimmed.contains(" - ") {
                let dotSplit = trimmed.components(separatedBy: ". ")
                let remainder = dotSplit.count >= 2 ? dotSplit.dropFirst().joined(separator: ". ") : trimmed
                let dashCols = remainder.components(separatedBy: " - ").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if dashCols.count >= 3 {
                    let weightDigits = dashCols[2].filter { $0.isNumber }
                    if let weight = Int(weightDigits) {
                        result.append(
                            WorldSpeciesRecordEntry(
                                fishName: dashCols[1],
                                weightGrams: weight,
                                holderLogin: dashCols[0]
                            )
                        )
                        continue
                    }
                }
            }

            // 2. Fallback colon-delimited format (`fishName:weightGrams:holderLogin`)
            let cols = trimmed.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cols.count >= 3, let weight = Int(cols[1]) else { continue }
            result.append(WorldSpeciesRecordEntry(fishName: cols[0], weightGrams: weight, holderLogin: cols[2]))
        }
        return result
    }

    /// Parses `http://fish-mob.ru/fff/index.php` tournament list (`Lx0/p.onActivityCreated`, `LINK=2` active / `LINK=3` finished):
    /// Entries are separated by `"#"` and fields inside each entry are separated by `"--"`.
    public static func parseTournamentIndexResponse(_ raw: String, isCompleted: Bool = false) -> [OnlineTournamentEntry] {
        let cleaned = FishingNetworkCrypto.truncateTournamentHeaderString(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != "not", cleaned != "0" else { return [] }

        var entries: [OnlineTournamentEntry] = []
        let blocks = cleaned.components(separatedBy: "#")
        for (idx, block) in blocks.enumerated() {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let fields = trimmed.components(separatedBy: "--").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if fields.count >= 6 {
                // `LINK=2` active tournament: `fields[0]=title`, `fields[1]=condition`, `fields[2]=pond`, `fields[3]=date`, `fields[4]=reg`, `fields[5]=id`
                let tourId = fields[5].isEmpty ? "active_\(idx + 1)" : fields[5]
                let detailsText = [fields[1], fields[2]].filter { !$0.isEmpty }.joined(separator: " • ")
                entries.append(
                    OnlineTournamentEntry(
                        id: tourId,
                        title: fields[0].isEmpty ? "Турнир #\(tourId)" : fields[0],
                        details: detailsText,
                        dateInfo: fields[3],
                        registrationState: fields[4],
                        isCompleted: false
                    )
                )
            } else if fields.count >= 2 {
                // `LINK=3` completed tournament: `fields[0]=title/summary`, `fields[1]=date`, `fields[2]=id`
                let tourId = (fields.count >= 3 && !fields[2].isEmpty) ? fields[2] : "done_\(idx + 1)"
                entries.append(
                    OnlineTournamentEntry(
                        id: tourId,
                        title: fields[0],
                        details: fields.count >= 3 ? "Завершённый турнир #\(tourId)" : "Завершённый турнир",
                        dateInfo: fields[1],
                        registrationState: "",
                        isCompleted: true
                    )
                )
            } else if trimmed.contains(" - ") {
                entries.append(
                    OnlineTournamentEntry(
                        id: "tour_\(idx + 1)",
                        title: trimmed,
                        details: isCompleted ? "Завершённый турнир" : "Онлайн-турнир",
                        isCompleted: isCompleted
                    )
                )
            }
        }
        return entries
    }

    /// Parses `tour_results.php` response (`x0.p$b.a`, `pc=00c6..016b` in `classes.dex`):
    /// Format: `"--regin=1,left=1200,start=0,users=14,tour=1045--1. PlayerA - 3450\n2. PlayerB - 2890"`.
    public static func parseTournamentResultsResponse(_ raw: String, tournamentId: String) -> TournamentResultsSnapshot {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TournamentResultsSnapshot(tournamentId: tournamentId)
        }
        let sections = trimmed.components(separatedBy: "--")
        var usersCount = 0
        var leftSec = 0
        var startSec = 0
        var regin = false
        var lines: [String] = []

        for sec in sections {
            let clean = sec.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            if clean.contains("users=") || clean.contains("left=") || clean.contains("regin=") {
                for kv in clean.components(separatedBy: ",") {
                    let p = kv.trimmingCharacters(in: .whitespacesAndNewlines)
                    if p.hasPrefix("users=") {
                        usersCount = Int(p.replacingOccurrences(of: "users=", with: "")) ?? 0
                    } else if p.hasPrefix("left=") {
                        leftSec = Int(p.replacingOccurrences(of: "left=", with: "")) ?? 0
                    } else if p.hasPrefix("start=") {
                        startSec = Int(p.replacingOccurrences(of: "start=", with: "")) ?? 0
                    } else if p.hasPrefix("regin=") {
                        regin = (Int(p.replacingOccurrences(of: "regin=", with: "")) ?? 0) > 0
                    }
                }
            } else {
                let subLines = clean.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                lines.append(contentsOf: subLines)
            }
        }
        return TournamentResultsSnapshot(
            tournamentId: tournamentId,
            participantsCount: usersCount,
            secondsLeft: leftSec,
            secondsToStart: startSec,
            isRegistered: regin,
            leaderboardLines: lines
        )
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

        var resolvedHour = initialHour
        var resolvedMinute = initialMinute
        if FileManager.default.fileExists(atPath: dbPath),
           let existingConn = try? SQLiteConnection(path: dbPath),
           let rows = try? existingConn.query(
               "SELECT counter_key, counter_value FROM player_runtime_counters WHERE counter_key IN ('pref_clock_hour', 'pref_clock_minute');"
           ) {
            for row in rows {
                let key = row.string("counter_key")
                let val = row.int("counter_value")
                if key == "pref_clock_hour", (0..<24).contains(val) {
                    resolvedHour = val
                } else if key == "pref_clock_minute", (0..<60).contains(val) {
                    resolvedMinute = val
                }
            }
        }

        return try FishingAppCoordinator(
            databasePath: dbPath,
            jsonDataDirectoryURL: jsonDirForInit,
            installationUuid: installationUuid,
            initialHour: resolvedHour,
            initialMinute: resolvedMinute,
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
            title: "Рыбалка для Друзей",
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
    case appTransportSecurityBlocked
    case transportError(description: String)

    public var errorDescription: String? {
        switch self {
        case .invalidServerResponse(let code):
            return "Сервер вернул код HTTP \(code)."
        case .emptyPayload:
            return "Пустой ответ от сервера fish-mob.ru."
        case .serverStatusRejected(let code):
            switch code {
            case "2000":
                return "Неверный логин или пароль на fish-mob.ru (код 2000)."
            case "3000":
                return "Аккаунт заблокирован или не активирован (код 3000)."
            case "4000":
                return "Профиль привязан к другому устройству UUID (код 4000)."
            case "5000":
                return "Сервер отклонил версию протокола (код 5000)."
            default:
                return "Сервер отклонил запрос (код: \(code))."
            }
        case .appTransportSecurityBlocked:
            return "iOS App Transport Security заблокировал HTTP-соединение с fish-mob.ru. Перегенерируйте проект через xcodegen из обновлённого project.yml (или включите Allow Arbitrary Loads в Info.plist таргета)."
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
            let nsErr = error as NSError
            if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorAppTransportSecurityRequiresSecureConnection {
                throw FishingLiveNetworkError.appTransportSecurityBlocked
            }
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
        tourType: Int,
        playerCategory: Int = 0,
        playerExperience: Int = 0,
        playerBalance: Int = 0,
        antiCheatCatchDeltaMs: Int64 = -1000,
        antiCheatBiteDelaySeconds: Int64 = 20,
        inventoryFolpHeader: String? = nil
    ) async throws -> FishCatchUploadResult {
        let req = FishingHttpRequestBuilder.makeSubmitFishCatchRequest(
            login: login,
            password: password,
            installationUuid: installationUuid,
            caughtFish: caughtFish,
            tourType: tourType,
            playerCategory: playerCategory,
            playerExperience: playerExperience,
            playerBalance: playerBalance,
            antiCheatCatchDeltaMs: antiCheatCatchDeltaMs,
            antiCheatBiteDelaySeconds: antiCheatBiteDelaySeconds,
            inventoryFolpHeader: inventoryFolpHeader
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

    public func registerOrRecoverAccount(
        loginOrEmail: String,
        plainPassword: String,
        languageCode: String = "ru",
        categoryRank: Int = 0
    ) async throws -> String {
        let req = FishingHttpRequestBuilder.makeAccountRegistrationOrRecoveryRequest(
            loginOrEmail: loginOrEmail,
            plainPassword: plainPassword,
            languageCode: languageCode,
            categoryRank: categoryRank
        )
        return try await executeStringRequest(req)
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

    public func fetchOnlineTournaments(
        login: String,
        listType: String = "2",
        languageCode: String = "ru"
    ) async throws -> [OnlineTournamentEntry] {
        let req = FishingHttpRequestBuilder.makeTournamentIndexRequest(
            login: login,
            listType: listType,
            languageCode: languageCode
        )
        let raw = try await executeStringRequest(req)
        return FishingOnlineResponseParser.parseTournamentIndexResponse(
            raw,
            isCompleted: listType == "3"
        )
    }

    public func syncAchievementsAndQuests(
        login: String,
        password: String,
        installationUuid: String,
        fachHeader: String,
        fqstHeader: String? = nil,
        languageCode: String = "ru"
    ) async throws -> AchievementsQuestsSyncResult {
        let req = FishingHttpRequestBuilder.makeSyncAchievementsAndQuestsRequest(
            login: login,
            password: password,
            installationUuid: installationUuid,
            fachHeader: fachHeader,
            fqstHeader: fqstHeader,
            languageCode: languageCode
        )
        let raw = try await executeStringRequest(req)
        return FishingOnlineResponseParser.parseAchievementsQuestsSyncResponse(raw)
    }

    public func registerInOnlineTournament(
        login: String,
        password: String,
        installationUuid: String,
        tournamentId: String,
        actionType: String = "1",
        languageCode: String = "ru"
    ) async throws -> String {
        let req = FishingHttpRequestBuilder.makeTournamentRegistrationRequest(
            login: login,
            password: password,
            installationUuid: installationUuid,
            tournamentId: tournamentId,
            actionType: actionType,
            languageCode: languageCode
        )
        return try await executeStringRequest(req)
    }

    public func fetchTournamentResults(
        login: String,
        password: String,
        tournamentId: String,
        regFlag: String = "1",
        listType: String = "2",
        languageCode: String = "ru"
    ) async throws -> TournamentResultsSnapshot {
        let req = FishingHttpRequestBuilder.makeTournamentResultsRequest(
            login: login,
            password: password,
            tournamentId: tournamentId,
            regFlag: regFlag,
            listType: listType,
            languageCode: languageCode
        )
        let raw = try await executeStringRequest(req)
        return FishingOnlineResponseParser.parseTournamentResultsResponse(raw, tournamentId: tournamentId)
    }
}

// MARK: - 7. Live TCP Chat Session (`chat.fish-mob.ru:15701`, `Client` & `Handler`, `NETWORK.md` Section 5)

@MainActor
public final class FishingLiveTCPChatSession {
    public enum ConnectionState: String, Sendable, Equatable {
        case disconnected = "Отключён"
        case connecting = "Подключение..."
        case connected = "В сети"
        case failed = "Ошибка сети"
    }

    public private(set) var state: ConnectionState = .disconnected
    public var onPacketReceived: ((Data) -> Void)?
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
    private var hasSentStreamHeader: Bool = false

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
        hasSentStreamHeader = false
        state = .connecting
        onConnectionStateChanged?(.connecting)

        #if canImport(Network)
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            state = .failed
            onConnectionStateChanged?(.failed)
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
                    self.onConnectionStateChanged?(.connected)
                    self.sendInitialHandshake(
                        userId: userId,
                        login: login,
                        pondIndex: pondIndex,
                        installationUuid: installationUuid
                    )
                    self.receiveNextChunk()
                case .failed, .cancelled:
                    self.state = .failed
                    self.onConnectionStateChanged?(.failed)
                default:
                    break
                }
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
        #else
        state = .failed
        onConnectionStateChanged?(.failed)
        #endif
    }

    public func disconnect() {
        #if canImport(Network)
        connection?.cancel()
        connection = nil
        #endif
        hasSentStreamHeader = false
        state = .disconnected
        onConnectionStateChanged?(.disconnected)
    }

    /// Sends a Mess over the persistent ObjectOutputStream on port 15701.
    /// Matches Java's ObjectOutputStream protocol: the 4-byte 0xACED0005 stream header is written
    /// ONLY ONCE when opening the stream; subsequent objects prepend TC_RESET (0x79) so the server's
    /// ObjectInputStream.readUnshared() resets its wire handle table without throwing StreamCorruptedException.
    public func sendMess(_ mess: ChatMess) {
        let includeHeader = !hasSentStreamHeader
        hasSentStreamHeader = true
        let packet = JavaObjectStreamCodec.encodeMess(
            mess,
            includeStreamHeader: includeHeader,
            prependResetWhenNoHeader: !includeHeader
        )
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
        // Match Client.open() (pc=003e..0056) & Data.initialize():
        // 1. Send "open" with Request(string: md5(installationUuid))
        let openMess = ChatProtocolSelector.makeOpenHandshakeMess(
            userId: userId,
            login: login,
            pondRoom: pondIndex,
            installationUuid: installationUuid
        )
        sendMess(openMess)

        // 2. Send "initialize" (Data.initialize())
        let initMess = ChatProtocolSelector.makeSystemMess(
            command: "initialize",
            userId: userId,
            login: login,
            pondRoom: pondIndex
        )
        sendMess(initMess)

        // 3. Request online users for the current pond room ("getUserList3")
        let usersMess = ChatProtocolSelector.makeSystemMess(
            command: "getUserList3",
            userId: userId,
            login: login,
            pondRoom: pondIndex
        )
        sendMess(usersMess)
    }

    #if canImport(Network)
    private func receiveNextChunk() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data, !data.isEmpty {
                    self.onPacketReceived?(data)
                }
                if isComplete || error != nil {
                    self.state = .disconnected
                    self.onConnectionStateChanged?(.disconnected)
                } else {
                    self.receiveNextChunk()
                }
            }
        }
    }
    #endif
}
