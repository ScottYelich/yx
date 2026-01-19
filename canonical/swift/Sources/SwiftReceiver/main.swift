import Foundation
import YXProtocol
import Network
import CryptoKit

// Get port from command line
guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift-receiver <port>")
    exit(1)
}

let port = UInt16(CommandLine.arguments[1])!
let keyData = Data(repeating: 0, count: 32)
let key = SymmetricKey(data: keyData)

do {
    let socket = UDPSocket(port: port)
    try socket.bind()

    if let packet = try socket.receivePacket(key: key, timeout: 3.0) {
        if let payload = String(data: packet.payload, encoding: .utf8) {
            print("RECEIVED: \(payload)")
        } else {
            print("ERROR: Could not decode payload")
            exit(1)
        }
    } else {
        print("ERROR: No packet received")
        exit(1)
    }
} catch {
    print("ERROR: \(error)")
    exit(1)
}
