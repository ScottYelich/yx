import Foundation
// filename: MockNetworking.swift

import Primitives
import CryptoKit

/// Mock networking implementation for testing.
///
/// Captures sent packets and allows injecting received packets without real sockets.
public actor MockNetworking {
    /// Captured packets from send() calls
    public private(set) var sentPackets: [(packet: MockPacket, host: String, port: UInt16)] = []

    /// Injected packets to be "received"
    private var injectQueue: [MockPacket] = []

    /// Optional receive handler (called when packets are injected)
    private var onReceive: (@Sendable (MockPacket) async -> Void)?

    /// Sets the receive handler
    public func setOnReceive(_ handler: @escaping @Sendable (MockPacket) async -> Void) {
        onReceive = handler
    }

    /// GUID for this mock instance
    public let guid: Data

    /// Default key for this mock instance
    public let key: SymmetricKey

    /// Whether the mock is "running"
    public private(set) var isRunning = false

    public init(guid: Data, key: SymmetricKey) {
        self.guid = guid
        self.key = key
    }

    /// Starts the mock networking (just sets flag)
    public func start(port: UInt16) {
        isRunning = true
    }

    /// Stops the mock networking
    public func stop() {
        isRunning = false
    }

    /// Sends a packet (captures it for inspection)
    public func send(_ packet: MockPacket, to host: String, port: UInt16) {
        sentPackets.append((packet, host, port))
    }

    /// Injects a packet as if it was received
    public func inject(_ packet: MockPacket) async {
        injectQueue.append(packet)
        await onReceive?(packet)
    }

    /// Returns all injected packets and clears the queue
    public func drainInjectQueue() -> [MockPacket] {
        let packets = injectQueue
        injectQueue.removeAll()
        return packets
    }

    /// Clears all captured sent packets
    public func clearSentPackets() {
        sentPackets.removeAll()
    }

    /// Returns the last sent packet, if any
    public var lastSentPacket: (packet: MockPacket, host: String, port: UInt16)? {
        sentPackets.last
    }

    /// Returns the number of sent packets
    public var sentCount: Int {
        sentPackets.count
    }
}

/// Simplified packet representation for testing
public struct MockPacket: Sendable {
    public let guid: Data?
    public let protocolID: UInt8
    public let payload: Data
    public let hmac: Data?

    public init(guid: Data?, protocolID: UInt8, payload: Data, hmac: Data? = nil) {
        self.guid = guid
        self.protocolID = protocolID
        self.payload = payload
        self.hmac = hmac
    }

    /// Creates a text packet
    public static func text(from: Data, message: String) -> MockPacket {
        let payload = message.data(using: .utf8) ?? Data()
        return MockPacket(guid: from, protocolID: 0x00, payload: payload)
    }

    /// Creates a binary packet
    public static func binary(from: Data, data: Data) -> MockPacket {
        return MockPacket(guid: from, protocolID: 0x01, payload: data)
    }

    /// Creates an RPC packet
    public static func rpc(from: Data, json: String) -> MockPacket {
        let payload = json.data(using: .utf8) ?? Data()
        return MockPacket(guid: from, protocolID: 0x22, payload: payload)
    }
}

/// Mock packet router for testing
public actor MockRouter {
    /// Captured routed packets
    public private(set) var routedPackets: [(packet: MockPacket, key: SymmetricKey)] = []

    /// Optional routing handler
    private var onRoute: (@Sendable (MockPacket, SymmetricKey) async -> Void)?

    /// Sets the routing handler
    public func setOnRoute(_ handler: @escaping @Sendable (MockPacket, SymmetricKey) async -> Void) {
        onRoute = handler
    }

    public init() {}

    /// Routes a packet (captures it)
    public func route(_ packet: MockPacket, key: SymmetricKey) async {
        routedPackets.append((packet, key))
        await onRoute?(packet, key)
    }

    /// Clears captured packets
    public func clear() {
        routedPackets.removeAll()
    }

    /// Returns the number of routed packets
    public var routedCount: Int {
        routedPackets.count
    }
}

/// Mock rate limiter for testing
public actor MockRateLimiter {
    private var blockedPeers: Set<String> = []
    private var requestCounts: [String: Int] = [:]

    public init() {}

    /// Sets whether a peer should be blocked
    public func block(peer: String) {
        blockedPeers.insert(peer)
    }

    /// Unblocks a peer
    public func unblock(peer: String) {
        blockedPeers.remove(peer)
    }

    /// Checks if a peer is allowed (returns false if blocked)
    public func checkLimit(for peer: String) -> Bool {
        requestCounts[peer, default: 0] += 1
        return !blockedPeers.contains(peer)
    }

    /// Returns request count for a peer
    public func requestCount(for peer: String) -> Int {
        requestCounts[peer, default: 0]
    }

    /// Clears all state
    public func reset() {
        blockedPeers.removeAll()
        requestCounts.removeAll()
    }
}

/// Mock nonce cache for testing
public actor MockReplayProtection {
    private var seenNonces: Set<Data> = []
    private var shouldRejectNext = false

    public init() {}

    /// Checks and records a nonce
    public func checkAndRecord(_ nonce: Data) -> Bool {
        if shouldRejectNext {
            shouldRejectNext = false
            return false
        }

        if seenNonces.contains(nonce) {
            return false
        }

        seenNonces.insert(nonce)
        return true
    }

    /// Forces the next check to fail (for testing replay detection)
    public func rejectNext() {
        shouldRejectNext = true
    }

    /// Returns the number of seen nonces
    public var count: Int {
        seenNonces.count
    }

    /// Clears all state
    public func clear() {
        seenNonces.removeAll()
        shouldRejectNext = false
    }
}
