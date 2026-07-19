import Foundation
// filename: RPCSystem.swift

import Primitives
import RPC

/// Coordinates JSON-RPC operations.
///
/// Responsible for:
/// - Managing RPC dispatcher
/// - Registering RPC handlers
/// - Dispatching RPC requests
/// - Handling JSON-RPC vs text fallback
public actor RPCSystem {
    public let dispatcher: RPCDispatcher
    private let fallback: (@Sendable (String) async -> Void)?

    public init(onText fallback: (@Sendable (String) async -> Void)? = nil) {
        self.dispatcher = RPCDispatcher()
        self.fallback = fallback
    }

    /// Registers an RPC handler
    public func register(
        _ method: String,
        handler: @escaping @Sendable (RPCRequest) async -> Void
    ) async {
        await dispatcher.register(method, handler: handler)
    }

    /// Handles incoming data - tries JSON-RPC first, then text fallback
    public func handle(_ data: Data) async {
        // Try JSON-RPC first
        // Accept both strict JSON-RPC 2.0 (with "jsonrpc": "2.0") and relaxed format (just needs "method")
        if let raw = try? JSONSerialization.jsonObject(with: data),
           let json = JSON(raw),
           case let .object(dict) = json,
           dict["method"] != nil {
            // Accept if either: (1) has "jsonrpc": "2.0", or (2) has "method" field (relaxed mode)
            let hasJsonRpc = dict["jsonrpc"]?.stringValue == "2.0"
            let hasMethod = dict["method"]?.stringValue != nil

            if hasJsonRpc || hasMethod {
                // Convert [String: JSON] back to [String: Any] for the dispatcher
                await dispatcher.handle(json: dict.rawValue) { _ in }
                return
            }
        }

        // Try text fallback
        if let text = String(data: data, encoding: .utf8) {
            await fallback?(text)
        }
        // Unknown format
        else {
            log("❓ RPCSystem: Unrecognized payload format", level: .warning)
        }
    }
}
