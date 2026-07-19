import Foundation
// filename: NetworkSystem.swift

import Primitives
import CryptoKit
import Transport
import RPC

/// Top-level coordinator that manages all networking subsystems.
///
/// Responsibilities:
/// - Network operations (UDP/TCP)
/// - Protocol handler registration and routing
/// - RPC dispatch
/// - Configuration management
public actor NetworkSystem {
    // Networking components
    nonisolated public let networking: Networking
    public let router: ProtocolRouter
    private var handlers: [UInt8: any ProtocolHandler] = [:]

    // RPC subsystem
    public let rpc: RPCSystem

    // Configuration
    public let config: Configuration

    // Protocol handlers
    private let protocol0: TextProtocol
    private let protocol1: BinaryProtocol

    public init(
        guid: Data,
        key: SymmetricKey,
        config: Configuration = .default,
        onText: (@Sendable (String) async -> Void)? = nil
    ) async {
        self.config = config

        // Configure logging from config
        await Log.configure(enabled: config.logging.enabled, minimumLevel: config.logging.minimumLevel)

        // Initialize networking with shared router
        self.router = ProtocolRouter()
        self.networking = Networking(guid: guid, key: key, router: router)

        // Initialize RPC coordinator
        self.rpc = RPCSystem(onText: onText)

        // Create protocol handlers
        self.protocol0 = TextProtocol()
        self.protocol1 = BinaryProtocol()

        // Register protocol handlers
        let proto0ID = await protocol0.proto()
        handlers[proto0ID] = protocol0
        await router.register(protocol0)
        await router.setTextHandler(protocol0)  // Set text handler for proto >= 32

        let proto1ID = await protocol1.proto()
        handlers[proto1ID] = protocol1
        await router.register(protocol1)

        // Wire send APIs for protocol handlers
        let localGUID = networking.localGUID
        let defaultKey = networking.defaultKey
        let udpRef = networking.udp

        // Install send API for Protocol0 (text)
        await protocol0.installSendAPI { data, host, port in
            let packet = UDPPacketUtils.build(
                guid: localGUID,
                bytesAfterGUID: data,
                key: defaultKey
            )
            udpRef.send(packet, to: host, port: port)
        }

        // Set encryption key for Protocol1
        await protocol1.setKey(defaultKey)

        // Install send API for Protocol1 (binary)
        await protocol1.installSendAPI { data, host, port in
            let packet = UDPPacketUtils.build(
                guid: localGUID,
                bytesAfterGUID: data,
                key: defaultKey
            )
            udpRef.send(packet, to: host, port: port)
        }

        // Wire receive handlers - route all data through RPC coordinator
        await protocol0.setReceiveHandler { [weak self] data in
            guard let self else { return }
            await self.rpc.handle(data)
        }

        await protocol1.setReceiveHandler { [weak self] data in
            guard let self else { return }
            await self.rpc.handle(data)
        }

        // Start networking with configured port
        networking.udp.setProcessOwnPackets(config.network.processOwnPackets)
        await networking.startUDPListener(on: config.network.udpPort, key: defaultKey)
    }

    /// Gracefully shuts down all subsystems
    public func shutdown() async {
        log("🛑 NetworkSystem: Initiating graceful shutdown...", level: .info)

        // Stop networking first to prevent new packets
        networking.udp.stop()

        // TODO: In future, notify protocol handlers to flush buffers
        // TODO: In future, notify RPC dispatcher to cancel pending requests

        log("✅ NetworkSystem: Shutdown complete", level: .info)
    }

    // MARK: - Protocol Registration

    /// Returns all registered protocol IDs
    public func registeredProtocols() -> [UInt8] {
        Array(handlers.keys).sorted()
    }

    /// Gets a specific protocol handler
    public func getHandler(for protoID: UInt8) -> (any ProtocolHandler)? {
        handlers[protoID]
    }
}

// MARK: - Convenience API

extension NetworkSystem {
    /// Sends a text packet (JSON-RPC)
    public func sendTextPacket(_ json: [String: Any], to host: String, port: UInt16) async {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            log("❌ Failed to encode JSON for text packet", level: .error)
            return
        }

        let packet = UDPPacketUtils.build(
            guid: networking.localGUID,
            bytesAfterGUID: data,
            key: networking.defaultKey
        )
        networking.sendUDPPacket(packet, to: host, port: port)
        log("📤 Sent text packet to \(host):\(port)", level: .info)
    }

    /// Sends a binary packet (Protocol 1)
    public func sendProtocol1Packet(
        payload: Data,
        protoOpts: UInt8,
        to host: String,
        port: UInt16
    ) async {
        await protocol1.send(payload: payload, protoOpts: protoOpts, to: host, port: port)
    }

    /// Returns local GUID
    public var localGUID: Data {
        networking.localGUID
    }

    /// Returns default key
    public var defaultKey: SymmetricKey {
        networking.defaultKey
    }
}
