import Foundation
// filename: PacketInspector.swift

import Primitives
import CryptoKit

public struct PacketInspector {

    public let protocol1: BinaryProtocol

    public init(protocol1: BinaryProtocol) {
        self.protocol1 = protocol1
    }

    public func debugDump(_ packet: UDPPacket, key: SymmetricKey) async {
        log("🧩 Packet Dump", level: .debug)
        log("  State: \(packet.state)")
        log("  Errors: \(packet.errors)")
        log("  HMAC: \(packet.hmac?.hexString ?? "nil")")
        log("  GUID: \(packet.guid?.hexString ?? "nil")")

        let payload = packet.bytesAfterGUID
        if let firstByte = payload.first, firstByte < 32 {
            log("  Proto: \(firstByte)")

            if let header = Protocol1Header(from: payload) {
                log("  ProtoOpts: \(header.protoOpts)")
                log("  ➤ Protocol1 Header (v2.0):")
                log("    proto: \(header.proto)")
                log("    protoOpts: \(header.protoOpts)")
                log("    channelID: \(header.channelID)")
                log("    sequence: \(header.sequence)")
                log("    chunkIndex: \(header.chunkIndex)")
                log("    totalChunks: \(header.totalChunks)")

                if let content = await protocol1.extractPayload(from: packet, key: key) {
                    log("    Decoded Payload: \(content.hexString)")
                } else {
                    log("    ❌ Could not extract payload")
                }
            } else {
                log("  ❌ Could not parse Protocol1Header")
            }
        } else {
            if let utf8 = String(data: payload, encoding: .utf8), utf8.allSatisfy(\.isASCII) {
                log("  Payload (UTF-8 text): \(utf8)")
            } else {
                log("  Payload (Raw): \(payload.hexString)")
            }
        }
    }
}
