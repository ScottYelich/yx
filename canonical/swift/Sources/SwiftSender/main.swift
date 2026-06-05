import Foundation
import CryptoKit
import YXProtocol

// Minimal demo sender: build a transport packet ([HMAC] + [GUID] + [payload])
// and send it over UDP using the POSIX UDPHelper (matches SwiftReceiver).
guard CommandLine.arguments.count >= 4 else {
    print("Usage: swift-sender <payload> <host> <port>")
    exit(1)
}

let payloadText = CommandLine.arguments[1]
let host = CommandLine.arguments[2]
let port = UInt16(CommandLine.arguments[3]) ?? TestConfig.testPort

let guid = TestConfig.testGUID
let key = SymmetricKey(data: TestConfig.testKey)
let payload = Data(payloadText.utf8)

do {
    let packet = try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: key)
    try UDPHelper.send(packet: packet, to: host, port: port)
    print("SENT: \(payloadText)")
    exit(0)
} catch {
    print("ERROR: \(error)")
    exit(1)
}
