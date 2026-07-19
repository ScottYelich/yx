import Foundation
// filename: DataRefHandler.swift

import Primitives

public actor DataRefHandler {

    private let sql: SQLiteInterpreter

    public init(sql: SQLiteInterpreter) async {
        self.sql = sql

        _ = await sql.execute("""
            CREATE TABLE IF NOT EXISTS kv_store (
                key TEXT PRIMARY KEY,
                value TEXT
            );
        """, args: [])
    }

    public func register(with dispatcher: RPCDispatcher) {
        let handler = self

        Task {
            await dispatcher.register("data.set") { req in
                await handler.handleSet(req)
            }

            await dispatcher.register("data.get") { req in
                await handler.handleGet(req)
            }
        }
    }

    private func handleSet(_ req: RPCRequest) async {
        guard let ref = req.params["ref"]?.stringValue else {
            req.reply(error: "Missing ref")
            return
        }

        guard let value = req.params["value"] else {
            req.reply(error: "Missing value")
            return
        }

        let valueRaw = value.rawValue

        let valueString: String
        if JSONSerialization.isValidJSONObject(valueRaw),
           let jsonData = try? JSONSerialization.data(withJSONObject: valueRaw),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            valueString = jsonString
        } else {
            valueString = "\(valueRaw)"
        }

        let ok = await sql.execute(
            "REPLACE INTO kv_store (key, value) VALUES (?, ?);",
            args: [ref, valueString]
        )

        if ok {
            req.reply(result: "ok")
        } else {
            req.reply(error: "Failed to store value")
        }
    }

    private func handleGet(_ req: RPCRequest) async {
        guard let ref = req.params["ref"]?.stringValue else {
            req.reply(error: "Missing ref")
            return
        }

        let rows = await sql.query("SELECT key, value FROM kv_store WHERE key = ?;", args: [ref])
        guard let row = rows.first else {
            req.reply(result: "null")
            return
        }

        let raw = row.value

        if let data = raw.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let json = JSON(jsonObject) {
            req.reply(result: "\(json.rawValue)")
        } else {
            req.reply(result: raw)
        }
    }
}


