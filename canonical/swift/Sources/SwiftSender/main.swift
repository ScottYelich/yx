import Foundation
import YXProtocol
import CryptoKit

// Usage: swift-sender <payload> <host> <port> [--key <hex32>]
func usage() -> Never {
    print("Usage: swift-sender <payload> <host> <port> [--key <hex32>]")
    exit(1)
}

var args = CommandLine.arguments.dropFirst()
guard args.count >= 3 else { usage() }

let payloadText = args.removeFirst()
let host = args.removeFirst()
guard let port = UInt16(args.removeFirst()) else { usage() }

// Parse optional --key
var keyData = Data(repeating: 0, count: 32)
var argList = Array(args)
var i = 0
while i < argList.count {
    if argList[i] == "--key", i + 1 < argList.count {
        guard let parsed = Data(hex: argList[i + 1]), parsed.count == 32 else {
            print("ERROR: --key must be 64 hex chars (32 bytes)")
            exit(1)
        }
        keyData = parsed
        i += 2
    } else {
        i += 1
    }
}

let key = SymmetricKey(data: keyData)
let guid = GUIDFactory.generate()
let payload = payloadText.data(using: .utf8)!

do {
    let socket = UDPSocket(port: 0)
    try socket.sendPacket(guid: guid, payload: payload, key: key, host: host, port: port)
    print("SENT: \(payloadText)")
    sleep(1)  // Give time for packet to send via NWConnection
    exit(0)
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
