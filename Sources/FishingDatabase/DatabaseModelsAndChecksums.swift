import Foundation
import FishingCore

// MARK: - Pure Swift RFC 1321 MD5 (Matches DatabaseHelper.md5 & F0.h/F0.i Bytecode)

public enum FishingChecksum: Sendable {
    private static let shiftAmounts: [UInt32] = [
        7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
        5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
        4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
        6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21
    ]

    private static let sineTable: [UInt32] = [
        0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
        0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
        0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
        0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
        0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
        0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
        0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
        0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
        0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
    ]

    /// Computes lowercase 32-character hexadecimal MD5 of UTF-8 string (`DatabaseHelper.md5`).
    public static func md5(_ input: String) -> String {
        let bytes = Array(input.utf8)
        var message = bytes
        let bitLength = UInt64(bytes.count) &* 8

        message.append(0x80)
        while (message.count % 64) != 56 {
            message.append(0x00)
        }
        for i in 0..<8 {
            message.append(UInt8((bitLength >> (i * 8)) & 0xff))
        }

        var a0: UInt32 = 0x67452301
        var b0: UInt32 = 0xefcdab89
        var c0: UInt32 = 0x98badcfe
        var d0: UInt32 = 0x10325476

        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            var m = [UInt32](repeating: 0, count: 16)
            for j in 0..<16 {
                let offset = chunkStart + j * 4
                m[j] = UInt32(message[offset])
                    | (UInt32(message[offset + 1]) << 8)
                    | (UInt32(message[offset + 2]) << 16)
                    | (UInt32(message[offset + 3]) << 24)
            }

            var A = a0
            var B = b0
            var C = c0
            var D = d0

            for i in 0..<64 {
                let F: UInt32
                let g: Int
                if i < 16 {
                    F = (B & C) | ((~B) & D)
                    g = i
                } else if i < 32 {
                    F = (D & B) | ((~D) & C)
                    g = (5 * i + 1) % 16
                } else if i < 48 {
                    F = B ^ C ^ D
                    g = (3 * i + 5) % 16
                } else {
                    F = C ^ (B | (~D))
                    g = (7 * i) % 16
                }

                let temp = D
                D = C
                C = B
                let sum = A &+ F &+ sineTable[i] &+ m[g]
                let shift = shiftAmounts[i]
                let rotated = (sum << shift) | (sum >> (32 - shift))
                B = B &+ rotated
                A = temp
            }

            a0 = a0 &+ A
            b0 = b0 &+ B
            c0 = c0 &+ C
            d0 = d0 &+ D
        }

        let words = [a0, b0, c0, d0]
        var hex = ""
        hex.reserveCapacity(32)
        for word in words {
            for byteIndex in 0..<4 {
                let byte = UInt8((word >> (byteIndex * 8)) & 0xff)
                if byte < 16 { hex.append("0") }
                hex.append(String(byte, radix: 16, uppercase: false))
            }
        }
        return hex
    }

    // MARK: - Exact DatabaseHelper.*Md5 Formulas (Verified by classes.dex Bytecode)

    /// `DatabaseHelper.fishMd5(Context, int id, int unitWeight, int unitPrice, int behaviorSum)` (`pc=0000..001a`)
    /// Sums `id + unitWeight + unitPrice + behaviorSum` as 32-bit signed int, appends `installationUuid`, and hashes with MD5.
    public static func fishMd5(
        id: Int,
        unitWeight: Int,
        unitPrice: Int,
        strength: Int,
        stamina: Int,
        intelligence: Int,
        aggression: Int,
        installationUuid: String
    ) -> String {
        let behaviorSum = Int32(truncatingIfNeeded: strength)
            &+ Int32(truncatingIfNeeded: stamina)
            &+ Int32(truncatingIfNeeded: intelligence)
            &+ Int32(truncatingIfNeeded: aggression)
        let total = Int32(truncatingIfNeeded: id)
            &+ Int32(truncatingIfNeeded: unitWeight)
            &+ Int32(truncatingIfNeeded: unitPrice)
            &+ behaviorSum
        return md5("\(total)\(installationUuid)")
    }

    /// `DatabaseHelper.UserDataMd5(Context, int balance, int experience, int category, long date)` (`pc=0000..001b`)
    /// Note: in `fillUserDataTable`, `MainActivity.Y`, `ShopActivity`, and `C0.d`, the arguments passed are `(balance, experience, category, date)`.
    public static func userDataMd5(
        balance: Int,
        experience: Int,
        category: Int,
        date: Int64,
        installationUuid: String
    ) -> String {
        let intSum = Int32(truncatingIfNeeded: balance)
            &+ Int32(truncatingIfNeeded: experience)
            &+ Int32(truncatingIfNeeded: category)
        let total = Int64(intSum) &+ date
        return md5("\(total)\(installationUuid)")
    }

    /// `DatabaseHelper.UserInvMd5(Context, int rowId, long baseItemId, long date, int strengthlengthOrTime)` (`pc=0000..001c`)
    public static func userInvMd5(
        rowId: Int,
        baseItemId: Int,
        date: Int64,
        attributeValue: Int,
        installationUuid: String
    ) -> String {
        let total = Int64(Int32(truncatingIfNeeded: rowId))
            &+ Int64(baseItemId)
            &+ date
            &+ Int64(Int32(truncatingIfNeeded: attributeValue))
        return md5("\(total)\(installationUuid)")
    }

    /// `DatabaseHelper.AchievementMd5(Context, int id, int score, int level, int nag, int nagsize, long date)` (`pc=0000..001d`)
    public static func achievementMd5(
        id: Int,
        score: Int,
        level: Int,
        nag: Int,
        nagsize: Int,
        date: Int64,
        installationUuid: String
    ) -> String {
        let intSum = Int32(truncatingIfNeeded: id)
            &+ Int32(truncatingIfNeeded: score)
            &+ Int32(truncatingIfNeeded: level)
            &+ Int32(truncatingIfNeeded: nag)
            &+ Int32(truncatingIfNeeded: nagsize)
        let total = Int64(intSum) &+ date
        return md5("\(total)\(installationUuid)")
    }

    /// `DatabaseHelper.QuestMd5(Context, int id, int type, String fish, String bait, String num, String weight, int cat, String nag, String res, int made, long date)` (`pc=0000..0033`)
    public static func questMd5(
        id: Int,
        type: Int,
        fish: String,
        bait: String,
        num: String,
        weight: String,
        cat: Int,
        nag: String,
        res: String,
        made: Int,
        date: Int64,
        installationUuid: String
    ) -> String {
        let idPlusType = Int32(truncatingIfNeeded: id) &+ Int32(truncatingIfNeeded: type)
        let payload = "\(idPlusType)\(fish)\(bait)\(num)\(weight)\(cat)\(nag)\(res)\(made)\(date)\(installationUuid)"
        return md5(payload)
    }

    /// `DatabaseHelper.UserTaskMd5(Context, int id, int type, int fish, int bait, int num, int weight, int totalWeight)`
    public static func userTaskMd5(
        id: Int,
        type: Int,
        fish: Int,
        bait: Int,
        num: Int,
        weight: Int,
        totalWeight: Int,
        installationUuid: String
    ) -> String {
        let sum = Int32(truncatingIfNeeded: id)
            &+ Int32(truncatingIfNeeded: type)
            &+ Int32(truncatingIfNeeded: fish)
            &+ Int32(truncatingIfNeeded: bait)
            &+ Int32(truncatingIfNeeded: num)
            &+ Int32(truncatingIfNeeded: weight)
            &+ Int32(truncatingIfNeeded: totalWeight)
        return md5("\(sum)\(installationUuid)")
    }

    /// `DatabaseHelper.UserTaskDataMd5(Context, int task, int num, int weight, int made, long date)`
    public static func userTaskDataMd5(
        task: Int,
        num: Int,
        weight: Int,
        made: Int,
        date: Int64,
        installationUuid: String
    ) -> String {
        let intSum = Int32(truncatingIfNeeded: task)
            &+ Int32(truncatingIfNeeded: num)
            &+ Int32(truncatingIfNeeded: weight)
            &+ Int32(truncatingIfNeeded: made)
        let total = Int64(intSum) &+ date
        return md5("\(total)\(installationUuid)")
    }

    /// `DatabaseHelper.createSign(Context, dao, int signId)` (`signId = 1..8`)
    /// Computes the table-level integrity checksum stored in `data_signs`.
    public static func dataSignMd5(sumOfPairs: Int, installationUuid: String) -> String {
        let sum32 = Int32(truncatingIfNeeded: sumOfPairs)
        return md5("\(sum32)\(installationUuid)")
    }
}

// MARK: - Reference & Player Database Models

public enum DataSignTableId: Int, Sendable, CaseIterable {
    case fishes = 1
    case fishingRods = 2
    case fishingLines = 3
    case coils = 4
    case coupons = 5
    case hooks = 6
    case baits = 7
    case userFishes = 8
}

public struct CouponSpec: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let dayCount: Int
    public let price: Int
    public let dn: Int

    public init(id: Int, name: String, dayCount: Int, price: Int, dn: Int) {
        self.id = id
        self.name = name
        self.dayCount = dayCount
        self.price = price
        self.dn = dn
    }
}

public struct PlayerProfileRecord: Sendable, Equatable {
    public var id: Int
    public var login: String
    public var password: String
    public var balance: Int
    public var experience: Int
    public var category: Int
    public var date: Int64
    public var md5: String

    public init(
        id: Int = 1,
        login: String = "",
        password: String = "",
        balance: Int = 500,
        experience: Int = 0,
        category: Int = 0,
        date: Int64 = 0,
        md5: String = ""
    ) {
        self.id = id
        self.login = login
        self.password = password
        self.balance = balance
        self.experience = experience
        self.category = category
        self.date = date
        self.md5 = md5
    }
}

public struct UserTackleSlotRecord: Sendable, Equatable {
    public static let unequippedSentinel: Int = Int(Int32.min) // -2147483648 (0x80000000)

    public var id: Int
    public var fishingRodId: Int
    public var fishingLineId: Int
    public var coilId: Int
    public var hookId: Int
    public var baitId: Int

    public init(
        id: Int = 1,
        fishingRodId: Int = Self.unequippedSentinel,
        fishingLineId: Int = Self.unequippedSentinel,
        coilId: Int = Self.unequippedSentinel,
        hookId: Int = Self.unequippedSentinel,
        baitId: Int = Self.unequippedSentinel
    ) {
        self.id = id
        self.fishingRodId = fishingRodId
        self.fishingLineId = fishingLineId
        self.coilId = coilId
        self.hookId = hookId
        self.baitId = baitId
    }
}

public struct UserCouponItem: Sendable, Equatable, Identifiable {
    public let id: Int
    public let coupon: CouponSpec
    public var remainingTimeUnits: Int
    public var date: Int64
    public var md5: String

    public init(id: Int, coupon: CouponSpec, remainingTimeUnits: Int, date: Int64, md5: String) {
        self.id = id
        self.coupon = coupon
        self.remainingTimeUnits = remainingTimeUnits
        self.date = date
        self.md5 = md5
    }
}

public struct FishnetEntryRecord: Sendable, Equatable, Identifiable {
    public let id: Int
    public let caughtFish: CaughtUserFish

    public init(id: Int, caughtFish: CaughtUserFish) {
        self.id = id
        self.caughtFish = caughtFish
    }
}

public struct PersonalSpeciesRecord: Sendable, Equatable, Identifiable {
    public let id: Int
    public let fishName: String
    public var weightGrams: Int
    public var baitId1Based: Int

    public init(id: Int, fishName: String, weightGrams: Int, baitId1Based: Int) {
        self.id = id
        self.fishName = fishName
        self.weightGrams = weightGrams
        self.baitId1Based = baitId1Based
    }
}

public struct AchievementRecord: Sendable, Equatable, Identifiable {
    public let id: Int
    public let imageResId: Int
    public var score: Int
    public var level: Int
    public var nag: Int
    public let nagSize: Int
    public var date: Int64
    public var md5: String

    public init(
        id: Int,
        imageResId: Int,
        score: Int,
        level: Int,
        nag: Int,
        nagSize: Int,
        date: Int64,
        md5: String
    ) {
        self.id = id
        self.imageResId = imageResId
        self.score = score
        self.level = level
        self.nag = nag
        self.nagSize = nagSize
        self.date = date
        self.md5 = md5
    }
}

public struct QuestRecord: Sendable, Equatable, Identifiable {
    public let id: Int
    public let type: Int
    public let fishCsv: String
    public let baitCsv: String
    public let numCsv: String
    public let weightCsv: String
    public let requiredCategory: Int
    public let rewardCsv: String
    public var progressRes: String
    public var made: Int
    public var date: Int64
    public var md5: String

    public init(
        id: Int,
        type: Int,
        fishCsv: String,
        baitCsv: String,
        numCsv: String,
        weightCsv: String,
        requiredCategory: Int,
        rewardCsv: String,
        progressRes: String,
        made: Int,
        date: Int64,
        md5: String
    ) {
        self.id = id
        self.type = type
        self.fishCsv = fishCsv
        self.baitCsv = baitCsv
        self.numCsv = numCsv
        self.weightCsv = weightCsv
        self.requiredCategory = requiredCategory
        self.rewardCsv = rewardCsv
        self.progressRes = progressRes
        self.made = made
        self.date = date
        self.md5 = md5
    }
}

public struct DataSignRecord: Sendable, Equatable, Identifiable {
    public let id: Int
    public var date: Int64
    public var md5: String

    public init(id: Int, date: Int64, md5: String) {
        self.id = id
        self.date = date
        self.md5 = md5
    }
}
