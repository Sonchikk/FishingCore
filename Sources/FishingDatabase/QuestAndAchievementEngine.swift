import Foundation
import FishingCore

/// Implements the achievement progression (`F0.o.a`), quest evaluation (`F0.o.b`), and personal
/// species records (`records` table / `MyRecordsActivity`) from `classes.dex` (`MECHANICS.md` Section 6).
extension PlayerStateRepository {

    // MARK: - 1. Personal Species Records (`records` table)

    /// Lists personal records from `records` (`id = 1..141`), optionally filtering to only caught species (`weight > 0`).
    public func listPersonalRecords(onlyCaught: Bool = false) throws -> [PersonalSpeciesRecord] {
        let sql: String
        if onlyCaught {
            sql = "SELECT id, fish_name, weight, bait_id FROM records WHERE weight > 0 ORDER BY weight DESC, id ASC;"
        } else {
            sql = "SELECT id, fish_name, weight, bait_id FROM records ORDER BY id ASC;"
        }
        let rows = try connection.query(sql)
        return rows.map {
            PersonalSpeciesRecord(
                id: $0.int("id"),
                fishName: $0.string("fish_name"),
                weightGrams: $0.int("weight"),
                baitId1Based: $0.int("bait_id")
            )
        }
    }

    // MARK: - 2. Achievements (`F0.o.a`, 14 Achievements with Score Obfuscation `2..10`)

    public func listAchievements() throws -> [AchievementRecord] {
        let rows = try connection.query("""
        SELECT id, image, score, level, nag, nagsize, date, md5
        FROM achievements ORDER BY id ASC;
        """)
        return rows.map {
            AchievementRecord(
                id: $0.int("id"),
                imageResId: $0.int("image"),
                score: $0.int("score"),
                level: $0.int("level"),
                nag: $0.int("nag"),
                nagSize: $0.int("nagsize"),
                date: $0.int64("date"),
                md5: $0.string("md5")
            )
        }
    }

    public func loadAchievement(id: Int) throws -> AchievementRecord? {
        let rows = try connection.query(
            "SELECT id, image, score, level, nag, nagsize, date, md5 FROM achievements WHERE id = ?;",
            bindings: [.integer(Int64(id))]
        )
        guard let row = rows.first else { return nil }
        return AchievementRecord(
            id: row.int("id"),
            imageResId: row.int("image"),
            score: row.int("score"),
            level: row.int("level"),
            nag: row.int("nag"),
            nagSize: row.int("nagsize"),
            date: row.int64("date"),
            md5: row.string("md5")
        )
    }

    /// Updates an achievement (`F0.o.a(Context, DatabaseHelper, int id, int value)`):
    /// - Verifies existing `AchievementMd5`;
    /// - Applies the original in-memory score obfuscation multiplier `v14 in 2..10` (`F0.o.c(2, 10)`)
    ///   and divides by `v14` (`pc=0143`) before comparing against `BalanceTables.achievementThresholds[id - 1]`;
    /// - For high-water-mark achievements (`id == 9` «Трофейщик» max fish weight, `id == 10` «Богач» max balance),
    ///   updates `score = max(score, value)`; for cumulative achievements (`id == 2, 3, 7, 8, 12, ...`), adds `value`;
    /// - Advances `level` (`0..3`) when `score >= thresholds[level]` and updates `AchievementMd5`.
    @discardableResult
    public func updateAchievementProgress(
        achievementId: Int,
        valueOrDelta: Int,
        nowMs: Int64,
        obfuscationMultiplier: Int = 5
    ) throws -> AchievementRecord? {
        guard achievementId >= 1 && achievementId <= BalanceTables.achievementThresholds.count else {
            return nil
        }
        return try connection.transaction {
            guard var ach = try loadAchievement(id: achievementId) else {
                return nil
            }

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
                throw PlayerPersistenceError.integrityCheckFailed("Achievement #\(achievementId) MD5 mismatch")
            }

            // Original `F0.o.a` obfuscation multiplier `v14 = F0.o.c(2, 10)` (`2..10`)
            let v14 = max(2, min(10, obfuscationMultiplier))
            let isHighWaterMark = (achievementId == 9 || achievementId == 10)
            let rawNewScore: Int
            if isHighWaterMark {
                rawNewScore = max(ach.score, valueOrDelta)
            } else {
                rawNewScore = ach.score + valueOrDelta
            }

            let obfuscatedScore = rawNewScore * v14
            let deobfuscatedScore = obfuscatedScore / v14
            ach.score = deobfuscatedScore

            let thresholds = BalanceTables.achievementThresholds[achievementId - 1]
            while ach.level < thresholds.count && ach.score >= thresholds[ach.level] {
                ach.level += 1
            }

            ach.date = nowMs
            ach.md5 = FishingChecksum.achievementMd5(
                id: ach.id,
                score: ach.score,
                level: ach.level,
                nag: ach.nag,
                nagsize: ach.nagSize,
                date: ach.date,
                installationUuid: installationUuid
            )

            try connection.run("""
            UPDATE achievements SET
                score = ?,
                level = ?,
                nag = ?,
                date = ?,
                md5 = ?
            WHERE id = ?;
            """, bindings: [
                .integer(Int64(ach.score)),
                .integer(Int64(ach.level)),
                .integer(Int64(ach.nag)),
                .integer(ach.date),
                .text(ach.md5),
                .integer(Int64(ach.id))
            ])

            return ach
        }
    }

    /// Evaluates all catch-triggered achievements (`C0.d` + `LC0/d$a.onClick`):
    /// - `#2` («Рыболов»): `+1` fish caught;
    /// - `#7` («Счастливчик»): `+1` if decimal digit sum of `weightGrams` == `25`;
    /// - `#8` («Игрок»): `+1` if `weightGrams` is a repdigit of 4+ identical digits (`1111`, `2222`, ...);
    /// - `#9` («Трофейщик»): `max(score, weightGrams)`;
    /// - `#12` («Чистильщик»): `+1` if `fish.id == 71` («Старая покрышка») or `112` («Старый ботинок»).
    public func evaluateAchievementsOnCatch(_ caught: CaughtUserFish, nowMs: Int64) throws {
        try connection.transaction {
            _ = try updateAchievementProgress(achievementId: 2, valueOrDelta: 1, nowMs: nowMs)
            _ = try updateAchievementProgress(achievementId: 9, valueOrDelta: caught.weightGrams, nowMs: nowMs)

            if ProgressionCalculator.isLuckyWeight25(caught.weightGrams) {
                _ = try updateAchievementProgress(achievementId: 7, valueOrDelta: 1, nowMs: nowMs)
            }
            if ProgressionCalculator.isRepdigitWeight(caught.weightGrams) {
                _ = try updateAchievementProgress(achievementId: 8, valueOrDelta: 1, nowMs: nowMs)
            }
            if ProgressionCalculator.isCleanerTrashCatch(fishId1Based: caught.fish.id) {
                _ = try updateAchievementProgress(achievementId: 12, valueOrDelta: 1, nowMs: nowMs)
            }
        }
    }

    /// Increments Achievement #3 («Хулиган») when a fishing rod breaks (`GameActivity$d`).
    public func evaluateAchievementOnRodBroken(nowMs: Int64) throws {
        _ = try updateAchievementProgress(achievementId: 3, valueOrDelta: 1, nowMs: nowMs)
    }

    /// Updates Achievement #10 («Богач») with the player's current coin balance after selling fish (`MainActivity$e.q`).
    public func evaluateAchievementOnFishSale(newBalance: Int, nowMs: Int64) throws {
        _ = try updateAchievementProgress(achievementId: 10, valueOrDelta: newBalance, nowMs: nowMs)
    }

    // MARK: - 3. Quests (`F0.o.b`, 44 Quests across Types 1, 2, 3, 4, 7)

    public func listQuests() throws -> [QuestRecord] {
        let rows = try connection.query("""
        SELECT id, type, fish, bait, num, weight, cat, nag, res, made, date, md5
        FROM quests ORDER BY id ASC;
        """)
        return rows.map {
            QuestRecord(
                id: $0.int("id"),
                type: $0.int("type"),
                fishCsv: $0.string("fish"),
                baitCsv: $0.string("bait"),
                numCsv: $0.string("num"),
                weightCsv: $0.string("weight"),
                requiredCategory: $0.int("cat"),
                rewardCsv: $0.string("nag"),
                progressRes: $0.string("res"),
                made: $0.int("made"),
                date: $0.int64("date"),
                md5: $0.string("md5")
            )
        }
    }

    /// Evaluates active quests on fish catch (`F0.o.b`):
    /// - Active only when `tasksEnabled == true` AND `languageCode` is `"ru"` or `"en"` (`F0.g.b(ctx)`);
    /// - Finds the first uncompleted quest (`made == 0`) with `requiredCategory <= playerCategory`;
    /// - Updates `progressRes` and marks `made = 1` when all target slots reach their goal.
    @discardableResult
    public func evaluateQuestsOnCatch(
        _ caught: CaughtUserFish,
        playerCategory: Int,
        tasksEnabled: Bool = true,
        languageCode: String = "ru",
        nowMs: Int64
    ) throws -> QuestRecord? {
        guard tasksEnabled && (languageCode == "ru" || languageCode == "en") else {
            return nil
        }

        return try connection.transaction {
            let allQuests = try listQuests()
            guard var quest = allQuests.first(where: { $0.made == 0 && $0.requiredCategory <= playerCategory }) else {
                return nil
            }

            let expectedMd5 = FishingChecksum.questMd5(
                id: quest.id,
                type: quest.type,
                fish: quest.fishCsv,
                bait: quest.baitCsv,
                num: quest.numCsv,
                weight: quest.weightCsv,
                cat: quest.requiredCategory,
                nag: quest.rewardCsv,
                res: quest.progressRes,
                made: quest.made,
                date: quest.date,
                installationUuid: installationUuid
            )
            guard quest.md5 == expectedMd5 else {
                throw PlayerPersistenceError.integrityCheckFailed("Quest #\(quest.id) MD5 mismatch")
            }

            let targetFishIds = parseIntList(quest.fishCsv)
            let allowedBaitIds = parseIntList(quest.baitCsv)
            let targetCounts = parseIntList(quest.numCsv)
            let targetWeights = quest.weightCsv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

            let caughtBaitId1Based = caught.baitIndex + 1
            let baitMatches = allowedBaitIds.isEmpty || allowedBaitIds.contains(0) || allowedBaitIds.contains(caughtBaitId1Based)
            guard baitMatches else { return quest }

            let slotCount = max(1, targetFishIds.count)
            var currentProgress = parseProgressSlots(quest.progressRes, count: slotCount)
            var didAdvance = false

            for slot in 0..<slotCount {
                let targetFishId = slot < targetFishIds.count ? targetFishIds[slot] : 0
                let fishMatches = (targetFishId == 0 || targetFishId == caught.fish.id)
                guard fishMatches else { continue }

                switch quest.type {
                case 1:
                    // Count of target fish
                    let goalCount = slot < targetCounts.count ? targetCounts[slot] : 1
                    if currentProgress[slot] < goalCount {
                        currentProgress[slot] += 1
                        didAdvance = true
                    }

                case 2:
                    // Cumulative weight in grams
                    let goalWeight = slot < targetWeights.count ? (Int(targetWeights[slot]) ?? 0) : 0
                    if currentProgress[slot] < goalWeight {
                        currentProgress[slot] = min(goalWeight, currentProgress[slot] + caught.weightGrams)
                        didAdvance = true
                    }

                case 3:
                    // Minimum weight per fish (`weight >= minWeight`)
                    let minWeight = slot < targetWeights.count ? (Int(targetWeights[slot]) ?? 0) : 0
                    let goalCount = max(1, slot < targetCounts.count ? targetCounts[slot] : 1)
                    if caught.weightGrams >= minWeight && currentProgress[slot] < goalCount {
                        currentProgress[slot] += 1
                        didAdvance = true
                    }

                case 4:
                    // Maximum weight per fish (`weight <= maxWeight`)
                    let maxWeight = slot < targetWeights.count ? (Int(targetWeights[slot]) ?? Int.max) : Int.max
                    let goalCount = max(1, slot < targetCounts.count ? targetCounts[slot] : 1)
                    if caught.weightGrams <= maxWeight && currentProgress[slot] < goalCount {
                        currentProgress[slot] += 1
                        didAdvance = true
                    }

                case 7:
                    // Exact weight interval `min-max` grams
                    let rawRange = slot < targetWeights.count ? targetWeights[slot] : "0-0"
                    let bounds = rawRange.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    let minW = bounds.first ?? 0
                    let maxW = bounds.count > 1 ? bounds[1] : Int.max
                    let goalCount = max(1, slot < targetCounts.count ? targetCounts[slot] : 1)
                    if caught.weightGrams >= minW && caught.weightGrams <= maxW && currentProgress[slot] < goalCount {
                        currentProgress[slot] += 1
                        didAdvance = true
                    }

                default:
                    break
                }
            }

            guard didAdvance else { return quest }

            quest.progressRes = currentProgress.map(String.init).joined(separator: ",")
            if isQuestCompleted(quest: quest, progressSlots: currentProgress, targetCounts: targetCounts, targetWeights: targetWeights) {
                quest.made = 1
            }
            quest.date = nowMs
            quest.md5 = FishingChecksum.questMd5(
                id: quest.id,
                type: quest.type,
                fish: quest.fishCsv,
                bait: quest.baitCsv,
                num: quest.numCsv,
                weight: quest.weightCsv,
                cat: quest.requiredCategory,
                nag: quest.rewardCsv,
                res: quest.progressRes,
                made: quest.made,
                date: quest.date,
                installationUuid: installationUuid
            )

            try connection.run("""
            UPDATE quests SET
                res = ?,
                made = ?,
                date = ?,
                md5 = ?
            WHERE id = ?;
            """, bindings: [
                .text(quest.progressRes),
                .integer(Int64(quest.made)),
                .integer(quest.date),
                .text(quest.md5),
                .integer(Int64(quest.id))
            ])

            return quest
        }
    }

    private func parseIntList(_ csv: String) -> [Int] {
        csv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func parseProgressSlots(_ res: String, count: Int) -> [Int] {
        if res == "null" || res.isEmpty {
            return [Int](repeating: 0, count: count)
        }
        let parsed = parseIntList(res)
        if parsed.count >= count {
            return Array(parsed.prefix(count))
        }
        return parsed + [Int](repeating: 0, count: count - parsed.count)
    }

    private func isQuestCompleted(
        quest: QuestRecord,
        progressSlots: [Int],
        targetCounts: [Int],
        targetWeights: [String]
    ) -> Bool {
        for i in 0..<progressSlots.count {
            switch quest.type {
            case 2:
                let goalWeight = i < targetWeights.count ? (Int(targetWeights[i]) ?? 0) : 0
                if progressSlots[i] < goalWeight { return false }
            default:
                let goalCount = max(1, i < targetCounts.count ? targetCounts[i] : 1)
                if progressSlots[i] < goalCount { return false }
            }
        }
        return true
    }
}
