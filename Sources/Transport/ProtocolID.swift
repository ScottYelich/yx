import Foundation
// filename: ProtocolID.swift

import Primitives

/// Unique protocol identifiers for packet routing.
///
/// Each protocol handler must use a unique ID. Collisions are detected at compile time.
public enum ProtocolID: UInt8, CaseIterable, Sendable {
    // Protocol actors (0x00-0x1F)
    case text = 0x00           // TextProtocol - text/JSON
    case binary = 0x01         // BinaryProtocol - binary with chunking

    // RPC handlers (0x20-0x3F)
    case taskHello = 0x21      // TaskHelloHandler
    case rpcChain = 0x22       // RPCChainHandler
    case taskChain = 0x23      // TaskChainHandler

    // Future use (0x40-0xFF)
    // Reserved for application-specific protocols

    /// Validates that all protocol IDs are unique.
    ///
    /// Call during app initialization to detect configuration errors.
    public static func validateUniqueness() {
        let ids = allCases.map(\.rawValue)
        let uniqueIds = Set(ids)

        assert(uniqueIds.count == ids.count,
               "Protocol ID collision detected! \(ids) contains duplicates")
    }

    /// Human-readable name for logging
    public var name: String {
        switch self {
        case .text: return "Protocol0/Text"
        case .binary: return "Protocol1/Binary"
        case .taskHello: return "TaskHello"
        case .rpcChain: return "RPCChain"
        case .taskChain: return "TaskChain"
        }
    }
}
