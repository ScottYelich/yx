// Transport Layer Test Sender: Empty payload
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol
import CryptoKit

// Empty payload test
do {
    let payload = Data() // Empty
    let guid = TestConfig.testGUID
    let key = TestConfig.testKey

    // Build packet manually (transport layer only)
    var message = Data(capacity: guid.count + payload.count)
    message.append(guid)
    message.append(payload)

    // Compute HMAC
    let hmacKey = SymmetricKey(data: key)
    var hmac = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
    hmac = hmac.prefix(16)

    // Build packet
    var packet = Data(capacity: hmac.count + message.count)
    packet.append(hmac)
    packet.append(message)

    // Send
    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
