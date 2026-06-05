// Transport Layer Receiver - verifies HMAC and extracts payload
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol
import CryptoKit

// Transport layer receiver - verifies HMAC and extracts payload
do {
    print("Listening on port \(TestConfig.testPort)...")

    let (packet, sourceAddr, sourcePort) = try UDPHelper.receive(
        port: TestConfig.testPort,
        timeout: 10.0
    )

    print("Received packet from \(sourceAddr):\(sourcePort)")

    // Verify packet structure
    guard packet.count >= 22 else { // 16 (HMAC) + 6 (GUID)
        print("ERROR: Packet too small")
        exit(1)
    }

    // Extract components. Wrap slices in Data(...) to rebase indices to 0 —
    // Data slices keep absolute indices, so chaining prefix/suffix with literal
    // offsets on a slice traps (SIGTRAP) once startIndex != 0.
    let receivedHMAC = packet.prefix(16)
    let message = Data(packet.suffix(from: 16))

    // Compute expected HMAC
    let hmacKey = SymmetricKey(data: TestConfig.testKey)
    var expectedHMAC = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
    expectedHMAC = expectedHMAC.prefix(16)

    // Constant-time comparison
    if receivedHMAC == expectedHMAC {
        // Extract GUID and payload
        let guid = message.prefix(6)
        let payload = message.suffix(from: 6)

        print("RECEIVED: \(payload.count) bytes (GUID: \(guid.map { String(format: "%02X", $0) }.joined()))")
        exit(0)
    } else {
        print("ERROR: Invalid HMAC")
        exit(1)
    }

} catch {
    print("ERROR: \(error)")
    exit(1)
}
