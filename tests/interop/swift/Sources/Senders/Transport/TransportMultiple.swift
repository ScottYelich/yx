// Transport Layer Test Sender: Multiple packets
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol
import CryptoKit

// Multiple packets test
do {
    for i in 0..<5 {
        let payload = "Message \(i)".data(using: .utf8)!
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
        Thread.sleep(forTimeInterval: 0.1) // Small delay
    }

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
