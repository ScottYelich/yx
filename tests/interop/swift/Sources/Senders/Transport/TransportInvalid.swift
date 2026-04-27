// Transport Layer Test Sender: Invalid HMAC (should be rejected)
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol
import CryptoKit

// Invalid HMAC test (should be rejected by receiver)
do {
    let payload = "Invalid packet".data(using: .utf8)!
    let guid = TestConfig.testGUID
    let wrongKey = Data(repeating: 0xFF, count: 32)

    // Build packet with WRONG key - HMAC will be invalid
    var message = Data(capacity: guid.count + payload.count)
    message.append(guid)
    message.append(payload)

    // Compute HMAC with wrong key
    let hmacKey = SymmetricKey(data: wrongKey)
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
