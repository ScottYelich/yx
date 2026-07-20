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

    /// S-expression car-dispatch table (Protocol-0 s-expr, ADR D11): head symbol → handler.
    private var sexpHandlers: [String: @Sendable (SExpr) async -> Void] = [:]

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

    /// Registers an S-expression handler for a car (head) symbol (ADR D11).
    public func registerSexp(
        _ head: String,
        handler: @escaping @Sendable (SExpr) async -> Void
    ) {
        sexpHandlers[head] = handler
    }

    /// Handles incoming data.
    /// Protocol-0 dispatch (ADR D11): peek the first non-whitespace byte —
    /// `(` → S-expression, dispatch on the car symbol; `{` → legacy JSON-RPC path.
    public func handle(_ data: Data) async {
        // S-expression path
        let ws: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        if let first = data.first(where: { !ws.contains($0) }),
           first == UInt8(ascii: "(") {
            guard let text = String(data: data, encoding: .utf8),
                  let expr = SExpr.parse(text),
                  let head = expr.head else {
                log("❓ RPCSystem: Malformed S-expression payload", level: .warning)
                return
            }
            if let handler = sexpHandlers[head] {
                await handler(expr)
            } else {
                log("❓ RPCSystem: No S-expr handler for '\(head)' — ignored", level: .debug)
            }
            return
        }
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
