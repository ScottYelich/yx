import Foundation
import YXProtocol
import CryptoKit

// Usage: swift-receiver <port> [--key <hex32>] [--timeout <seconds>]
func usage() -> Never {
    print("Usage: swift-receiver <port> [--key <hex32>] [--timeout <seconds>]")
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else { usage() }
guard let port = UInt16(args.removeFirst()) else { usage() }

// Parse optional flags
var keyData = Data(repeating: 0, count: 32)
var timeout: TimeInterval = 5.0
var i = 0
while i < args.count {
    if args[i] == "--key", i + 1 < args.count {
        guard let parsed = Data(hex: args[i + 1]), parsed.count == 32 else {
            print("ERROR: --key must be 64 hex chars (32 bytes)")
            exit(1)
        }
        keyData = parsed
        i += 2
    } else if args[i] == "--timeout", i + 1 < args.count {
        timeout = TimeInterval(args[i + 1]) ?? 5.0
        i += 2
    } else {
        i += 1
    }
}

let key = SymmetricKey(data: keyData)

do {
    let (data, _, _) = try UDPHelper.receive(port: port, timeout: timeout)
    guard let packet = PacketBuilder.parseAndValidate(data, key: key) else {
        print("ERROR: Invalid packet (HMAC mismatch or malformed)")
        exit(1)
    }
    if let payload = String(data: packet.payload, encoding: .utf8) {
        print("RECEIVED: \(payload)")
        exit(0)
    } else {
        print("ERROR: Could not decode payload as UTF-8")
        exit(1)
    }
} catch {
    print("ERROR: \(error)")
    exit(1)
}

// MARK: - Hex extension

extension Data {
    init?(hex: String) {
        var data = Data()
        var hex = hex
        while hex.count >= 2 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let byteString = String(hex[..<index])
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            hex = String(hex[index...])
        }
        self = data
    }
}
