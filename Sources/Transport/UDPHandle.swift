import Foundation
// filename: UDPNetworking.swift

import Primitives
import CryptoKit

/// Sendable wrapper around UDPTransport.
///
/// Provides a simple synchronous-looking API that internally uses the actor for thread safety.
public final class UDPNetworking: Sendable {
    private let actor: UDPTransport
    private let startTask: Task<Void, Never>?

    public init(guid: Data, key: SymmetricKey, router: ProtocolRouter) {
        self.actor = UDPTransport(guid: guid, key: key, router: router)
        self.startTask = nil
    }

    /// Start UDP listener on the specified port
    public func start(port: UInt16) async throws {
        // Await the actor's start method (required for actor isolation)
        try await actor.start(port: port)
    }

    /// Stop the UDP listener gracefully
    public func stop() {
        Task {
            await actor.stop()
        }
    }

    /// Send a UDP packet
    public func send(_ packet: UDPPacket, to host: String, port: UInt16) {
        Task {
            await actor.send(packet, to: host, port: port)
        }
    }

    /// Set encryption key for a specific peer
    public func setKey(for guid: Data, key: SymmetricKey) {
        Task {
            await actor.setKey(for: guid, key: key)
        }
    }

    /// Get encryption key for a specific peer
    public func key(for guid: Data) -> SymmetricKey? {
        // This is problematic - we can't await in a non-async context
        // Will be fixed in P1 architecture refactor
        // For now, return nil and log a warning
        log("⚠️ UDPNetworking.key(for:) called synchronously - returning nil. Use async version.", level: .warning)
        return nil
    }

    /// Get local GUID (synchronous access to immutable property)
    public var localGUID: Data {
        get async {
            await actor.localGUID
        }
    }

    /// Get all peer keys
    public func allKeys() -> [Data: SymmetricKey] {
        // Same issue as key(for:) - will be fixed in P1
        log("⚠️ UDPNetworking.allKeys() called synchronously - returning empty. Use async version.", level: .warning)
        return [:]
    }

    /// Set whether to process packets sent by this instance
    public func setProcessOwnPackets(_ value: Bool) {
        Task {
            await actor.setProcessOwnPackets(value)
        }
    }

    /// Get whether to process own packets (async)
    public func getProcessOwnPackets() async -> Bool {
        await actor.processOwnPackets
    }

    /// Access to the packet router
    public var router: ProtocolRouter {
        actor.router
    }
}

// MARK: - Actor Extensions for Compatibility

extension UDPTransport {
    func setProcessOwnPackets(_ value: Bool) {
        self.processOwnPackets = value
    }
}
