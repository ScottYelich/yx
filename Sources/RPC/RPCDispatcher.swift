import Foundation
// filename: RPCDispatcher.swift

import Primitives

public struct RPCRequest: Sendable {
    public let id: String?
    public let method: String
    public let params: [String: JSON]
    public let raw: [String: JSON]
    private let replyHandler: @Sendable (Any) -> Void
    private let errorHandler: @Sendable (String) -> Void

    public init(
        id: String?,
        method: String,
        params: [String: JSON],
        raw: [String: JSON],
        replyHandler: @escaping @Sendable (Any) -> Void,
        errorHandler: @escaping @Sendable (String) -> Void
    ) {
        self.id = id
        self.method = method
        self.params = params
        self.raw = raw
        self.replyHandler = replyHandler
        self.errorHandler = errorHandler
    }

    public func reply(result: Any) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id = id {
            response["id"] = id
        }
        replyHandler(response)
    }

    public func reply(error message: String) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": -32000, "message": message]
        ]
        if let id = id {
            response["id"] = id
        }
        replyHandler(response)
    }
}

public actor RPCDispatcher {

    private var handlers: [String: @Sendable (RPCRequest) async -> Void] = [:]

    public init() {}

    public func register(_ method: String, handler: @escaping @Sendable (RPCRequest) async -> Void) {
        handlers[method] = handler
    }

    public func unregister(_ method: String) {
        handlers.removeValue(forKey: method)
    }

    public func handle(json: [String: Any], reply: @escaping @Sendable (Any) -> Void) async {
        guard let method = json["method"] as? String else {
            reply([
                "jsonrpc": "2.0",
                "error": ["code": -32600, "message": "Missing method"]
            ])
            return
        }

        let id = json["id"] as? String
        let paramsRaw = json["params"] as? [String: Any] ?? [:]

        guard let params = [String: JSON](paramsRaw),
              let raw = [String: JSON](json) else {
            reply([
                "jsonrpc": "2.0",
                "error": ["code": -32602, "message": "Invalid parameters"]
            ])
            return
        }

        let request = RPCRequest(
            id: id,
            method: method,
            params: params,
            raw: raw,
            replyHandler: reply,
            errorHandler: { msg in reply([
                "jsonrpc": "2.0",
                "error": ["code": -32001, "message": msg]
            ]) }
        )

        if let handler = handlers[method] {
            await handler(request)
        } else {
            // Silent ignore for broadcast messages - unhandled methods are expected
            // in a broadcast network architecture (services receive all broadcasts,
            // only handle relevant ones). No error reply sent to avoid flooding
            // network when multiple services ignore the same broadcast.
            return
        }
    }
}


