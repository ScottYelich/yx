import Foundation
import YXProtocol

// Minimal demo receiver: bind, receive one YX packet, verify HMAC, print payload.
guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift-receiver <port>")
    exit(1)
}

let port = UInt16(CommandLine.arguments[1]) ?? TestConfig.testPort
let key = TestConfig.testKey

do {
    let (packet, _, _) = try UDPHelper.receive(port: port, timeout: 3.0)

    guard SimplePacketBuilder.verifyPacket(packet: packet, key: key) else {
        print("ERROR: Invalid HMAC")
        exit(1)
    }

    if let payload = SimplePacketBuilder.extractPayload(packet: packet),
       let text = String(data: payload, encoding: .utf8) {
        print("RECEIVED: \(text)")
    } else {
        print("RECEIVED: \(packet.count) bytes")
    }
    exit(0)
} catch {
    print("ERROR: \(error)")
    exit(1)
}
