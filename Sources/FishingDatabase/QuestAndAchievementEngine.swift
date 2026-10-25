import Foundation
import FishingCore

/// Implements the achievement progression (`F0.o.a`), quest evaluation (`F0.o.b`), and personal
/// species records (`records` table / `MyRecordsActivity`) from `classes.dex` (`MECHANICS.md` Section 6).

/// Result of claiming a completed quest reward (`QuestActivity.W`).
public struct QuestRewardClaimResult: Sendable, Equatable {
    public let questId: Int
    public let coinsAwarded: Int
    public let experienceAwarded: Int
    public let newBalance: Int
    public let newExperience: Int
    public let newCategoryRank: Int

    public init(
        questId: Int,
        coinsAwarded: Int,
        experienceAwarded: Int,
        newBalance: Int,
        newExperience: Int,
        newCategoryRank: Int
    ) {
        self.questId = questId
        self.coinsAwarded = coinsAwarded
        self.experienceAwarded = experienceAwarded
        self.newBalance = newBalance
        self.newExperience = newExperience
        self.newCategoryRank = newCategoryRank
    }
}

/// Per-target-slot progress row for `QuestActivity` (`Ly0/h` adapter).
public struct QuestTargetSlotProgress: Sendable, Equatable, Identifiable {
    public var id: Int { slotIndex }
    public let slotIndex: Int
    public let fishId: Int
    public let fishName: String
    public let conditionText: String
    public let progressText: String
    public let currentValue: Int
    public let goalValue: Int
    public let isSlotCompleted: Bool

    public init(
        slotIndex: Int,
        fishId: Int,
        fishName: String,
        conditionText: String,
        progressText: String,
        currentValue: Int,
        goalValue: Int,
        isSlotCompleted: Bool
    ) {
        self.slotIndex = slotIndex
        self.fishId = fishId
        self.fishName = fishName
        self.conditionText = conditionText
        self.progressText = progressText
        self.currentValue = currentValue
        self.goalValue = goalValue
        self.isSlotCompleted = isSlotCompleted
    }
}

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

            let oldLevel = ach.level
            let thresholds = BalanceTables.achievementThresholds[achievementId - 1]
            while ach.level < thresholds.count && ach.score >= thresholds[ach.level] {
                ach.level += 1
            }
            if ach.level > oldLevel {
                ach.nag = 1
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

    /// Updates Achievement #6 («Торговец», sold fish count) and Achievement #10 («Богач», max balance) after selling fish (`MainActivity$e.q`).
    public func evaluateAchievementOnFishSale(soldFishCount: Int = 0, newBalance: Int, nowMs: Int64) throws {
        try connection.transaction {
            if soldFishCount > 0 {
                _ = try updateAchievementProgress(achievementId: 6, valueOrDelta: soldFishCount, nowMs: nowMs)
            }
            _ = try updateAchievementProgress(achievementId: 10, valueOrDelta: newBalance, nowMs: nowMs)
        }
    }

    /// Reconstructs `F0.o$a.e()` (`pc=0000..0212` in `classes.dex`):
    /// After `achievs.php` returns `"1000"`, awards `nagSize * level` experience to `user_data` for every achievement
    /// with `nag == 1` and resets `nag = 0`.
    @discardableResult
    public func claimPendingAchievementLevelRewards(nowMs: Int64) throws -> Int {
        return try connection.transaction {
            let rows = try listAchievements()
            var totalBonusXp = 0
            for var ach in rows where ach.nag == 1 {
                let expectedMd5 = FishingChecksum.achievementMd5(
                    id: ach.id,
                    score: ach.score,
                    level: ach.level,
                    nag: ach.nag,
                    nagsize: ach.nagSize,
                    date: ach.date,
                    installationUuid: installationUuid
                )
                guard ach.md5 == expectedMd5 else { continue }
                let bonusXp = max(0, ach.nagSize * max(1, ach.level))
                totalBonusXp += bonusXp
                ach.nag = 0
                ach.date = nowMs
                ach.md5 = FishingChecksum.achievementMd5(
                    id: ach.id,
                    score: ach.score,
                    level: ach.level,
                    nag: 0,
                    nagsize: ach.nagSize,
                    date: nowMs,
                    installationUuid: installationUuid
                )
                try connection.run(
                    "UPDATE achievements SET nag = 0, date = ?, md5 = ? WHERE id = ?;",
                    bindings: [
                        .integer(nowMs),
                        .text(ach.md5),
                        .integer(Int64(ach.id))
                    ]
                )
            }
            if totalBonusXp > 0 {
                var profile = try loadPlayerProfile()
                profile.experience += totalBonusXp
                profile.category = ProgressionCalculator.categoryForExperience(
                    profile.experience,
                    balanceTables: balanceTables
                )
                let newMd5 = FishingChecksum.userDataMd5(
                    balance: profile.balance,
                    experience: profile.experience,
                    category: profile.category,
                    date: nowMs,
                    installationUuid: installationUuid
                )
                try connection.run(
                    "UPDATE user_data SET experience = ?, category = ?, date = ?, md5 = ? WHERE id = 1;",
                    bindings: [
                        .integer(Int64(profile.experience)),
                        .integer(Int64(profile.category)),
                        .integer(nowMs),
                        .text(newMd5)
                    ]
                )
            }
            return totalBonusXp
        }
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
            guard var quest = allQuests.first(where: { $0.made <= 1 && $0.requiredCategory <= playerCategory }) else {
                return nil
            }
            // In original `F0.o.b` (`pc=008b..008f`): if the active quest has `made == 1` (completed, awaiting reward claim in `QuestActivity`),
            // subsequent quests do not advance until the player claims the current quest reward (`made -> 2`).
            guard quest.made == 0 else {
                return quest
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


    /// Returns the active quest for the player (`QuestActivity.onCreate`: first quest with `made <= 1 && cat <= category`).
    public func activeQuest(playerCategory: Int) throws -> QuestRecord? {
        let allQuests = try listQuests()
        return allQuests.first(where: { $0.made <= 1 && $0.requiredCategory <= playerCategory })
    }

    /// Parses `quest.rewardCsv` (`nag`, e.g. `"200,150"` or `"5000,1000"`) into `(coins, experience)` (`QuestActivity.W`).
    public static func parseQuestRewards(_ rewardCsv: String) -> (coins: Int, experience: Int) {
        let parts = rewardCsv.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let coins = parts.first.flatMap(Int.init) ?? 0
        let exp = (parts.count > 1 ? Int(parts[1]) : nil) ?? 0
        return (coins: max(0, coins), experience: max(0, exp))
    }

    /// Formats the required bait list for a quest (`QuestActivity.onCreate` `pc=0175..01df`).
    public static func formatQuestBaitsDescription(
        baitCsv: String,
        baitNamesById: [Int: String]
    ) -> String {
        let ids = baitCsv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if ids.isEmpty || ids.contains(0) {
            return "любая"
        }
        let names = ids.map { baitNamesById[$0] ?? "наживка #\($0)" }
        return names.joined(separator: ", ")
    }

    /// Reconstructs `Ly0/h` (`QuestTargetAdapter`) per-fish target rows for `QuestActivity`.
    public static func buildQuestTargetSlots(
        for quest: QuestRecord,
        fishCatalogById: [Int: FishSpecies]
    ) -> [QuestTargetSlotProgress] {
        let fishIds = quest.fishCsv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let counts = quest.numCsv.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let weights = quest.weightCsv.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        let slotCount = max(1, fishIds.count)

        let rawProgress: [Int]
        if quest.progressRes == "null" || quest.progressRes.isEmpty {
            rawProgress = [Int](repeating: 0, count: slotCount)
        } else {
            let parsed = quest.progressRes.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parsed.count >= slotCount {
                rawProgress = Array(parsed.prefix(slotCount))
            } else {
                rawProgress = parsed + [Int](repeating: 0, count: slotCount - parsed.count)
            }
        }

        var slots: [QuestTargetSlotProgress] = []
        for idx in 0..<slotCount {
            let fishId = idx < fishIds.count ? fishIds[idx] : 0
            let fishName = (fishId == 0) ? "Любая рыба" : (fishCatalogById[fishId]?.name ?? "Рыба #\(fishId)")
            let currentVal = rawProgress[idx]

            let conditionText: String
            let progressText: String
            let goalVal: Int
            let isDone: Bool

            switch quest.type {
            case 2:
                // Cumulative weight in grams (`Ly0/h.c` formats as kg)
                let goalW = idx < weights.count ? (Int(weights[idx]) ?? 0) : 0
                goalVal = max(1, goalW)
                let shownCur = quest.made >= 2 ? goalVal : min(goalVal, currentVal)
                isDone = shownCur >= goalVal || quest.made >= 1
                conditionText = "вес любой"
                progressText = "\(formatGramsAsKgOrGrams(shownCur)) / \(formatGramsAsKgOrGrams(goalVal))"

            case 3:
                let minW = idx < weights.count ? (Int(weights[idx]) ?? 0) : 0
                let goalC = max(1, idx < counts.count ? counts[idx] : 1)
                goalVal = goalC
                let shownCur = quest.made >= 2 ? goalC : min(goalC, currentVal)
                isDone = shownCur >= goalC || quest.made >= 1
                conditionText = "от \(formatGramsAsKgOrGrams(minW))"
                progressText = "\(shownCur) / \(goalC) шт."

            case 4:
                let maxW = idx < weights.count ? (Int(weights[idx]) ?? 0) : 0
                let goalC = max(1, idx < counts.count ? counts[idx] : 1)
                goalVal = goalC
                let shownCur = quest.made >= 2 ? goalC : min(goalC, currentVal)
                isDone = shownCur >= goalC || quest.made >= 1
                conditionText = "до \(formatGramsAsKgOrGrams(maxW))"
                progressText = "\(shownCur) / \(goalC) шт."

            case 7:
                let rawRange = idx < weights.count ? weights[idx] : "0-0"
                let bounds = rawRange.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                let minW = bounds.first ?? 0
                let maxW = bounds.count > 1 ? bounds[1] : minW
                let goalC = max(1, idx < counts.count ? counts[idx] : 1)
                goalVal = goalC
                let shownCur = quest.made >= 2 ? goalC : min(goalC, currentVal)
                isDone = shownCur >= goalC || quest.made >= 1
                conditionText = "\(formatGramsAsKgOrGrams(minW)) – \(formatGramsAsKgOrGrams(maxW))"
                progressText = "\(shownCur) / \(goalC) шт."

            default:
                // Type 1: count of fish of any weight
                let goalC = max(1, idx < counts.count ? counts[idx] : 1)
                goalVal = goalC
                let shownCur = quest.made >= 2 ? goalC : min(goalC, currentVal)
                isDone = shownCur >= goalC || quest.made >= 1
                conditionText = "вес любой"
                progressText = "\(shownCur) / \(goalC) шт."
            }

            slots.append(
                QuestTargetSlotProgress(
                    slotIndex: idx,
                    fishId: fishId,
                    fishName: fishName,
                    conditionText: conditionText,
                    progressText: progressText,
                    currentValue: currentVal,
                    goalValue: goalVal,
                    isSlotCompleted: isDone
                )
            )
        }
        return slots
    }

    public static func formatGramsAsKgOrGrams(_ grams: Int) -> String {
        if grams >= 1000 {
            if grams % 1000 == 0 {
                return "\(grams / 1000) кг"
            } else if grams % 100 == 0 {
                return String(format: "%.1f кг", Double(grams) / 1000.0)
            } else {
                return String(format: "%.3f кг", Double(grams) / 1000.0)
            }
        }
        return "\(grams) г"
    }

    /// Reconstructs `QuestActivity.W(Quest)` (`pc=0000..015b`):
    /// Claims the reward for a completed quest (`made == 1`), awarding `nag[0]` coins and `nag[1]` XP
    /// to `user_data`, recalculating `category`, and advancing `quest.made` from `1` to `2`.
    @discardableResult
    public func claimQuestReward(
        questId: Int,
        nowMs: Int64
    ) throws -> QuestRewardClaimResult {
        try connection.transaction {
            let allQuests = try listQuests()
            guard var quest = allQuests.first(where: { $0.id == questId }) else {
                throw PlayerPersistenceError.invalidInventoryItem("Quest #\(questId) not found")
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
                throw PlayerPersistenceError.integrityCheckFailed("Quest #\(quest.id) MD5 mismatch before claimQuestReward")
            }
            guard quest.made == 1 else {
                throw PlayerPersistenceError.invalidInventoryItem("Quest #\(quest.id) is not in claimable state (made=\(quest.made))")
            }

            guard try verifyPlayerProfileIntegrity() else {
                throw PlayerPersistenceError.integrityCheckFailed("user_data MD5 mismatch before claimQuestReward")
            }
            var profile = try loadPlayerProfile()
            let rewards = Self.parseQuestRewards(quest.rewardCsv)

            profile.balance += rewards.coins
            profile.experience += rewards.experience
            profile.category = ProgressionCalculator.categoryForExperience(
                profile.experience,
                balanceTables: balanceTables
            )
            let newProfileMd5 = FishingChecksum.userDataMd5(
                balance: profile.balance,
                experience: profile.experience,
                category: profile.category,
                date: nowMs,
                installationUuid: installationUuid
            )
            try connection.run("""
            UPDATE user_data SET balance = ?, experience = ?, category = ?, date = ?, md5 = ? WHERE id = 1;
            """, bindings: [
                .integer(Int64(profile.balance)),
                .integer(Int64(profile.experience)),
                .integer(Int64(profile.category)),
                .integer(nowMs),
                .text(newProfileMd5)
            ])

            quest.made = 2
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
            UPDATE quests SET made = ?, date = ?, md5 = ? WHERE id = ?;
            """, bindings: [
                .integer(Int64(quest.made)),
                .integer(quest.date),
                .text(quest.md5),
                .integer(Int64(quest.id))
            ])

            return QuestRewardClaimResult(
                questId: quest.id,
                coinsAwarded: rewards.coins,
                experienceAwarded: rewards.experience,
                newBalance: profile.balance,
                newExperience: profile.experience,
                newCategoryRank: profile.category
            )
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
