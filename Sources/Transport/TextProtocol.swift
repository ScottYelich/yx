import Foundation
// filename: TextProtocol.swift

import Primitives
import CryptoKit

/// A basic protocol actor for handling text-based payloads (Protocol 0).
public actor TextProtocol: ProtocolHandler {

    public func proto() async -> UInt8 { ProtocolID.text.rawValue }

    private let core = ProtocolActorCore(proto: 0x00)
    private var sendAPI: (@Sendable (Data, String, UInt16) async -> Void)?

    public init() {}

    /// Injects a send function for outbound messages.
    public func installSendAPI(_ send: @escaping @Sendable (Data, String, UInt16) async -> Void) async {
        self.sendAPI = send
    }

    /// Sets the receive handler for incoming payloads.
    public func setReceiveHandler(_ handler: @escaping @Sendable (Data) async -> Void) async {
        core.setReceiveHandler(handler)
    }

    /// Ingests a validated UDPPacket and routes its payload to the receive handler.
    public func ingest(_ packet: UDPPacket, key: SymmetricKey) async {
        guard let text = packet.bytesAfterGUID.utf8String else {
            log("⚠️ TextProtocol: Invalid UTF-8 payload", level: .warning)
            return
        }
        guard let payload = text.data(using: .utf8) else {
            log("⚠️ TextProtocol: Failed to convert string to Data", level: .warning)
            return
        }
        await core.handlePayload(payload)
    }

    /// Sends a UTF-8 text payload to the specified host and port.
    public func send(_ payload: Data, to host: String = "192.168.1.255", port: UInt16 = 9999) async {
        guard let send = sendAPI else {
            log("❌ TextProtocol: sendAPI not installed", level: .error)
            return
        }

        await send(payload, host, port)
        log("📤 TextProtocol: Sent text to \(host):\(port)", level: .info)
    }
}
