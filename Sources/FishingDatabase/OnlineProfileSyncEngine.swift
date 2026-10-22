import Foundation
import FishingCore

// MARK: - 1. Cryptographic Primitives, Headers & Permutation Cipher (`F0.e`, `F0.h`, `F0.i`, `F0.t`, `FishingService.z`)

/// Reconstructs all cryptographic primitives, version markers, and `X-Fish-*` header formulas
/// from `classes.dex` (`NETWORK.md` Sections 1–3).
public enum FishingNetworkCrypto: Sendable {
    /// Fixed APK signature hash `FishingService.z()` computed from `META-INF/CERT.RSA` (`SHA-1: aa920315...` + `"com.evados.fishing"`).
    public static let appSignConstant = "baa4d19bbde3a629d99fcd7e7d89beae"

    /// Protocol version token `"fishmob " + Base64("bd")` (`189 = 0xbd`) used in `C0.a$h`, `F0.o$a`, `MyTourActivity$h`.
    public static let versionFishmobYmQ = "fishmob YmQ="

    /// Protocol version token `"meeks4_fff " + Base64("cd")` (`205 = 0xcd`) used in `FishingService$d`, `MainActivity$d`, `OnlineShopActivity`.
    public static let versionMeeks4Y2Q = "meeks4_fff Y2Q="

    /// Static version header `"meeks4_fff 15"` used in `OnlineGameActivity$b/c/d/e` and `x0.p$b`.
    public static let versionMeeks4_15 = "meeks4_fff 15"

    /// IAP / Rewarded video pearl key (`BuyGoods$b`, `RewardedGoods$b`).
    public static let keyBuyBalls = "367sdy672fdg243dtr671dfu"

    /// Account registration / password recovery key (`RegisterActivity$g`).
    public static let keyRegister = "367sdy672fdg243dtr671dfuReg"

    /// Permutation table `pi_0` (`permVariant == 0`) in `F0.t.a`.
    public static let permutationPi0: [Int] = [1, 3, 7, 4, 0, 6, 9, 8, 2, 5]
    /// Inverse permutation `pi_0^-1` (`pi_0[pi_0_inv[k]] == k`).
    public static let inversePermutationPi0: [Int] = [4, 0, 8, 1, 3, 9, 5, 2, 7, 6]

    /// Permutation table `pi_1` (`permVariant != 0`) in `F0.t.a`.
    public static let permutationPi1: [Int] = [1, 5, 7, 4, 0, 6, 9, 8, 2, 3]
    /// Inverse permutation `pi_1^-1` (`pi_1[pi_1_inv[k]] == k`).
    public static let inversePermutationPi1: [Int] = [4, 0, 8, 9, 3, 1, 5, 2, 7, 6]

    /// Computes the lowercase 32-char hex MD5 of the installation UUID (`F0.e.a(context)` -> `DatabaseHelper.md5`).
    public static func installationUuidMd5(_ installationUuid: String) -> String {
        FishingChecksum.md5(installationUuid)
    }

    /// Computes the double-MD5 password hash (`F0.h` / `F0.i`, `NETWORK.md` Section 1.2):
    /// `passHash = MD5_hex(ASCII(MD5_hex(password)))`.
    public static func doubleMd5Password(_ password: String) -> String {
        let firstHex = FishingChecksum.md5(password)
        return FishingChecksum.md5(firstHex)
    }

    /// Reconstructs `F0.t.a(input, "encode", simpleBase64, permVariant)` (`NETWORK.md` Section 1.4).
    public static func encodeF0t(
        _ input: String,
        simpleBase64: Bool = false,
        permVariant: Int = 0
    ) -> String {
        let b64 = Data(input.utf8).base64EncodedString()
        if simpleBase64 {
            return b64
        }
        let chars = Array(b64)
        let rowCount = (chars.count + 9) / 10
        guard rowCount > 0 else { return "" }

        let pi = (permVariant == 0) ? permutationPi0 : permutationPi1
        var matrix = [[Character]](repeating: [Character](repeating: "-", count: 10), count: rowCount)
        for (idx, ch) in chars.enumerated() {
            matrix[idx / 10][idx % 10] = ch
        }

        var out = String()
        out.reserveCapacity(rowCount * 10)
        for r in 0..<rowCount {
            for c in 0..<10 {
                out.append(matrix[r][pi[c]])
            }
        }
        return out
    }

    /// Reconstructs `F0.t.a(input, "decode", simpleBase64, permVariant)` (`NETWORK.md` Section 1.4).
    public static func decodeF0t(
        _ encoded: String,
        simpleBase64: Bool = false,
        permVariant: Int = 0
    ) -> String? {
        if simpleBase64 {
            guard let data = Data(base64Encoded: encoded) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        let chars = Array(encoded)
        guard chars.count % 10 == 0 else { return nil }
        let rowCount = chars.count / 10
        let piInv = (permVariant == 0) ? inversePermutationPi0 : inversePermutationPi1

        var restoredBase64 = String()
        restoredBase64.reserveCapacity(chars.count)
        for r in 0..<rowCount {
            let rowOffset = r * 10
            for k in 0..<10 {
                let ch = chars[rowOffset + piInv[k]]
                if ch != "-" {
                    restoredBase64.append(ch)
                }
            }
        }
        guard let data = Data(base64Encoded: restoredBase64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Composite `X-Fish-*` Header Builders (`NETWORK.md` Section 3)

    /// `X-Fish-Fopl` for `auth.php` (`C0.a$h.b`) and `achievs.php` (`F0.o$a.a`):
    /// `Base64(login + ":" + passHash + ":fishmob YmQ=:" + imeiOrUuidMd5 + ":" + appSign)`
    public static func makeAuthOrAchievsFoplHeader(
        login: String,
        password: String,
        installationUuid: String,
        appSign: String = appSignConstant
    ) -> String {
        let passHash = doubleMd5Password(password)
        let uuidMd5 = installationUuidMd5(installationUuid)
        let plain = "\(login):\(passHash):\(versionFishmobYmQ):\(uuidMd5):\(appSign)"
        return Data(plain.utf8).base64EncodedString()
    }

    /// `X-Fish-Fopl` for `fish.php` (`FishingService$d.a`):
    /// `Base64(login + ":" + passHash + ":meeks4_fff Y2Q=:" + imeiOrUuidMd5 + ":" + appSign)`
    public static func makeFishCatchFoplHeader(
        login: String,
        password: String,
        installationUuid: String,
        appSign: String = appSignConstant
    ) -> String {
        let passHash = doubleMd5Password(password)
        let uuidMd5 = installationUuidMd5(installationUuid)
        let plain = "\(login):\(passHash):\(versionMeeks4Y2Q):\(uuidMd5):\(appSign)"
        return Data(plain.utf8).base64EncodedString()
    }

    /// `X-Fish-Folp` for `fish.php` (`FishingService$d.a`):
    /// `F0.t.a(pondId0Based + ":" + baitId0Based + ":" + fishId0Based + ":" + weightGrams + ":" + tourType, "encode", false, 0)`
    public static func makeFishCatchFolpHeader(
        pondId0Based: Int,
        baitId0Based: Int,
        fishId0Based: Int,
        weightGrams: Int,
        tourType: Int = 0
    ) -> String {
        let plain = "\(pondId0Based):\(baitId0Based):\(fishId0Based):\(weightGrams):\(tourType)"
        return encodeF0t(plain, simpleBase64: false, permVariant: 0)
    }

    /// `X-Fish-Fopl` for `http://chat.fish-mob.ru/auth_chat.php` (`SplashScreenActivity$d.a`):
    /// `F0.t.a(login + ":ZWY=:" + imeiOrZero + ":" + appSign + ":" + uuidMd5, "encode", false, 0)`
    public static func makeChatAuthFoplHeader(
        login: String,
        installationUuid: String,
        imeiOrZero: String = "0",
        appSign: String = appSignConstant
    ) -> String {
        let uuidMd5 = installationUuidMd5(installationUuid)
        let plain = "\(login):ZWY=:\(imeiOrZero):\(appSign):\(uuidMd5)"
        return encodeF0t(plain, simpleBase64: false, permVariant: 0)
    }

    /// Replicates the tournament header string truncation quirk in `x0.p.A(String)` (`NETWORK.md` Section 7.1 #4):
    /// If the string ends with `\n` (`charAt(len - 1) == 10`), truncates the last 3 characters (`substring(0, len - 3)`).
    public static func truncateTournamentHeaderString(_ raw: String) -> String {
        guard raw.hasSuffix("\n"), raw.count >= 3 else { return raw }
        return String(raw.dropLast(3))
    }
}

// MARK: - 2. All 17 HTTP Endpoints (`NETWORK.md` Section 2)

public enum FishingHttpEndpoint: String, CaseIterable, Sendable {
    case authProfile = "http://fish-mob.ru/fff/auth.php"
    case authChat = "http://chat.fish-mob.ru/auth_chat.php"
    case submitFishCatch = "http://fish-mob.ru/fff/fish.php"
    case syncAchievementsAndQuests = "http://fish-mob.ru/fff/achievs.php"
    case onlineShopCatalog = "http://fish-mob.ru/fff/online.php"
    case onlineShopPurchaseOrMessages = "http://fish-mob.ru/fff/repaint.php"
    case claimRewards = "http://fish-mob.ru/fff/reaward.php"
    case buyPearls = "http://fish-mob.ru/fff/buyballs.php"
    case registerAccount = "http://fish-mob.ru/registration_app.php"
    case individualTournaments = "http://fish-mob.ru/fff/tour_app.php"
    case tournamentRegistration = "http://fish-mob.ru/fff/tour_regin.php"
    case tournamentResults = "http://fish-mob.ru/fff/tour_results.php"
    case tournamentTimetable = "http://fish-mob.ru/fff/timetable/tt.php"
    case tournamentIndex = "http://fish-mob.ru/fff/index.php"
    case topPlayersRating = "http://fish-mob.ru/fff/top.php"
    case worldSpeciesRecords = "http://fish-mob.ru/fff/rek.php"
    case assetPacksManifest = "http://fish-mob.ru/fff/update.php"
}

// MARK: - 3. Auth Brute-Force Cooldown Tracker (`C0.a$d` & `C0.a$h`, `NETWORK.md` Section 4.1)

/// Reconstructs the 180-second brute-force protection from `C0.a$d.onClick()` (`pc=0012..0087`)
/// and `C0.a$h.b()` (`pc=02f9..0321`).
public struct AuthAttemptLimiter: Sendable, Equatable {
    public static let cooldownWindowSeconds: Int64 = 180
    public static let maxAllowedAttemptsBeforeLock: Int = 3

    public private(set) var lastAttemptTimeSeconds: Int64 = 0
    public private(set) var consecutiveAttempts: Int = 0

    public init(lastAttemptTimeSeconds: Int64 = 0, consecutiveAttempts: Int = 0) {
        self.lastAttemptTimeSeconds = lastAttemptTimeSeconds
        self.consecutiveAttempts = consecutiveAttempts
    }

    /// Checks whether a login request is allowed at `nowSeconds`.
    /// In `C0.a`, `authNums` increments on each attempt; if `nowSeconds - authTime <= 180` and `authNums > 2`
    /// (i.e. more than 3 attempts in a 180s window), returns the remaining cooldown in seconds.
    public mutating func registerAttempt(nowSeconds: Int64) -> Int64? {
        let elapsed = nowSeconds - lastAttemptTimeSeconds
        if lastAttemptTimeSeconds > 0 && elapsed <= Self.cooldownWindowSeconds {
            if consecutiveAttempts >= Self.maxAllowedAttemptsBeforeLock {
                return max(1, Self.cooldownWindowSeconds - elapsed)
            }
            consecutiveAttempts += 1
        } else {
            consecutiveAttempts = 1
        }
        lastAttemptTimeSeconds = nowSeconds
        return nil
    }

    public mutating func resetOnSuccess() {
        consecutiveAttempts = 0
        lastAttemptTimeSeconds = 0
    }
}

// MARK: - 4. Online Profile Restore (`C0.a.l`) & Online Shop CSV Sync (`MainActivity$d.c`)

public struct AuthRestoreSummary: Sendable, Equatable {
    public let experience: Int
    public let categoryRank: Int
    public let balanceCoins: Int
    public let restoredRodsCount: Int
    public let restoredCoilsCount: Int
    public let restoredLinesCount: Int
    public let restoredAchievementsCount: Int
    public let restoredQuestsCount: Int
}

public struct OnlineShopSnapshot: Sendable, Equatable {
    public let pearlsBalance: Int
    public let onlineRodWeightsKg: [Int]       // IDs 11, 12, 13
    public let onlineRodPearlPrices: [Int]
    public let onlineCoilBearings: [Int]       // IDs 8, 9, 10
    public let onlineCoilPearlPrices: [Int]
    public let onlineLineWeightsKg: [Int]      // IDs 14, 15, 16
    public let onlineLineStockLengthsM: [Int]  // IDs 14, 15, 16
    public let onlineLinePearlPrices: [Int]
    public let couponPearlPrices: [Int]        // 7 coupons
    public let unreadNotesCount: Int           // note=K
}

extension PlayerStateRepository {

    /// Builds the `X-Fish-Fach` header (`F0.o$a.b()`, `NETWORK.md` Section 3.2):
    /// `"1:score1:level1|2:score2:level2|...|14:score14:level14|"` after verifying `AchievementMd5` on all 14 rows.
    public func buildFachHeader() throws -> String {
        let rows = try listAchievements()
        guard rows.count == 14 else {
            throw PlayerPersistenceError.integrityCheckFailed("Expected 14 achievements for X-Fish-Fach, found \(rows.count)")
        }
        var parts = ""
        for ach in rows {
            let expectedMd5 = FishingChecksum.achievementMd5(
                id: ach.id,
                score: ach.score,
                level: ach.level,
                nag: ach.nag,
                nagsize: ach.nagSize,
                date: ach.date,
                installationUuid: installationUuid
            )
            guard ach.md5 == expectedMd5 else {
                throw PlayerPersistenceError.integrityCheckFailed("Achievement #\(ach.id) MD5 mismatch in buildFachHeader")
            }
            parts.append("\(ach.id):\(ach.score):\(ach.level)|")
        }
        return parts
    }

    /// Builds the `X-Fish-Fqst` header (`F0.o$a.c()`, `NETWORK.md` Section 3.2):
    /// `"made1|made2|...|madeN|"` ordered by `id ASC`.
    public func buildFqstHeader() throws -> String {
        let quests = try listQuests()
        var out = ""
        for q in quests {
            out.append("\(q.made)|")
        }
        return out
    }

    /// Parses a 7-section `auth.php` response (`C0.a.l(String, Context, DatabaseHelper)`, `NETWORK.md` Section 4.1)
    /// and restores the player's profile, rods (`C0.a.n`), coils (`C0.a.k`), lines (`C0.a.m`),
    /// achievements (`C0.a.j`), and quests (`C0.a.o`) inside a single atomic SQLite transaction.
    @discardableResult
    public func restoreProfileFromAuthResponse(
        _ response: String,
        login: String,
        password: String,
        nowMs: Int64
    ) throws -> AuthRestoreSummary {
        let sections = response.components(separatedBy: ";")
        guard sections.count >= 7,
              let exp = Int(sections[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let balance = Int(sections[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw PlayerPersistenceError.invalidInventoryItem("Malformed 7-section auth.php response")
        }

        let passHash = FishingNetworkCrypto.doubleMd5Password(password)
        let newRank = ProgressionCalculator.categoryForExperience(exp, balanceTables: balanceTables)

        return try connection.transaction {
            // 1 & 2: Restore `user_data` (`experience`, `category`, `balance`, `login`, `password`)
            let userDataMd5 = FishingChecksum.userDataMd5(
                balance: balance,
                experience: exp,
                category: newRank,
                date: nowMs,
                installationUuid: installationUuid
            )
            try connection.run("""
            UPDATE user_data SET
                login = ?,
                password = ?,
                balance = ?,
                experience = ?,
                category = ?,
                date = ?,
                md5 = ?
            WHERE id = 1;
            """, bindings: [
                .text(login),
                .text(passHash),
                .integer(Int64(balance)),
                .integer(Int64(exp)),
                .integer(Int64(newRank)),
                .integer(nowMs),
                .text(userDataMd5)
            ])

            // 3. Section[2] — Restore up to 5 rods (`C0.a.n()`: `name:weight:strength|...` or `not`)
            try connection.run("DELETE FROM user_fishing_rods;")
            var rodsRestored = 0
            let rodTokens = sections[2].split(separator: "|").map(String.init)
            for token in rodTokens {
                guard token != "not", token.contains(":") else { continue }
                let fields = token.split(separator: ":").map(String.init)
                guard fields.count >= 3,
                      let weightKg = Int(fields[1]),
                      let strength = Int(fields[2]) else { continue }
                let name = fields[0]

                let rodRows = try connection.query(
                    "SELECT id, price FROM fishing_rods WHERE name = ? LIMIT 1;",
                    bindings: [.text(name)]
                )
                guard let rodRow = rodRows.first else { continue }
                let baseRodId = rodRow.int("id")
                let basePrice = rodRow.int("price")
                if basePrice == 0 && weightKg > 0 {
                    try connection.run(
                        "UPDATE fishing_rods SET weight = ? WHERE id = ?;",
                        bindings: [.integer(Int64(weightKg)), .integer(Int64(baseRodId))]
                    )
                }

                rodsRestored += 1
                let rowId = rodsRestored
                let invMd5 = FishingChecksum.userInvMd5(
                    rowId: rowId,
                    baseItemId: baseRodId,
                    date: nowMs,
                    attributeValue: strength,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT INTO user_fishing_rods (id, fishing_rod_id, strength, date, md5)
                VALUES (?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(rowId)),
                    .integer(Int64(baseRodId)),
                    .integer(Int64(strength)),
                    .integer(nowMs),
                    .text(invMd5)
                ])
            }

            // 4. Section[3] — Restore up to 5 coils (`C0.a.k()`: `name:bearings:strength|...` or `not`)
            try connection.run("DELETE FROM user_coils;")
            var coilsRestored = 0
            let coilTokens = sections[3].split(separator: "|").map(String.init)
            for token in coilTokens {
                guard token != "not", token.contains(":") else { continue }
                let fields = token.split(separator: ":").map(String.init)
                guard fields.count >= 3,
                      let bearings = Int(fields[1]),
                      let strength = Int(fields[2]) else { continue }
                let name = fields[0]

                let coilRows = try connection.query(
                    "SELECT id, price FROM coils WHERE name = ? LIMIT 1;",
                    bindings: [.text(name)]
                )
                guard let coilRow = coilRows.first else { continue }
                let baseCoilId = coilRow.int("id")
                let basePrice = coilRow.int("price")
                if basePrice == 0 && bearings > 0 {
                    try connection.run(
                        "UPDATE coils SET bearing_count = ? WHERE id = ?;",
                        bindings: [.integer(Int64(bearings)), .integer(Int64(baseCoilId))]
                    )
                }

                coilsRestored += 1
                let rowId = coilsRestored
                let invMd5 = FishingChecksum.userInvMd5(
                    rowId: rowId,
                    baseItemId: baseCoilId,
                    date: nowMs,
                    attributeValue: strength,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT INTO user_coils (id, coil_id, strength, date, md5)
                VALUES (?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(rowId)),
                    .integer(Int64(baseCoilId)),
                    .integer(Int64(strength)),
                    .integer(nowMs),
                    .text(invMd5)
                ])
            }

            // 5. Section[4] — Restore up to 5 lines (`C0.a.m()`: `name:weight:length|...` or `not`)
            try connection.run("DELETE FROM user_fishing_lines;")
            var linesRestored = 0
            let lineTokens = sections[4].split(separator: "|").map(String.init)
            for token in lineTokens {
                guard token != "not", token.contains(":") else { continue }
                let fields = token.split(separator: ":").map(String.init)
                guard fields.count >= 3,
                      let weightKg = Int(fields[1]),
                      let lengthM = Int(fields[2]) else { continue }
                let name = fields[0]

                let lineRows = try connection.query(
                    "SELECT id, price FROM fishing_lines WHERE name = ? LIMIT 1;",
                    bindings: [.text(name)]
                )
                guard let lineRow = lineRows.first else { continue }
                let baseLineId = lineRow.int("id")
                let basePrice = lineRow.int("price")
                if basePrice == 0 && weightKg > 0 {
                    try connection.run(
                        "UPDATE fishing_lines SET weight = ? WHERE id = ?;",
                        bindings: [.integer(Int64(weightKg)), .integer(Int64(baseLineId))]
                    )
                }

                linesRestored += 1
                let rowId = linesRestored
                let invMd5 = FishingChecksum.userInvMd5(
                    rowId: rowId,
                    baseItemId: baseLineId,
                    date: nowMs,
                    attributeValue: lengthM,
                    installationUuid: installationUuid
                )
                try connection.run("""
                INSERT INTO user_fishing_lines (id, fishing_line_id, length, date, md5)
                VALUES (?, ?, ?, ?, ?);
                """, bindings: [
                    .integer(Int64(rowId)),
                    .integer(Int64(baseLineId)),
                    .integer(Int64(lengthM)),
                    .integer(nowMs),
                    .text(invMd5)
                ])
            }

            // Rebuild DataSigns 1..7 (`fillFishingRodsLegal`, `fillCoilsLegal`, `fillFishingLinesLegal`)
            try catalog.rebuildReferenceDataSigns(nowMs: nowMs)

            // 6. Section[5] — Restore Achievements (`C0.a.j()`: `id:score:level|...`, active when `length > 2`)
            var achievsRestored = 0
            let achSection = sections[5].trimmingCharacters(in: .whitespacesAndNewlines)
            if achSection.count > 2 {
                // In `C0.a.l` (`pc=0085`), Achievement #1 is incremented by +1 first before restoring
                _ = try updateAchievementProgress(achievementId: 1, valueOrDelta: 1, nowMs: nowMs)
                for token in achSection.split(separator: "|") {
                    let parts = token.split(separator: ":").map(String.init)
                    guard parts.count >= 3,
                          let achId = Int(parts[0]),
                          let score = Int(parts[1]),
                          let level = Int(parts[2]),
                          let existing = try loadAchievement(id: achId) else { continue }
                    let newMd5 = FishingChecksum.achievementMd5(
                        id: achId,
                        score: score,
                        level: level,
                        nag: existing.nag,
                        nagsize: existing.nagSize,
                        date: nowMs,
                        installationUuid: installationUuid
                    )
                    try connection.run("""
                    UPDATE achievements SET score = ?, level = ?, date = ?, md5 = ? WHERE id = ?;
                    """, bindings: [
                        .integer(Int64(score)),
                        .integer(Int64(level)),
                        .integer(nowMs),
                        .text(newMd5),
                        .integer(Int64(achId))
                    ])
                    achievsRestored += 1
                }
            }

            // 7. Section[6] — Restore Quests (`C0.a.o()`: `m0|m1|...|m43`, active when `length > 2`)
            var questsRestored = 0
            let questSection = sections[6].trimmingCharacters(in: .whitespacesAndNewlines)
            if questSection.count > 2 {
                let madeValues = questSection.split(separator: "|").compactMap { Int($0) }
                let allQuests = try listQuests()
                for (idx, madeVal) in madeValues.enumerated() where idx < allQuests.count {
                    let q = allQuests[idx]
                    let newMd5 = FishingChecksum.questMd5(
                        id: q.id,
                        type: q.type,
                        fish: q.fishCsv,
                        bait: q.baitCsv,
                        num: q.numCsv,
                        weight: q.weightCsv,
                        cat: q.requiredCategory,
                        nag: q.rewardCsv,
                        res: q.progressRes,
                        made: madeVal,
                        date: nowMs,
                        installationUuid: installationUuid
                    )
                    try connection.run("""
                    UPDATE quests SET made = ?, date = ?, md5 = ? WHERE id = ?;
                    """, bindings: [
                        .integer(Int64(madeVal)),
                        .integer(nowMs),
                        .text(newMd5),
                        .integer(Int64(q.id))
                    ])
                    questsRestored += 1
                }
            }

            return AuthRestoreSummary(
                experience: exp,
                categoryRank: newRank,
                balanceCoins: balance,
                restoredRodsCount: rodsRestored,
                restoredCoilsCount: coilsRestored,
                restoredLinesCount: linesRestored,
                restoredAchievementsCount: achievsRestored,
                restoredQuestsCount: questsRestored
            )
        }
    }

    /// Parses the 37+ field CSV response from `online.php` (`MainActivity$d.c(String)`, `NETWORK.md` Section 4.2),
    /// updates the database specs for the 3 online rods (`id = 11, 12, 13`), 3 online coils (`id = 8, 9, 10`),
    /// and 3 online lines (`id = 14, 15, 16`), and rebuilds `DataSign` #2, #3, #4.
    @discardableResult
    public func applyOnlineShopCSV(_ csv: String, nowMs: Int64) throws -> OnlineShopSnapshot {
        let fields = csv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard fields.count >= 37,
              let pearls = Int(fields[0]) else {
            throw PlayerPersistenceError.invalidInventoryItem("Expected at least 37 CSV fields in online.php response, got \(fields.count)")
        }

        let rodWeights = (1...3).map { Int(fields[$0]) ?? 0 }
        let rodPrices = (4...6).map { Int(fields[$0]) ?? 0 }
        let coilBearings = (7...9).map { Int(fields[$0]) ?? 0 }
        let coilPrices = (10...12).map { Int(fields[$0]) ?? 0 }
        let lineWeights = (13...15).map { Int(fields[$0]) ?? 0 }
        let lineLengths = (16...18).map { Int(fields[$0]) ?? 0 }
        let linePrices = (19...21).map { Int(fields[$0]) ?? 0 }
        let couponPrices = (30...36).map { Int(fields[$0]) ?? 0 }

        var notesCount = 0
        if let lastField = fields.last, lastField.contains("note") {
            let parts = lastField.split(separator: "=")
            if parts.count == 2, let k = Int(parts[1]) {
                notesCount = k
            }
        }

        try connection.transaction {
            // Online rods: IDs 11 ('venol'), 12 ('master fish'), 13 ('dasf')
            for i in 0..<3 {
                let rodId = 11 + i
                try connection.run(
                    "UPDATE fishing_rods SET weight = ? WHERE id = ?;",
                    bindings: [.integer(Int64(rodWeights[i])), .integer(Int64(rodId))]
                )
            }
            // Online coils: IDs 8, 9, 10
            for i in 0..<3 {
                let coilId = 8 + i
                try connection.run(
                    "UPDATE coils SET bearing_count = ? WHERE id = ?;",
                    bindings: [.integer(Int64(coilBearings[i])), .integer(Int64(coilId))]
                )
            }
            // Online lines: IDs 14, 15, 16 ('big fish')
            for i in 0..<3 {
                let lineId = 14 + i
                try connection.run(
                    "UPDATE fishing_lines SET weight = ?, stock_length = ? WHERE id = ?;",
                    bindings: [
                        .integer(Int64(lineWeights[i])),
                        .integer(Int64(lineLengths[i])),
                        .integer(Int64(lineId))
                    ]
                )
            }
            try catalog.rebuildReferenceDataSigns(nowMs: nowMs)
        }

        return OnlineShopSnapshot(
            pearlsBalance: pearls,
            onlineRodWeightsKg: rodWeights,
            onlineRodPearlPrices: rodPrices,
            onlineCoilBearings: coilBearings,
            onlineCoilPearlPrices: coilPrices,
            onlineLineWeightsKg: lineWeights,
            onlineLineStockLengthsM: lineLengths,
            onlineLinePearlPrices: linePrices,
            couponPearlPrices: couponPrices,
            unreadNotesCount: notesCount
        )
    }
}