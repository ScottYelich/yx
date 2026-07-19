import Foundation
// filename: Networking.swift

import Primitives
import CryptoKit

/// Sendable networking coordinator.
///
/// Provides a unified API for UDP and TCP networking operations.
/// All properties are immutable and Sendable, making this struct safe for concurrent use.
public struct Networking: Sendable {

    public let udp: UDPNetworking
    private let tcp: TCPNetworking
    public let localGUID: Data
    public let defaultKey: SymmetricKey

    public init(guid: Data, key: SymmetricKey, router: ProtocolRouter) {
        self.localGUID = guid
        self.defaultKey = key
        self.udp = UDPNetworking(guid: guid, key: key, router: router)
        self.udp.setKey(for: guid, key: key)
        self.tcp = TCPNetworking()
    }

    public func startUDPListener(on port: UInt16, key: SymmetricKey) async {
        do {
            try await udp.start(port: port)
        } catch {
            // For now, print but plan to propagate in future iterations
            log("❌ Failed to start UDP listener: \(error.localizedDescription)", level: .error)
        }
    }

    /// Send raw UDPPacket as-is
    public func sendUDPPacket(_ packet: UDPPacket, to host: String, port: UInt16) {
        udp.send(packet, to: host, port: port)
    }

    /// Send payload to peer, using peer-specific key if known
    public func sendUDPPacket(to host: String, port: UInt16, peerGUID: Data, payload: Data) {
        let key = udp.key(for: peerGUID) ?? defaultKey
        let packet = UDPPacketUtils.build(to: peerGUID, guid: localGUID, bytesAfterGUID: payload, key: key)
        udp.send(packet, to: host, port: port)
    }

    /// Register a peer key
    public func setKey(for guid: Data, key: SymmetricKey) {
        udp.setKey(for: guid, key: key)
    }
    
    public var router: ProtocolRouter {
        return udp.router
    }

    public func exportConfig() -> NetworkingConfig {
        NetworkingConfig(guid: localGUID, key: defaultKey, router: router)
    }

}

public struct NetworkingConfig: Sendable {
    public let guid: Data
    public let key: SymmetricKey
    public let router: ProtocolRouter

}
