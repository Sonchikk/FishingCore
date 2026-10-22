import Foundation
import SQLite3

public enum SQLiteError: Error, Sendable, Equatable, CustomStringConvertible {
    case openFailed(message: String, code: Int32)
    case prepareFailed(sql: String, message: String, code: Int32)
    case stepFailed(sql: String, message: String, code: Int32)
    case bindFailed(index: Int32, message: String, code: Int32)
    case executeFailed(sql: String, message: String, code: Int32)
    case transactionFailed(message: String)
    case invalidData(String)

    public var description: String {
        switch self {
        case let .openFailed(msg, code):
            return "SQLite open failed (\(code)): \(msg)"
        case let .prepareFailed(sql, msg, code):
            return "SQLite prepare failed (\(code)) for [\(sql)]: \(msg)"
        case let .stepFailed(sql, msg, code):
            return "SQLite step failed (\(code)) for [\(sql)]: \(msg)"
        case let .bindFailed(idx, msg, code):
            return "SQLite bind failed at index \(idx) (\(code)): \(msg)"
        case let .executeFailed(sql, msg, code):
            return "SQLite exec failed (\(code)) for [\(sql)]: \(msg)"
        case let .transactionFailed(msg):
            return "SQLite transaction failed: \(msg)"
        case let .invalidData(msg):
            return "SQLite invalid data: \(msg)"
        }
    }
}

public enum SQLiteValue: Sendable, Equatable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null

    public var intValue: Int? {
        if case let .integer(v) = self { return Int(v) }
        return nil
    }

    public var int64Value: Int64? {
        if case let .integer(v) = self { return v }
        return nil
    }

    public var doubleValue: Double? {
        switch self {
        case let .real(d): return d
        case let .integer(i): return Double(i)
        default: return nil
        }
    }

    public var stringValue: String? {
        if case let .text(s) = self { return s }
        return nil
    }
}

public struct SQLiteRow: Sendable, Equatable {
    public let columns: [String: SQLiteValue]

    public init(columns: [String: SQLiteValue]) {
        self.columns = columns
    }

    public func int(_ column: String) -> Int {
        columns[column]?.intValue ?? 0
    }

    public func optionalInt(_ column: String) -> Int? {
        columns[column]?.intValue
    }

    public func int64(_ column: String) -> Int64 {
        columns[column]?.int64Value ?? 0
    }

    public func double(_ column: String) -> Double {
        columns[column]?.doubleValue ?? 0.0
    }

    public func string(_ column: String) -> String {
        columns[column]?.stringValue ?? ""
    }

    public func hasColumn(_ column: String) -> Bool {
        columns[column] != nil
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Lightweight, thread-safe (serial-queue / nonisolated Sendable via NSLock) wrapper around C SQLite3.
/// Supports in-memory (`:memory:`) and file-backed databases, prepared statements, savepoints,
/// and atomic `BEGIN IMMEDIATE` transactions.
public final class SQLiteConnection: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()
    private var transactionDepth: Int = 0
    public let path: String

    public init(path: String = ":memory:", readOnly: Bool = false) throws {
        self.path = path
        var handle: OpaquePointer?
        let flags = readOnly
            ? (SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX)
            : (SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX)
        let rc = sqlite3_open_v2(path, &handle, flags, nil)
        guard rc == SQLITE_OK, let opened = handle else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            if let handle { sqlite3_close(handle) }
            throw SQLiteError.openFailed(message: msg, code: rc)
        }
        self.db = opened
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA busy_timeout = 5000;")
    }

    deinit {
        close()
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        if let handle = db {
            sqlite3_close_v2(handle)
            db = nil
        }
    }

    public func execute(_ sql: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let handle = db else {
            throw SQLiteError.openFailed(message: "Database connection is closed", code: SQLITE_MISUSE)
        }
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let message = errMsg.map { String(cString: $0) } ?? Self.lastErrorMessage(handle)
            if let errMsg { sqlite3_free(errMsg) }
            throw SQLiteError.executeFailed(sql: sql, message: message, code: rc)
        }
    }

    @discardableResult
    public func run(_ sql: String, bindings: [SQLiteValue] = []) throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        guard let handle = db else {
            throw SQLiteError.openFailed(message: "Database connection is closed", code: SQLITE_MISUSE)
        }
        var stmt: OpaquePointer?
        let prepRc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard prepRc == SQLITE_OK, let statement = stmt else {
            throw SQLiteError.prepareFailed(sql: sql, message: Self.lastErrorMessage(handle), code: prepRc)
        }
        defer { sqlite3_finalize(statement) }

        try Self.bind(values: bindings, to: statement, db: handle)

        let stepRc = sqlite3_step(statement)
        guard stepRc == SQLITE_DONE || stepRc == SQLITE_ROW else {
            throw SQLiteError.stepFailed(sql: sql, message: Self.lastErrorMessage(handle), code: stepRc)
        }
        return sqlite3_last_insert_rowid(handle)
    }

    public func query(_ sql: String, bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
        lock.lock()
        defer { lock.unlock() }
        guard let handle = db else {
            throw SQLiteError.openFailed(message: "Database connection is closed", code: SQLITE_MISUSE)
        }
        var stmt: OpaquePointer?
        let prepRc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard prepRc == SQLITE_OK, let statement = stmt else {
            throw SQLiteError.prepareFailed(sql: sql, message: Self.lastErrorMessage(handle), code: prepRc)
        }
        defer { sqlite3_finalize(statement) }

        try Self.bind(values: bindings, to: statement, db: handle)

        var rows: [SQLiteRow] = []
        let columnCount = sqlite3_column_count(statement)

        while true {
            let stepRc = sqlite3_step(statement)
            if stepRc == SQLITE_ROW {
                var rowDict: [String: SQLiteValue] = [:]
                rowDict.reserveCapacity(Int(columnCount))
                for colIdx in 0..<columnCount {
                    let colName = String(cString: sqlite3_column_name(statement, colIdx))
                    let colType = sqlite3_column_type(statement, colIdx)
                    let value: SQLiteValue
                    switch colType {
                    case SQLITE_INTEGER:
                        value = .integer(sqlite3_column_int64(statement, colIdx))
                    case SQLITE_FLOAT:
                        value = .real(sqlite3_column_double(statement, colIdx))
                    case SQLITE_TEXT:
                        if let cStr = sqlite3_column_text(statement, colIdx) {
                            value = .text(String(cString: cStr))
                        } else {
                            value = .text("")
                        }
                    case SQLITE_BLOB:
                        let bytes = sqlite3_column_blob(statement, colIdx)
                        let count = Int(sqlite3_column_bytes(statement, colIdx))
                        if let bytes, count > 0 {
                            value = .blob(Data(bytes: bytes, count: count))
                        } else {
                            value = .blob(Data())
                        }
                    default:
                        value = .null
                    }
                    rowDict[colName] = value
                }
                rows.append(SQLiteRow(columns: rowDict))
            } else if stepRc == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.stepFailed(sql: sql, message: Self.lastErrorMessage(handle), code: stepRc)
            }
        }
        return rows
    }

    public func scalarInt(_ sql: String, bindings: [SQLiteValue] = []) throws -> Int {
        let rows = try query(sql, bindings: bindings)
        guard let firstRow = rows.first, let firstVal = firstRow.columns.values.first else {
            return 0
        }
        return firstVal.intValue ?? 0
    }

    public func tableExists(_ tableName: String) throws -> Bool {
        let count = try scalarInt(
            "SELECT COUNT(DISTINCT tbl_name) FROM sqlite_master WHERE tbl_name = ?;",
            bindings: [.text(tableName)]
        )
        return count > 0
    }

    public func columnExists(table: String, column: String) throws -> Bool {
        let rows = try query("PRAGMA table_info(\(table));")
        return rows.contains { $0.string("name").caseInsensitiveCompare(column) == .orderedSame }
    }

    public func userVersion() throws -> Int {
        try scalarInt("PRAGMA user_version;")
    }

    public func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version);")
    }

    /// Executes `block` inside an atomic SQLite transaction (`BEGIN IMMEDIATE` for top-level,
    /// `SAVEPOINT` for nested calls). Automatically rolls back on any thrown error.
    @discardableResult
    public func transaction<T>(_ block: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }

        let depth = transactionDepth
        let savepointName = "sp_fishing_\(depth)"
        if depth == 0 {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
        } else {
            try execute("SAVEPOINT \(savepointName);")
        }
        transactionDepth += 1

        do {
            let result = try block()
            transactionDepth -= 1
            if depth == 0 {
                try execute("COMMIT TRANSACTION;")
            } else {
                try execute("RELEASE SAVEPOINT \(savepointName);")
            }
            return result
        } catch {
            transactionDepth -= 1
            if depth == 0 {
                try? execute("ROLLBACK TRANSACTION;")
            } else {
                try? execute("ROLLBACK TO SAVEPOINT \(savepointName);")
                try? execute("RELEASE SAVEPOINT \(savepointName);")
            }
            throw error
        }
    }

    private static func bind(values: [SQLiteValue], to statement: OpaquePointer, db: OpaquePointer) throws {
        for (idx, value) in values.enumerated() {
            let bindIndex = Int32(idx + 1)
            let rc: Int32
            switch value {
            case let .integer(intVal):
                rc = sqlite3_bind_int64(statement, bindIndex, intVal)
            case let .real(dblVal):
                rc = sqlite3_bind_double(statement, bindIndex, dblVal)
            case let .text(strVal):
                rc = strVal.withCString { cStr in
                    sqlite3_bind_text(statement, bindIndex, cStr, -1, sqliteTransient)
                }
            case let .blob(dataVal):
                rc = dataVal.withUnsafeBytes { rawBuf in
                    sqlite3_bind_blob(statement, bindIndex, rawBuf.baseAddress, Int32(dataVal.count), sqliteTransient)
                }
            case .null:
                rc = sqlite3_bind_null(statement, bindIndex)
            }
            if rc != SQLITE_OK {
                throw SQLiteError.bindFailed(index: bindIndex, message: lastErrorMessage(db), code: rc)
            }
        }
    }

    private static func lastErrorMessage(_ db: OpaquePointer) -> String {
        guard let cStr = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: cStr)
    }
}