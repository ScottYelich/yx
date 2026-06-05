import Foundation

/// Routes incoming payloads to protocol-specific handlers based on protocol ID
///
/// Protocol IDs:
/// - 0x00: Text (JSON-RPC 2.0)
/// - 0x01: Binary (Chunked with compression/encryption)
actor ProtocolRouter {

    /// Protocol handler function type
    typealias ProtocolHandler = (Data) async throws -> Void

    /// Registered protocol handlers
    private var handlers: [UInt8: ProtocolHandler] = [:]

    /// Register a protocol handler
    func register(protocolID: UInt8, handler: @escaping ProtocolHandler) {
        handlers[protocolID] = handler
    }

    /// Route payload to appropriate protocol handler
    /// - Throws: ProtocolError if protocol not supported or payload invalid
    func route(payload: Data) async throws {
        guard !payload.isEmpty else {
            throw ProtocolError.emptyPayload
        }

        let protocolID = payload[payload.startIndex]

        guard let handler = handlers[protocolID] else {
            throw ProtocolError.unsupportedProtocol(protocolID)
        }

        try await handler(payload)
    }

    /// Get registered protocol IDs
    func registeredProtocols() -> [UInt8] {
        return Array(handlers.keys).sorted()
    }
}

/// Protocol routing errors
enum ProtocolError: Error, CustomStringConvertible {
    case emptyPayload
    case unsupportedProtocol(UInt8)
    case invalidFormat(String)
    case encodingError(String)
    case decodingError(String)

    var description: String {
        switch self {
        case .emptyPayload:
            return "Empty payload"
        case .unsupportedProtocol(let id):
            return "Unsupported protocol: 0x\(String(format: "%02X", id))"
        case .invalidFormat(let msg):
            return "Invalid format: \(msg)"
        case .encodingError(let msg):
            return "Encoding error: \(msg)"
        case .decodingError(let msg):
            return "Decoding error: \(msg)"
        }
    }
}
