// filename: DemoSender.swift

import Foundation
import YX
import Primitives
import RPC

enum DemoSender {
    static func sendTaskHello(using comms: NetworkSystem, targets: [PeerTarget]) async {
        let guidString = await comms.localGUID.hexString

        // Use IdentityManager to create proper PKI-based hello
        let pki = IdentityManager(guid: guidString)
        let timestamp = Int(Date().timeIntervalSince1970)
        let fields = pki.exportHelloFields(timestamp: timestamp)

        if targets.isEmpty {
            // No specific peers - send broadcast to default
            let packet = DemoPackets.taskHelloPacket(fields: fields)
            await comms.sendTextPacket(packet, to: "192.168.1.255", port: 9999)
            log("📣 Sent task.hello broadcast to 192.168.1.255:9999", level: .info)
        } else {
            // Send to each configured peer
            for target in targets {
                let packet = DemoPackets.taskHelloPacket(fields: fields)
                await comms.sendTextPacket(packet, to: target.host, port: target.port)
                log("📣 Sent task.hello to \(target.host):\(target.port)", level: .info)
            }
        }
    }

    static func sendBinaryTest(using comms: NetworkSystem, protoOpts: UInt8, payloadSize: Int?, targets: [PeerTarget]) async {
        // Create test payload with timestamp and description
        let timestamp = Int(Date().timeIntervalSince1970)
        let description = protoOptsDescription(protoOpts)

        let payload: Data
        if let size = payloadSize {
            // Generate payload of specified size
            let header = """
            {
                "type": "binary_test",
                "timestamp": \(timestamp),
                "proto_opts": "0x\(String(format: "%02X", protoOpts))",
                "description": "\(description)",
                "payload_size": \(size),
                "data": "
            """

            guard var headerData = header.data(using: .utf8) else {
                log("❌ Failed to encode header", level: .error)
                return
            }

            // Calculate remaining size for padding
            let footer = "\"\n}"
            let footerSize = footer.utf8.count
            let remainingSize = size - headerData.count - footerSize

            if remainingSize > 0 {
                // Fill with repeating pattern
                let pattern = "0123456789ABCDEF"
                let patternData = Data(pattern.utf8)
                let fullRepeats = remainingSize / patternData.count
                let partialSize = remainingSize % patternData.count

                for _ in 0..<fullRepeats {
                    headerData.append(patternData)
                }
                headerData.append(patternData.prefix(partialSize))
            }

            headerData.append(Data(footer.utf8))
            payload = headerData

            log("📏 Generated \(payload.count) byte payload (requested: \(size))", level: .info)
        } else {
            // Default small test message
            let testMessage = """
            {
                "type": "binary_test",
                "timestamp": \(timestamp),
                "proto_opts": "0x\(String(format: "%02X", protoOpts))",
                "description": "\(description)",
                "payload": "This is a test message to verify Protocol 1 binary packet handling with different encoding options."
            }
            """

            guard let messageData = testMessage.data(using: .utf8) else {
                log("❌ Failed to encode test message", level: .error)
                return
            }
            payload = messageData
        }

        if targets.isEmpty {
            // No specific peers - send broadcast to default
            await comms.sendProtocol1Packet(payload: payload, protoOpts: protoOpts, to: "192.168.1.255", port: 9999)
            log("📦 Sent binary test (\(description)) broadcast to 192.168.1.255:9999", level: .info)
        } else {
            // Send to each configured peer
            for target in targets {
                await comms.sendProtocol1Packet(payload: payload, protoOpts: protoOpts, to: target.host, port: target.port)
                log("📦 Sent binary test (\(description)) to \(target.host):\(target.port)", level: .info)
            }
        }
    }

    private static func protoOptsDescription(_ opts: UInt8) -> String {
        switch opts {
        case 0x00: return "Plaintext, Uncompressed"
        case 0x01: return "Plaintext, Compressed"
        case 0x02: return "Encrypted, Uncompressed"
        case 0x03: return "Encrypted, Compressed"
        default: return "Unknown (0x\(String(format: "%02X", opts)))"
        }
    }
}

