// Protocol 0 Test Sender: Invalid JSON (should be rejected)
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol
import CryptoKit

// Protocol 0: Invalid JSON (should be rejected)
do {
    // Manually construct invalid JSON payload
    let invalidJSON = "{invalid json}".data(using: .utf8)!

    var payload = Data(capacity: 1 + invalidJSON.count)
    payload.append(0x00) // Protocol 0
    payload.append(invalidJSON)

    // Build packet with HMAC
    let guid = TestConfig.testGUID
    let key = TestConfig.testKey

    var message = Data(capacity: guid.count + payload.count)
    message.append(guid)
    message.append(payload)

    let hmacKey = SymmetricKey(data: key)
    var hmac = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
    hmac = hmac.prefix(16)

    var packet = Data(capacity: hmac.count + message.count)
    packet.append(hmac)
    packet.append(message)

    try UDPHelper.send(packet: packet, to: TestConfig.testHost, port: TestConfig.testPort)

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
