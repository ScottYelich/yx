import Foundation

/// Protocol ID byte (first byte of payload).
///
/// Traceability:
/// - protocol/specs/architecture/protocol-layers.md (Protocol ID Registry)
public enum ProtocolID: UInt8 {
    case text   = 0x00  // Protocol 0: Text/JSON-RPC
    case binary = 0x01  // Protocol 1: Binary/Chunked
}

/// Routes validated payloads to the appropriate protocol handler.
///
/// Traceability:
/// - protocol/specs/architecture/protocol-layers.md (Protocol Router)
public actor ProtocolRouter {

    public typealias Handler = (Data) async throws -> Void

    private var handlers: [UInt8: Handler] = [:]

    public init() {}

    /// Register a protocol handler.
    /// - Parameters:
    ///   - protocolID: Protocol ID byte (e.g. 0x00 for text)
    ///   - handler: Async function that processes the payload
    public func register(protocolID: UInt8, handler: @escaping Handler) {
        handlers[protocolID] = handler
    }

    /// Route payload to the registered handler by protocol ID.
    /// - Parameter payload: Raw payload (first byte is protocol ID)
    /// - Throws: ProtocolRouterError if payload empty or no handler registered
    public func route(payload: Data) async throws {
        guard !payload.isEmpty else {
            throw ProtocolRouterError.emptyPayload
        }
        let id = payload[0]
        guard let handler = handlers[id] else {
            throw ProtocolRouterError.unknownProtocol(id)
        }
        try await handler(payload)
    }
}

/// Errors from ProtocolRouter.
public enum ProtocolRouterError: Error, CustomStringConvertible {
    case emptyPayload
    case unknownProtocol(UInt8)

    public var description: String {
        switch self {
        case .emptyPayload:
            return "Empty payload"
        case .unknownProtocol(let id):
            return String(format: "Unknown protocol ID: 0x%02x", id)
        }
    }
}
