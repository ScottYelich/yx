import Foundation
import YXProtocol
import Network
import CryptoKit

// Get payload from command line
guard CommandLine.arguments.count >= 4 else {
    print("Usage: swift-sender <payload> <host> <port>")
    exit(1)
}

let payloadText = CommandLine.arguments[1]
let host = CommandLine.arguments[2]
let port = UInt16(CommandLine.arguments[3])!

let guid = GUIDFactory.generate()
let keyData = Data(repeating: 0, count: 32)
let key = SymmetricKey(data: keyData)
let payload = payloadText.data(using: .utf8)!

do {
    let socket = UDPSocket(port: 0)  // Random sender port
    try socket.sendPacket(guid: guid, payload: payload, key: key, host: host, port: port)
    print("SENT: \(payloadText)")
    sleep(1)  // Give time for packet to send
} catch {
    print("ERROR: \(error)")
    exit(1)
}
