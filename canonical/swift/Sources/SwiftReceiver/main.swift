import Foundation
import YXProtocol
import CryptoKit

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift-receiver <port>")
    exit(1)
}

let port = UInt16(CommandLine.arguments[1])!
let keyData = Data(repeating: 0, count: 32)
let key = SymmetricKey(data: keyData)

do {
    let (data, _, _) = try UDPHelper.receive(port: port, timeout: 30.0)
    guard let packet = PacketBuilder.parseAndValidate(data, key: key) else {
        print("ERROR: Invalid packet (HMAC mismatch or malformed)")
        exit(1)
    }
    if let payload = String(data: packet.payload, encoding: .utf8) {
        print("RECEIVED: \(payload)")
    } else {
        print("ERROR: Could not decode payload as UTF-8")
        exit(1)
    }
} catch {
    print("ERROR: \(error)")
    exit(1)
}
