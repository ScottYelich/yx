import Foundation
// filename: Errors.swift

import Primitives

/// Errors related to network operations
public enum NetworkingError: Error, Equatable {
    case socketCreationFailed
    case bindFailed(port: UInt16)
    case sendFailed(destination: String, reason: String)
    case receiveFailed(reason: String)
    case invalidAddress(String)
    case timeout
}

/// Errors related to packet processing
public enum PacketError: Error, Equatable {
    case invalidPacket(reason: String)
    case hmacValidationFailed
    case decryptionFailed
    case insufficientData(expected: Int, got: Int)
    case guidMissing
    case invalidProtocolID(UInt8)
}

/// Errors related to RPC operations
public enum RPCError: Error, Equatable {
    case methodNotFound(String)
    case invalidRequest(reason: String)
    case invalidResponse(reason: String)
    case timeout
    case handlerError(method: String, underlying: String)
}

/// Errors related to protocol handling
public enum ProtocolError: Error, Equatable {
    case parsingFailed(protocol: String, reason: String)
    case assemblyFailed(messageID: String, reason: String)
    case compressionFailed
    case decompressionFailed
}

// MARK: - LocalizedError conformance for better error messages

extension NetworkingError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create network socket"
        case .bindFailed(let port):
            return "Failed to bind to port \(port)"
        case .sendFailed(let dest, let reason):
            return "Failed to send to \(dest): \(reason)"
        case .receiveFailed(let reason):
            return "Failed to receive: \(reason)"
        case .invalidAddress(let addr):
            return "Invalid address: \(addr)"
        case .timeout:
            return "Network operation timed out"
        }
    }
}

extension PacketError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPacket(let reason):
            return "Invalid packet: \(reason)"
        case .hmacValidationFailed:
            return "Packet HMAC validation failed"
        case .decryptionFailed:
            return "Packet decryption failed"
        case .insufficientData(let expected, let got):
            return "Insufficient data: expected \(expected), got \(got)"
        case .guidMissing:
            return "Packet GUID is missing"
        case .invalidProtocolID(let id):
            return "Invalid protocol ID: 0x\(String(id, radix: 16))"
        }
    }
}

extension RPCError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .methodNotFound(let method):
            return "RPC method not found: \(method)"
        case .invalidRequest(let reason):
            return "Invalid RPC request: \(reason)"
        case .invalidResponse(let reason):
            return "Invalid RPC response: \(reason)"
        case .timeout:
            return "RPC request timed out"
        case .handlerError(let method, let underlying):
            return "RPC handler error for \(method): \(underlying)"
        }
    }
}

extension ProtocolError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .parsingFailed(let proto, let reason):
            return "Failed to parse \(proto): \(reason)"
        case .assemblyFailed(let msgID, let reason):
            return "Failed to assemble message \(msgID): \(reason)"
        case .compressionFailed:
            return "Data compression failed"
        case .decompressionFailed:
            return "Data decompression failed"
        }
    }
}
