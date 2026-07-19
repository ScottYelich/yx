import Foundation
// filename: SQLiteInterpreter.swift

import Primitives
import SQLite3

public struct KeyValueRow: Sendable {
    public let key: String
    public let value: String
}

public actor SQLiteInterpreter: Interpreter {

    public let name: String = "sql"
    private var db: OpaquePointer?

    public init() async {
        await openMemoryDatabase()
    }

    private func openMemoryDatabase() async {
        if sqlite3_open(":memory:", &db) != SQLITE_OK {
            log("❌ Failed to open in-memory database.", level: .error)
        }
    }

    public func execute(_ sql: String, args: [Any] = []) async -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            log("❌ SQL prepare failed: \(sql)", level: .error)
            return false
        }

        bindArgs(statement, args)

        let status = sqlite3_step(statement)
        sqlite3_finalize(statement)
        return status == SQLITE_DONE || status == SQLITE_ROW
    }

    public func query(_ sql: String, args: [Any] = []) async -> [KeyValueRow] {
        var results: [KeyValueRow] = []
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            log("❌ SQL prepare failed: \(sql)", level: .error)
            return []
        }

        bindArgs(statement, args)

        while sqlite3_step(statement) == SQLITE_ROW {
            let key: String = {
                if let text = sqlite3_column_text(statement, 0) {
                    return String(cString: text)
                } else {
                    return ""
                }
            }()

            let value: String = {
                if let text = sqlite3_column_text(statement, 1) {
                    return String(cString: text)
                } else {
                    return ""
                }
            }()

            results.append(KeyValueRow(key: key, value: value))
        }

        sqlite3_finalize(statement)
        return results
    }

    private func bindArgs(_ stmt: OpaquePointer?, _ args: [Any]) {
        for (i, arg) in args.enumerated() {
            let index = Int32(i + 1)

            if let s = arg as? String {
                sqlite3_bind_text(stmt, index, s, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else if let n = arg as? Int {
                sqlite3_bind_int64(stmt, index, sqlite3_int64(n))
            } else if let d = arg as? Double {
                sqlite3_bind_double(stmt, index, d)
            } else if let b = arg as? Bool {
                sqlite3_bind_int(stmt, index, b ? 1 : 0)
            } else if arg is NSNull {
                sqlite3_bind_null(stmt, index)
            } else {
                sqlite3_bind_text(stmt, index, "\(arg)", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }
    }

    public func evaluate(input: String) async -> String {
        await execute(input) ? "ok" : "error"
    }
}


