import Foundation
import YXProtocol

// SwiftSender - YX Protocol interop test sender
// Implements: protocol/specs/testing/interoperability-requirements.md
//
// Usage: SwiftSender <mode> [data_hex_or_json]
// Modes: proto0, proto1-base, proto1-compressed, proto1-encrypted, proto1-both

extension Data {
    init?(hex: String) {
        guard hex.count % 2 == 0 else { return nil }
        var data = Data()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            guard let byte = UInt8(hex[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        self = data
    }
}

func runSender() throws {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        print("Usage: SwiftSender <mode> [data]")
        exit(1)
    }

    let mode = args[1]
    let guid = TestConfig.testGUID
    let key = TestConfig.testKey
    let port = TestConfig.testPort

    switch mode {
    case "proto0":
        let jsonStr = args.count > 2 ? args[2] : "{\"method\":\"test\"}"
        guard let jsonData = jsonStr.data(using: .utf8),
              let message = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("ERROR: invalid JSON")
            exit(1)
        }
        let packet = try SimplePacketBuilder.buildTextPacket(message, guid: guid, key: key)
        try sendUDPPacket(packet, to: "127.0.0.1", port: port)
        print("SENT proto0: \(jsonStr)")

    case "proto1-base":
        let data = args.count > 2 ? (Data(hex: args[2]) ?? Data("hello".utf8)) : Data("hello".utf8)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x00)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-base: \(data.count) bytes")

    case "proto1-compressed":
        let data = args.count > 2 ? (Data(hex: args[2]) ?? Data(repeating: 0xAA, count: 100)) : Data(repeating: 0xAA, count: 100)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x01)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-compressed: \(data.count) bytes")

    case "proto1-encrypted":
        let data = args.count > 2 ? (Data(hex: args[2]) ?? Data("secret".utf8)) : Data("secret".utf8)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x02)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-encrypted: \(data.count) bytes")

    case "proto1-both":
        let data = args.count > 2 ? (Data(hex: args[2]) ?? Data(repeating: 0xBB, count: 100)) : Data(repeating: 0xBB, count: 100)
        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x03)
        try sendUDPPackets(packets, to: "127.0.0.1", port: port)
        print("SENT proto1-both: \(data.count) bytes")

    default:
        print("Unknown mode: \(mode)")
        exit(1)
    }

    exit(0)
}

do {
    try runSender()
} catch {
    print("ERROR: \(error)")
    exit(1)
}
