import Foundation

// MARK: - 1. All 7 Java `Serializable` Models & Exact `serialVersionUID`s (`NETWORK.md` Section 6)

/// Value wrapper for polymorphic `Object` fields inside `com.evados.fishing.obj.Mess` and `Request`.
public indirect enum ChatSerializedObject: Sendable, Equatable {
    case request(ChatRequest)
    case initObject(ChatInitObject)
    case userData(ChatServerUserData)
    case userOnlineList([ChatUserOnline])
    case toursList([ChatTourModel])
    case faq(ChatFaqModel)
    case boolValue(Bool)
    case intValue(Int32)
    case stringValue(String)
}

/// 1. `com.evados.fishing.obj.Mess` (`serialVersionUID = 1L`)
public struct ChatMess: Sendable, Equatable, Identifiable {
    public static let javaClassName = "com.evados.fishing.obj.Mess"
    public static let serialVersionUID: Int64 = 1
    public static let systemPeer = "-1"

    // Primitive fields (alphabetical order in Java Object Stream: `fromID`, `prem`, `room`)
    public var fromID: Int32
    public var prem: Int32
    public var room: Int32

    // Object fields (alphabetical order in Java Object Stream: `from`, `object`, `text`, `time`, `to`)
    public var from: String?
    public var object: ChatSerializedObject?
    public var text: String?
    public var timeEpochMs: Int64?
    public var to: String?

    public var id: String {
        "\(fromID)_\(from ?? "")_\(text ?? "")_\(timeEpochMs ?? 0)"
    }

    public init(
        fromID: Int32 = 0,
        prem: Int32 = 0,
        room: Int32 = 0,
        from: String? = nil,
        object: ChatSerializedObject? = nil,
        text: String? = nil,
        timeEpochMs: Int64? = nil,
        to: String? = nil
    ) {
        self.fromID = fromID
        self.prem = prem
        self.room = room
        self.from = from
        self.object = object
        self.text = text
        self.timeEpochMs = timeEpochMs
        self.to = to
    }
}

/// 2. `com.evados.fishing.obj.Request` (`serialVersionUID = -2875567258615516599L`)
public struct ChatRequest: Sendable, Equatable {
    public static let javaClassName = "com.evados.fishing.obj.Request"
    public static let serialVersionUID: Int64 = -2875567258615516599

    // Primitive fields (`id: I`, `status: Z`, `var1: I`, `var2: I`)
    public var id: Int32
    public var status: Bool
    public var var1: Int32
    public var var2: Int32

    // Object fields (`obj: Object`, `string: String`)
    public var obj: ChatSerializedObject?
    public var string: String?

    public init(
        id: Int32 = 0,
        status: Bool = false,
        var1: Int32 = 0,
        var2: Int32 = 0,
        obj: ChatSerializedObject? = nil,
        string: String? = nil
    ) {
        self.id = id
        self.status = status
        self.var1 = var1
        self.var2 = var2
        self.obj = obj
        self.string = string
    }
}

/// 3. `com.evados.fishing.obj.InitObject` (`serialVersionUID = -1824945529069185020L`)
public struct ChatInitObject: Sendable, Equatable {
    public static let javaClassName = "com.evados.fishing.obj.InitObject"
    public static let serialVersionUID: Int64 = -1824945529069185020

    // Object fields (`tours: ArrayList`, `userData: UserData`)
    public var tours: [ChatTourModel]
    public var userData: ChatServerUserData?

    public init(tours: [ChatTourModel] = [], userData: ChatServerUserData? = nil) {
        self.tours = tours
        self.userData = userData
    }
}

/// 4. `com.evados.fishing.obj.UserData` (`serialVersionUID = 1L`)
public struct ChatServerUserData: Sendable, Equatable {
    public static let javaClassName = "com.evados.fishing.obj.UserData"
    public static let serialVersionUID: Int64 = 1

    // 10 primitive `int` fields in alphabetical order
    public var bcap: Int32
    public var curLevelXP: Int32
    public var fbcap: Int32
    public var lv: Int32
    public var mbcap: Int32
    public var money: Int32
    public var prem: Int32
    public var rmoney: Int32
    public var toNextlv: Int32
    public var xp: Int32

    public init(
        bcap: Int32 = 0,
        curLevelXP: Int32 = 0,
        fbcap: Int32 = 0,
        lv: Int32 = 0,
        mbcap: Int32 = 0,
        money: Int32 = 0,
        prem: Int32 = 0,
        rmoney: Int32 = 0,
        toNextlv: Int32 = 0,
        xp: Int32 = 0
    ) {
        self.bcap = bcap
        self.curLevelXP = curLevelXP
        self.fbcap = fbcap
        self.lv = lv
        self.mbcap = mbcap
        self.money = money
        self.prem = prem
        self.rmoney = rmoney
        self.toNextlv = toNextlv
        self.xp = xp
    }
}

/// 5. `com.evados.fishing.obj.UserOnline` (`serialVersionUID = -4036788353175013539L`)
public struct ChatUserOnline: Sendable, Equatable, Identifiable {
    public static let javaClassName = "com.evados.fishing.obj.UserOnline"
    public static let serialVersionUID: Int64 = -4036788353175013539

    // Primitive fields (`ban: Z`, `frig: I`, `id: I`, `lv: I`, `online: Z`, `pond: I`, `premium: I`, `rate: I`, `role: I`, `xp: I`)
    public var ban: Bool
    public var frig: Int32
    public var id: Int32
    public var lv: Int32
    public var online: Bool
    public var pond: Int32
    public var premium: Int32
    public var rate: Int32
    public var role: Int32
    public var xp: Int32

    // Object fields (`login: String`, `team: String`)
    public var login: String
    public var team: String

    public init(
        ban: Bool = false,
        frig: Int32 = 0,
        id: Int32,
        lv: Int32 = 0,
        online: Bool = true,
        pond: Int32 = 0,
        premium: Int32 = 0,
        rate: Int32 = 0,
        role: Int32 = 0,
        xp: Int32 = 0,
        login: String,
        team: String = "Нет"
    ) {
        self.ban = ban
        self.frig = frig
        self.id = id
        self.lv = lv
        self.online = online
        self.pond = pond
        self.premium = premium
        self.rate = rate
        self.role = role
        self.xp = xp
        self.login = login
        self.team = team
    }
}

/// 6. `com.evados.fishing.chat.models.Tours` (`serialVersionUID = 4477032905427767288L`)
public struct ChatTourModel: Sendable, Equatable, Identifiable {
    public static let javaClassName = "com.evados.fishing.chat.models.Tours"
    public static let serialVersionUID: Int64 = 4477032905427767288

    // Primitive fields (14 fields in alphabetical order)
    public var active: Int32
    public var bait: Int32
    public var cond: Float
    public var fee: Int32
    public var feed: Bool
    public var finish: Int64
    public var fish: Int32
    public var id: Int32
    public var leftToFinish: Int64
    public var leftToStart: Int64
    public var pond: Int32
    public var reg: Bool
    public var start: Int64
    public var vip: Bool

    // Object fields (`desc`, `fond`, `title`, `type`, `users`)
    public var desc: String
    public var fond: String
    public var title: String
    public var type: String
    public var users: [String]

    public init(
        active: Int32 = 0,
        bait: Int32 = 0,
        cond: Float = 0,
        fee: Int32 = 0,
        feed: Bool = false,
        finish: Int64 = 0,
        fish: Int32 = 0,
        id: Int32,
        leftToFinish: Int64 = 0,
        leftToStart: Int64 = 0,
        pond: Int32 = 0,
        reg: Bool = false,
        start: Int64 = 0,
        vip: Bool = false,
        desc: String = "",
        fond: String = "",
        title: String = "",
        type: String = "",
        users: [String] = []
    ) {
        self.active = active
        self.bait = bait
        self.cond = cond
        self.fee = fee
        self.feed = feed
        self.finish = finish
        self.fish = fish
        self.id = id
        self.leftToFinish = leftToFinish
        self.leftToStart = leftToStart
        self.pond = pond
        self.reg = reg
        self.start = start
        self.vip = vip
        self.desc = desc
        self.fond = fond
        self.title = title
        self.type = type
        self.users = users
    }
}

/// 7. `com.evados.fishing.chat.models.Faq` (`serialVersionUID = 6479371882847742292L`)
public struct ChatFaqModel: Sendable, Equatable, Identifiable {
    public static let javaClassName = "com.evados.fishing.chat.models.Faq"
    public static let serialVersionUID: Int64 = 6479371882847742292

    public var id: Int32
    public var text: String
    public var title: String

    public init(id: Int32, text: String, title: String) {
        self.id = id
        self.text = text
        self.title = title
    }
}

// MARK: - 2. Binary Java Object Serialization Stream (`0xACED0005`) Encoder & Decoder

public enum JavaObjectStreamError: Error, Sendable, Equatable {
    case invalidStreamHeader(magic: UInt16, version: UInt16)
    case unexpectedEOF
    case unexpectedTypeCode(UInt8)
    case unsupportedClass(name: String, serialVersionUID: Int64)
}

/// Implements the binary Java Object Serialization Stream Protocol (`STREAM_MAGIC = 0xACED`, `STREAM_VERSION = 0x0005`)
/// for `ObjectOutputStream.writeUnshared(Mess)` and `ObjectInputStream.readUnshared()` on `chat.fish-mob.ru:15701`.
public enum JavaObjectStreamCodec: Sendable {
    public static let streamMagic: UInt16 = 0xACED
    public static let streamVersion: UInt16 = 0x0005

    public static let tcNull: UInt8 = 0x70
    public static let tcReference: UInt8 = 0x71
    public static let tcClassDesc: UInt8 = 0x72
    public static let tcObject: UInt8 = 0x73
    public static let tcString: UInt8 = 0x74
    public static let tcBlockData: UInt8 = 0x77
    public static let tcEndBlockData: UInt8 = 0x78

    public static let scSerializable: UInt8 = 0x02
    public static let scWriteMethod: UInt8 = 0x03

    public static let arrayListClassName = "java.util.ArrayList"
    public static let arrayListSerialVersionUID: Int64 = 8683452581122892189

    public static let dateClassName = "java.util.Date"
    public static let dateSerialVersionUID: Int64 = 7523967970034938905

    public static let booleanClassName = "java.lang.Boolean"
    public static let booleanSerialVersionUID: Int64 = -3665804199014368530

    public static let integerClassName = "java.lang.Integer"
    public static let integerSerialVersionUID: Int64 = 1360826667806852920

    // MARK: - Encoding (`writeUnshared`)

    public static func encodeMess(_ mess: ChatMess, includeStreamHeader: Bool = true) -> Data {
        var writer = BinaryWriter()
        if includeStreamHeader {
            writer.writeUInt16(streamMagic)
            writer.writeUInt16(streamVersion)
        }
        writeMessObject(&writer, mess)
        return writer.data
    }

    private static func writeMessObject(_ w: inout BinaryWriter, _ mess: ChatMess) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: ChatMess.javaClassName,
            uid: ChatMess.serialVersionUID,
            flags: scSerializable,
            fields: [
                ("I", "fromID", nil),
                ("I", "prem", nil),
                ("I", "room", nil),
                ("L", "from", "Ljava/lang/String;"),
                ("L", "object", "Ljava/lang/Object;"),
                ("L", "text", "Ljava/lang/String;"),
                ("L", "time", "Ljava/util/Date;"),
                ("L", "to", "Ljava/lang/String;")
            ]
        )
        // Primitive values
        w.writeInt32(mess.fromID)
        w.writeInt32(mess.prem)
        w.writeInt32(mess.room)
        // Object values
        writeOptionalString(&w, mess.from)
        writeOptionalSerializedObject(&w, mess.object)
        writeOptionalString(&w, mess.text)
        writeOptionalDate(&w, mess.timeEpochMs)
        writeOptionalString(&w, mess.to)
    }

    private static func writeOptionalSerializedObject(_ w: inout BinaryWriter, _ obj: ChatSerializedObject?) {
        guard let obj else {
            w.writeUInt8(tcNull)
            return
        }
        switch obj {
        case .request(let req):
            writeRequestObject(&w, req)
        case .initObject(let initObj):
            writeInitObject(&w, initObj)
        case .userData(let ud):
            writeUserDataObject(&w, ud)
        case .userOnlineList(let users):
            writeArrayListHeader(&w, count: users.count)
            for u in users { writeUserOnlineObject(&w, u) }
            w.writeUInt8(tcEndBlockData)
        case .toursList(let tours):
            writeArrayListHeader(&w, count: tours.count)
            for t in tours { writeTourObject(&w, t) }
            w.writeUInt8(tcEndBlockData)
        case .faq(let faq):
            writeFaqObject(&w, faq)
        case .boolValue(let flag):
            w.writeUInt8(tcObject)
            writeClassDesc(
                &w,
                name: booleanClassName,
                uid: booleanSerialVersionUID,
                flags: scSerializable,
                fields: [("Z", "value", nil)]
            )
            w.writeBool(flag)
        case .intValue(let val):
            w.writeUInt8(tcObject)
            writeClassDesc(
                &w,
                name: integerClassName,
                uid: integerSerialVersionUID,
                flags: scSerializable,
                fields: [("I", "value", nil)]
            )
            w.writeInt32(val)
        case .stringValue(let str):
            writeOptionalString(&w, str)
        }
    }

    private static func writeRequestObject(_ w: inout BinaryWriter, _ req: ChatRequest) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: ChatRequest.javaClassName,
            uid: ChatRequest.serialVersionUID,
            flags: scSerializable,
            fields: [
                ("I", "id", nil),
                ("Z", "status", nil),
                ("I", "var1", nil),
                ("I", "var2", nil),
                ("L", "obj", "Ljava/lang/Object;"),
                ("L", "string", "Ljava/lang/String;")
            ]
        )
        w.writeInt32(req.id)
        w.writeBool(req.status)
        w.writeInt32(req.var1)
        w.writeInt32(req.var2)
        writeOptionalSerializedObject(&w, req.obj)
        writeOptionalString(&w, req.string)
    }

    private static func writeInitObject(_ w: inout BinaryWriter, _ initObj: ChatInitObject) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: ChatInitObject.javaClassName,
            uid: ChatInitObject.serialVersionUID,
            flags: scSerializable,
            fields: [
                ("L", "tours", "Ljava/util/ArrayList;"),
                ("L", "userData", "Lcom/evados/fishing/obj/UserData;")
            ]
        )
        writeArrayListHeader(&w, count: initObj.tours.count)
        for t in initObj.tours { writeTourObject(&w, t) }
        w.writeUInt8(tcEndBlockData)

        if let ud = initObj.userData {
            writeUserDataObject(&w, ud)
        } else {
            w.writeUInt8(tcNull)
        }
    }

    private static func writeUserDataObject(_ w: inout BinaryWriter, _ ud: ChatServerUserData) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: ChatServerUserData.javaClassName,
            uid: ChatServerUserData.serialVersionUID,
            flags: scSerializable,
            fields: [
                ("I", "bcap", nil),
                ("I", "curLevelXP", nil),
                ("I", "fbcap", nil),
                ("I", "lv", nil),
                ("I", "mbcap", nil),
                ("I", "money", nil),
                ("I", "prem", nil),
                ("I", "rmoney", nil),
                ("I", "toNextlv", nil),
                ("I", "xp", nil)
            ]
        )
        w.writeInt32(ud.bcap)
        w.writeInt32(ud.curLevelXP)
        w.writeInt32(ud.fbcap)
        w.writeInt32(ud.lv)
        w.writeInt32(ud.mbcap)
        w.writeInt32(ud.money)
        w.writeInt32(ud.prem)
        w.writeInt32(ud.rmoney)
        w.writeInt32(ud.toNextlv)
        w.writeInt32(ud.xp)
    }

    private static func writeUserOnlineObject(_ w: inout BinaryWriter, _ u: ChatUserOnline) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: ChatUserOnline.javaClassName,
            uid: ChatUserOnline.serialVersionUID,
            flags: scSerializable,
            fields: [
                ("Z", "ban", nil),
                ("I", "frig", nil),
                ("I", "id", nil),
                ("I", "lv", nil),
                ("Z", "online", nil),
                ("I", "pond", nil),
                ("I", "premium", nil),
                ("I", "rate", nil),
                ("I", "role", nil),
                ("I", "xp", nil),
                ("L", "login", "Ljava/lang/String;"),
                ("L", "team", "Ljava/lang/String;")
            ]
        )
        w.writeBool(u.ban)
        w.writeInt32(u.frig)
        w.writeInt32(u.id)
        w.writeInt32(u.lv)
        w.writeBool(u.online)
        w.writeInt32(u.pond)
        w.writeInt32(u.premium)
        w.writeInt32(u.rate)
        w.writeInt32(u.role)
        w.writeInt32(u.xp)
        writeOptionalString(&w, u.login)
        writeOptionalString(&w, u.team)
    }

    private static func writeTourObject(_ w: inout BinaryWriter, _ t: ChatTourModel) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: ChatTourModel.javaClassName,
            uid: ChatTourModel.serialVersionUID,
            flags: scSerializable,
            fields: [
                ("I", "active", nil),
                ("I", "bait", nil),
                ("F", "cond", nil),
                ("I", "fee", nil),
                ("Z", "feed", nil),
                ("J", "finish", nil),
                ("I", "fish", nil),
                ("I", "id", nil),
                ("J", "leftToFinish", nil),
                ("J", "leftToStart", nil),
                ("I", "pond", nil),
                ("Z", "reg", nil),
                ("J", "start", nil),
                ("Z", "vip", nil),
                ("L", "desc", "Ljava/lang/String;"),
                ("L", "fond", "Ljava/lang/String;"),
                ("L", "title", "Ljava/lang/String;"),
                ("L", "type", "Ljava/lang/String;"),
                ("L", "users", "Ljava/util/ArrayList;")
            ]
        )
        w.writeInt32(t.active)
        w.writeInt32(t.bait)
        w.writeFloat(t.cond)
        w.writeInt32(t.fee)
        w.writeBool(t.feed)
        w.writeInt64(t.finish)
        w.writeInt32(t.fish)
        w.writeInt32(t.id)
        w.writeInt64(t.leftToFinish)
        w.writeInt64(t.leftToStart)
        w.writeInt32(t.pond)
        w.writeBool(t.reg)
        w.writeInt64(t.start)
        w.writeBool(t.vip)
        writeOptionalString(&w, t.desc)
        writeOptionalString(&w, t.fond)
        writeOptionalString(&w, t.title)
        writeOptionalString(&w, t.type)
        writeArrayListHeader(&w, count: t.users.count)
        for u in t.users { writeOptionalString(&w, u) }
        w.writeUInt8(tcEndBlockData)
    }

    private static func writeFaqObject(_ w: inout BinaryWriter, _ faq: ChatFaqModel) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: ChatFaqModel.javaClassName,
            uid: ChatFaqModel.serialVersionUID,
            flags: scSerializable,
            fields: [
                ("I", "id", nil),
                ("L", "text", "Ljava/lang/String;"),
                ("L", "title", "Ljava/lang/String;")
            ]
        )
        w.writeInt32(faq.id)
        writeOptionalString(&w, faq.text)
        writeOptionalString(&w, faq.title)
    }

    private static func writeArrayListHeader(_ w: inout BinaryWriter, count: Int) {
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: arrayListClassName,
            uid: arrayListSerialVersionUID,
            flags: scWriteMethod,
            fields: [("I", "size", nil)]
        )
        w.writeInt32(Int32(count))
        // `ArrayList.writeObject` writes a 4-byte capacity block data before the elements
        w.writeUInt8(tcBlockData)
        w.writeUInt8(4)
        w.writeInt32(Int32(count))
    }

    private static func writeOptionalDate(_ w: inout BinaryWriter, _ epochMs: Int64?) {
        guard let ms = epochMs else {
            w.writeUInt8(tcNull)
            return
        }
        w.writeUInt8(tcObject)
        writeClassDesc(
            &w,
            name: dateClassName,
            uid: dateSerialVersionUID,
            flags: scWriteMethod,
            fields: []
        )
        w.writeUInt8(tcBlockData)
        w.writeUInt8(8)
        w.writeInt64(ms)
        w.writeUInt8(tcEndBlockData)
    }

    private static func writeOptionalString(_ w: inout BinaryWriter, _ str: String?) {
        guard let str else {
            w.writeUInt8(tcNull)
            return
        }
        w.writeUInt8(tcString)
        w.writeUTF(str)
    }

    private static func writeClassDesc(
        _ w: inout BinaryWriter,
        name: String,
        uid: Int64,
        flags: UInt8,
        fields: [(typeCode: String, name: String, className: String?)]
    ) {
        w.writeUInt8(tcClassDesc)
        w.writeUTF(name)
        w.writeInt64(uid)
        w.writeUInt8(flags)
        w.writeUInt16(UInt16(fields.count))
        for f in fields {
            w.writeUInt8(UInt8(f.typeCode.utf8.first!))
            w.writeUTF(f.name)
            if let cls = f.className {
                w.writeUInt8(tcString)
                w.writeUTF(cls)
            }
        }
        w.writeUInt8(tcEndBlockData)
        w.writeUInt8(tcNull) // No superclass descriptor
    }

    // MARK: - Decoding (`readUnshared`)

    public static func decodeMess(from data: Data, hasStreamHeader: Bool = true) throws -> ChatMess {
        var reader = BinaryReader(data: data)
        if hasStreamHeader {
            let magic = try reader.readUInt16()
            let version = try reader.readUInt16()
            guard magic == streamMagic && version == streamVersion else {
                throw JavaObjectStreamError.invalidStreamHeader(magic: magic, version: version)
            }
        }
        guard let obj = try readAnyObject(&reader),
              case .mess(let mess) = obj else {
            throw JavaObjectStreamError.unexpectedTypeCode(0)
        }
        return mess
    }

    private enum InternalDecoded {
        case mess(ChatMess)
        case serialized(ChatSerializedObject)
        case date(Int64)
    }

    private static func readAnyObject(_ r: inout BinaryReader) throws -> InternalDecoded? {
        let tc = try r.readUInt8()
        if tc == tcNull {
            return nil
        }
        if tc == tcString {
            let s = try r.readUTF()
            return .serialized(.stringValue(s))
        }
        guard tc == tcObject else {
            throw JavaObjectStreamError.unexpectedTypeCode(tc)
        }

        let (className, uid) = try readClassDesc(&r)
        switch (className, uid) {
        case (ChatMess.javaClassName, ChatMess.serialVersionUID):
            let fromID = try r.readInt32()
            let prem = try r.readInt32()
            let room = try r.readInt32()
            let from = try readOptionalString(&r)
            let obj = try readOptionalSerialized(&r)
            let text = try readOptionalString(&r)
            let timeMs = try readOptionalDate(&r)
            let to = try readOptionalString(&r)
            return .mess(ChatMess(
                fromID: fromID,
                prem: prem,
                room: room,
                from: from,
                object: obj,
                text: text,
                timeEpochMs: timeMs,
                to: to
            ))

        case (ChatRequest.javaClassName, ChatRequest.serialVersionUID):
            let id = try r.readInt32()
            let status = try r.readBool()
            let var1 = try r.readInt32()
            let var2 = try r.readInt32()
            let obj = try readOptionalSerialized(&r)
            let str = try readOptionalString(&r)
            return .serialized(.request(ChatRequest(
                id: id,
                status: status,
                var1: var1,
                var2: var2,
                obj: obj,
                string: str
            )))

        case (ChatInitObject.javaClassName, ChatInitObject.serialVersionUID):
            let tours = try readToursArrayList(&r)
            let udOpt = try readOptionalSerialized(&r)
            let ud: ChatServerUserData?
            if case .userData(let u) = udOpt { ud = u } else { ud = nil }
            return .serialized(.initObject(ChatInitObject(tours: tours, userData: ud)))

        case (ChatServerUserData.javaClassName, ChatServerUserData.serialVersionUID):
            let bcap = try r.readInt32()
            let curLevelXP = try r.readInt32()
            let fbcap = try r.readInt32()
            let lv = try r.readInt32()
            let mbcap = try r.readInt32()
            let money = try r.readInt32()
            let prem = try r.readInt32()
            let rmoney = try r.readInt32()
            let toNextlv = try r.readInt32()
            let xp = try r.readInt32()
            return .serialized(.userData(ChatServerUserData(
                bcap: bcap,
                curLevelXP: curLevelXP,
                fbcap: fbcap,
                lv: lv,
                mbcap: mbcap,
                money: money,
                prem: prem,
                rmoney: rmoney,
                toNextlv: toNextlv,
                xp: xp
            )))

        case (ChatUserOnline.javaClassName, ChatUserOnline.serialVersionUID):
            let ban = try r.readBool()
            let frig = try r.readInt32()
            let id = try r.readInt32()
            let lv = try r.readInt32()
            let online = try r.readBool()
            let pond = try r.readInt32()
            let premium = try r.readInt32()
            let rate = try r.readInt32()
            let role = try r.readInt32()
            let xp = try r.readInt32()
            let login = try readOptionalString(&r) ?? ""
            let team = try readOptionalString(&r) ?? "Нет"
            return .serialized(.userOnlineList([ChatUserOnline(
                ban: ban, frig: frig, id: id, lv: lv, online: online,
                pond: pond, premium: premium, rate: rate, role: role, xp: xp,
                login: login, team: team
            )]))

        case (ChatTourModel.javaClassName, ChatTourModel.serialVersionUID):
            let tour = try readTourFields(&r)
            return .serialized(.toursList([tour]))

        case (ChatFaqModel.javaClassName, ChatFaqModel.serialVersionUID):
            let id = try r.readInt32()
            let text = try readOptionalString(&r) ?? ""
            let title = try readOptionalString(&r) ?? ""
            return .serialized(.faq(ChatFaqModel(id: id, text: text, title: title)))

        case (booleanClassName, booleanSerialVersionUID):
            return .serialized(.boolValue(try r.readBool()))

        case (integerClassName, integerSerialVersionUID):
            return .serialized(.intValue(try r.readInt32()))

        case (dateClassName, dateSerialVersionUID):
            let blk = try r.readUInt8()
            guard blk == tcBlockData else { throw JavaObjectStreamError.unexpectedTypeCode(blk) }
            let len = try r.readUInt8()
            guard len == 8 else { throw JavaObjectStreamError.unexpectedTypeCode(len) }
            let ms = try r.readInt64()
            let end = try r.readUInt8()
            guard end == tcEndBlockData else { throw JavaObjectStreamError.unexpectedTypeCode(end) }
            return .date(ms)

        case (arrayListClassName, arrayListSerialVersionUID):
            let count = Int(try r.readInt32())
            let blk = try r.readUInt8()
            guard blk == tcBlockData else { throw JavaObjectStreamError.unexpectedTypeCode(blk) }
            let blkLen = Int(try r.readUInt8())
            try r.skip(blkLen)

            var users: [ChatUserOnline] = []
            var tours: [ChatTourModel] = []
            for _ in 0..<max(0, count) {
                if let elem = try readAnyObject(&r) {
                    if case .serialized(.userOnlineList(let u)) = elem {
                        users.append(contentsOf: u)
                    } else if case .serialized(.toursList(let t)) = elem {
                        tours.append(contentsOf: t)
                    }
                }
            }
            let end = try r.readUInt8()
            guard end == tcEndBlockData else { throw JavaObjectStreamError.unexpectedTypeCode(end) }
            if !tours.isEmpty {
                return .serialized(.toursList(tours))
            }
            return .serialized(.userOnlineList(users))

        default:
            throw JavaObjectStreamError.unsupportedClass(name: className, serialVersionUID: uid)
        }
    }

    private static func readTourFields(_ r: inout BinaryReader) throws -> ChatTourModel {
        let active = try r.readInt32()
        let bait = try r.readInt32()
        let cond = try r.readFloat()
        let fee = try r.readInt32()
        let feed = try r.readBool()
        let finish = try r.readInt64()
        let fish = try r.readInt32()
        let id = try r.readInt32()
        let leftToFinish = try r.readInt64()
        let leftToStart = try r.readInt64()
        let pond = try r.readInt32()
        let reg = try r.readBool()
        let start = try r.readInt64()
        let vip = try r.readBool()
        let desc = try readOptionalString(&r) ?? ""
        let fond = try readOptionalString(&r) ?? ""
        let title = try readOptionalString(&r) ?? ""
        let type = try readOptionalString(&r) ?? ""
        let users = try readStringArrayList(&r)
        return ChatTourModel(
            active: active, bait: bait, cond: cond, fee: fee, feed: feed,
            finish: finish, fish: fish, id: id, leftToFinish: leftToFinish,
            leftToStart: leftToStart, pond: pond, reg: reg, start: start,
            vip: vip, desc: desc, fond: fond, title: title, type: type, users: users
        )
    }

    private static func readToursArrayList(_ r: inout BinaryReader) throws -> [ChatTourModel] {
        guard let decoded = try readAnyObject(&r) else { return [] }
        if case .serialized(.toursList(let list)) = decoded {
            return list
        }
        return []
    }

    private static func readStringArrayList(_ r: inout BinaryReader) throws -> [String] {
        let tc = try r.readUInt8()
        if tc == tcNull { return [] }
        guard tc == tcObject else { throw JavaObjectStreamError.unexpectedTypeCode(tc) }
        let (cls, _) = try readClassDesc(&r)
        guard cls == arrayListClassName else {
            throw JavaObjectStreamError.unsupportedClass(name: cls, serialVersionUID: 0)
        }
        let count = Int(try r.readInt32())
        let blk = try r.readUInt8()
        guard blk == tcBlockData else { throw JavaObjectStreamError.unexpectedTypeCode(blk) }
        let blkLen = Int(try r.readUInt8())
        try r.skip(blkLen)
        var result: [String] = []
        for _ in 0..<max(0, count) {
            if let s = try readOptionalString(&r) {
                result.append(s)
            }
        }
        let end = try r.readUInt8()
        guard end == tcEndBlockData else { throw JavaObjectStreamError.unexpectedTypeCode(end) }
        return result
    }

    private static func readOptionalString(_ r: inout BinaryReader) throws -> String? {
        let tc = try r.readUInt8()
        if tc == tcNull { return nil }
        guard tc == tcString else { throw JavaObjectStreamError.unexpectedTypeCode(tc) }
        return try r.readUTF()
    }

    private static func readOptionalSerialized(_ r: inout BinaryReader) throws -> ChatSerializedObject? {
        guard let decoded = try readAnyObject(&r) else { return nil }
        if case .serialized(let s) = decoded { return s }
        return nil
    }

    private static func readOptionalDate(_ r: inout BinaryReader) throws -> Int64? {
        guard let decoded = try readAnyObject(&r) else { return nil }
        if case .date(let ms) = decoded { return ms }
        return nil
    }

    private static func readClassDesc(_ r: inout BinaryReader) throws -> (String, Int64) {
        let tc = try r.readUInt8()
        guard tc == tcClassDesc else { throw JavaObjectStreamError.unexpectedTypeCode(tc) }
        let name = try r.readUTF()
        let uid = try r.readInt64()
        let _ = try r.readUInt8() // flags
        let fieldCount = Int(try r.readUInt16())
        for _ in 0..<fieldCount {
            let typeByte = try r.readUInt8()
            _ = try r.readUTF() // field name
            if typeByte == UInt8(ascii: "L") || typeByte == UInt8(ascii: "[") {
                let fTc = try r.readUInt8()
                if fTc == tcString {
                    _ = try r.readUTF()
                } else if fTc == tcReference {
                    try r.skip(4)
                }
            }
        }
        let endAnnot = try r.readUInt8()
        guard endAnnot == tcEndBlockData else { throw JavaObjectStreamError.unexpectedTypeCode(endAnnot) }
        let superTc = try r.readUInt8()
        if superTc == tcClassDesc {
            _ = try readClassDesc(&r)
        }
        return (name, uid)
    }
}

// MARK: - 3. Chat & Tournament Protocol Dispatcher (`Handler.selector` & `Chat$ULTask`, `NETWORK.md` Section 5.2 & 7.1)

public struct PartitionedOnlineUsers: Sendable, Equatable {
    /// Players on the current pond (`pond == currentPond && online == true`).
    public let userPond: [ChatUserOnline]
    /// Friends (`frig == 1`).
    public let userFriends: [ChatUserOnline]
    /// Ignored players (`frig == 2`).
    public let userIgnore: [ChatUserOnline]
}

public enum ChatSelectorOutcome: Sendable, Equatable {
    case sendHeartbeatReply(ChatMess)
    case sendInitializeRequest(ChatMess)
    case serverRequestedRestart
    case initialized(ChatInitObject)
    case userListReceived(all: [ChatUserOnline], partitioned: PartitionedOnlineUsers)
    case friendOrIgnoreUpdated(Bool)
    case serverUserDataUpdated(ChatServerUserData)
    case transactionCompleted(status: Bool, updatedInit: ChatInitObject?)
    case toursUpdated([ChatTourModel])
    case chatMessageReceived(ChatMess)
    /// Preserves the confirmed original bug in `Handler.selector(Mess)` (`NETWORK.md` Section 7.1 #1):
    /// `"sellFish"` has no `case` in `Handler.selector`, leaving `sell_call.wait(60000)` to time out!
    case unhandledSystemCommand(String)
}

public enum ChatProtocolSelector: Sendable {
    /// Builds a simple system command `Mess` (`Client.simpleMess(String)`).
    public static func makeSystemMess(
        command: String,
        userId: Int32,
        login: String,
        pondRoom: Int32,
        object: ChatSerializedObject? = nil
    ) -> ChatMess {
        ChatMess(
            fromID: userId,
            prem: 0,
            room: pondRoom,
            from: login,
            object: object,
            text: command,
            timeEpochMs: nil,
            to: ChatMess.systemPeer
        )
    }

    /// Builds the initial `"open"` handshake message sent immediately after opening `ObjectInputStream` (`Client.open()`).
    public static func makeOpenHandshakeMess(
        userId: Int32,
        login: String,
        pondRoom: Int32,
        installationUuid: String
    ) -> ChatMess {
        let uuidMd5 = FishingNetworkCrypto.installationUuidMd5(installationUuid)
        return makeSystemMess(
            command: "open",
            userId: userId,
            login: login,
            pondRoom: pondRoom,
            object: .request(ChatRequest(string: uuidMd5))
        )
    }

    /// Partitions online users into the 3 tabs of `Chat$ULTask` (`userPond`, `userFriends`, `userIgnore`).
    public static func partitionUserList(_ users: [ChatUserOnline], currentPond: Int32) -> PartitionedOnlineUsers {
        let pondUsers = users.filter { $0.pond == currentPond && $0.online }
        let friends = users.filter { $0.frig == 1 }
        let ignored = users.filter { $0.frig == 2 }
        return PartitionedOnlineUsers(userPond: pondUsers, userFriends: friends, userIgnore: ignored)
    }

    /// Dispatches an incoming `Mess` from `chat.fish-mob.ru:15701` (`Handler.selector(Mess)`, `pc=0035..017f`).
    public static func handleIncomingMess(
        _ mess: ChatMess,
        currentUserId: Int32,
        currentLogin: String,
        currentPond: Int32
    ) -> ChatSelectorOutcome {
        guard mess.from == ChatMess.systemPeer else {
            return .chatMessageReceived(mess)
        }

        let cmd = mess.text ?? ""
        switch cmd {
        case "bit":
            let reply = makeSystemMess(
                command: "bit",
                userId: currentUserId,
                login: currentLogin,
                pondRoom: currentPond
            )
            return .sendHeartbeatReply(reply)

        case "force_init":
            let req = makeSystemMess(
                command: "initialize",
                userId: currentUserId,
                login: currentLogin,
                pondRoom: currentPond
            )
            return .sendInitializeRequest(req)

        case "restart":
            return .serverRequestedRestart

        case "initialize":
            if case .initObject(let initObj) = mess.object {
                return .initialized(initObj)
            }
            return .unhandledSystemCommand(cmd)

        case "getUserList3":
            if case .userOnlineList(let users) = mess.object {
                return .userListReceived(
                    all: users,
                    partitioned: partitionUserList(users, currentPond: currentPond)
                )
            }
            return .unhandledSystemCommand(cmd)

        case "toFriendsOrIgnore":
            if case .boolValue(let ok) = mess.object {
                return .friendOrIgnoreUpdated(ok)
            }
            return .unhandledSystemCommand(cmd)

        case "import value":
            if case .userData(let ud) = mess.object {
                return .serverUserDataUpdated(ud)
            }
            return .unhandledSystemCommand(cmd)

        case "transaction":
            if case .request(let req) = mess.object {
                let updatedInit: ChatInitObject?
                if req.status, case .initObject(let io) = req.obj {
                    updatedInit = io
                } else {
                    updatedInit = nil
                }
                return .transactionCompleted(status: req.status, updatedInit: updatedInit)
            }
            return .unhandledSystemCommand(cmd)

        case "tours":
            if case .toursList(let tours) = mess.object {
                return .toursUpdated(tours)
            }
            return .unhandledSystemCommand(cmd)

        default:
            // Note: `"sellFish"` falls into `default` because `Handler.selector` in `classes.dex`
            // has no `case "sellFish":` branch (`NETWORK.md` Section 7.1 #1).
            return .unhandledSystemCommand(cmd)
        }
    }
}

// MARK: - Internal Big-Endian Binary Reader & Writer

private struct BinaryWriter {
    var data = Data()

    mutating func writeUInt8(_ v: UInt8) { data.append(v) }
    mutating func writeBool(_ v: Bool) { data.append(v ? 1 : 0) }

    mutating func writeUInt16(_ v: UInt16) {
        var be = v.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    mutating func writeInt32(_ v: Int32) {
        var be = v.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    mutating func writeInt64(_ v: Int64) {
        var be = v.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    mutating func writeFloat(_ v: Float) {
        var be = v.bitPattern.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    mutating func writeUTF(_ str: String) {
        let bytes = Array(str.utf8)
        writeUInt16(UInt16(bytes.count))
        data.append(contentsOf: bytes)
    }
}

private struct BinaryReader {
    let bytes: [UInt8]
    var offset: Int = 0

    init(data: Data) {
        self.bytes = Array(data)
    }

    mutating func skip(_ count: Int) throws {
        guard offset + count <= bytes.count else { throw JavaObjectStreamError.unexpectedEOF }
        offset += count
    }

    mutating func readUInt8() throws -> UInt8 {
        guard offset < bytes.count else { throw JavaObjectStreamError.unexpectedEOF }
        defer { offset += 1 }
        return bytes[offset]
    }

    mutating func readBool() throws -> Bool {
        try readUInt8() != 0
    }

    mutating func readUInt16() throws -> UInt16 {
        guard offset + 2 <= bytes.count else { throw JavaObjectStreamError.unexpectedEOF }
        let v = (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
        offset += 2
        return v
    }

    mutating func readInt32() throws -> Int32 {
        guard offset + 4 <= bytes.count else { throw JavaObjectStreamError.unexpectedEOF }
        let u = (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
        offset += 4
        return Int32(bitPattern: u)
    }

    mutating func readInt64() throws -> Int64 {
        guard offset + 8 <= bytes.count else { throw JavaObjectStreamError.unexpectedEOF }
        var u: UInt64 = 0
        for i in 0..<8 {
            u = (u << 8) | UInt64(bytes[offset + i])
        }
        offset += 8
        return Int64(bitPattern: u)
    }

    mutating func readFloat() throws -> Float {
        let bits = UInt32(bitPattern: try readInt32())
        return Float(bitPattern: bits)
    }

    mutating func readUTF() throws -> String {
        let len = Int(try readUInt16())
        guard offset + len <= bytes.count else { throw JavaObjectStreamError.unexpectedEOF }
        let slice = bytes[offset..<(offset + len)]
        offset += len
        return String(decoding: slice, as: UTF8.self)
    }
}