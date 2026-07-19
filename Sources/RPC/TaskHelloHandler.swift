import Foundation
// filename: TaskHelloHandler.swift

import Primitives
import CryptoKit
import Transport

/// Handles task.hello messages and broadcasts signed hello packets.
public actor TaskHelloHandler: ProtocolInterface {

    private let pki: IdentityManager
    private var sendAPI: (@Sendable (Data, String, UInt16) async -> Void)?
    private let guid: Data
    private let key: SymmetricKey
    private let udp: UDPNetworking
    private var dispatcher: RPCDispatcher?

    public init(networking: Networking) {
        self.guid = networking.localGUID
        self.key = networking.defaultKey
        self.udp = networking.udp
        self.pki = IdentityManager(guid: guid.hexString)
    }

    public func installSendAPI(_ send: @escaping @Sendable (Data, String, UInt16) async -> Void) async {
        self.sendAPI = send
    }

    public func register(with dispatcher: RPCDispatcher) async {
        self.dispatcher = dispatcher
        await dispatcher.register("task.hello") { [weak self] req in
            guard let self else { return }
            await self.handleHello(req: req)
        }
    }

    private func handleHello(req: RPCRequest) async {
        guard let fromHex = req.params["guid"]?.rawValue as? String,
              let timestampStr = req.params["timestamp"]?.rawValue as? String,
              let publicKeyB64 = req.params["publicKey"]?.rawValue as? String,
              let signingKeyB64 = req.params["signingKey"]?.rawValue as? String,
              let signatureB64 = req.params["signature"]?.rawValue as? String,
              let timestamp = Int(timestampStr),
              let peerGUID = Data(hex: fromHex)
        else {
            req.reply(error: "Invalid task.hello format")
            return
        }

        let valid = pki.verifyHelloSignature(
            guid: fromHex,
            timestamp: timestamp,
            publicKeyBase64: publicKeyB64,
            signingKeyBase64: signingKeyB64,
            signatureBase64: signatureB64
        )

        guard valid else {
            log("❌ [task.hello] Invalid signature from \(fromHex)", level: .error)
            req.reply(error: "Invalid signature")
            return
        }

        guard let symKey = pki.deriveSymmetricKey(with: publicKeyB64) else {
            log("❌ [task.hello] Failed to derive key for \(fromHex)", level: .error)
            req.reply(error: "Key derivation failed")
            return
        }

        if peerGUID != guid {
            if let existing = udp.key(for: peerGUID), existing != symKey {
                log("🚨 GUID collision detected: \(fromHex) — keys differ", level: .warning)
                return
            }

            log("🧪 Setting key for \(peerGUID.hexString) — \(symKey.withUnsafeBytes { Data($0).hexString })", level: .debug)
            udp.setKey(for: peerGUID, key: symKey)
            log("🔐 [task.hello] Learned verified key for peer \(fromHex)", level: .info)
            req.reply(result: "ok")
        } else {
            log("ℹ️ [task.hello] Ignored self-hello", level: .info)
        }
    }

    public func sendHello(to host: String, port: UInt16) async {
        guard let send = sendAPI else {
            log("❌ TaskHelloHandler: sendAPI not installed", level: .error)
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fields = pki.exportHelloFields(timestamp: timestamp)

        let payload: [String: JSON] = [
            "jsonrpc": .string("2.0"),
            "method": .string("task.hello"),
            "params": .object(fields.compactMapValues { JSON($0) }),
            "id": .string(UUID().uuidString)
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload.rawValue) else {
            log("❌ Failed to encode task.hello packet", level: .error)
            return
        }

        let packet = UDPPacketUtils.build(guid: guid, bytesAfterGUID: data, key: key)
        await send(packet.bytes, host, port)

        log("📣 Broadcasted signed task.hello (GUID: \(guid.hexString))", level: .info)
    }
    
    public func proto() async -> UInt8 { ProtocolID.taskHello.rawValue }

    public func ingest(_ packet: UDPPacket, key: SymmetricKey) async {
        guard let data = packet.bytesAfterGUID.utf8String?.data(using: .utf8) else { return }
        await handleInbound(data)
    }

    // MARK: - Private Helpers
    private func handleInbound(_ data: Data) async {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let dict = json as? [String: Any] {
            await dispatcher?.handle(json: dict) { _ in }
        }
    }

}

