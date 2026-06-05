// Protocol 0 Receiver - decodes JSON-RPC
// Traceability: specs/testing/interoperability-requirements.md

import Foundation
import YXProtocol
import CryptoKit

// Protocol 0 receiver - decodes JSON-RPC
do {
    print("Listening on port \(TestConfig.testPort)...")

    let (packet, sourceAddr, sourcePort) = try UDPHelper.receive(
        port: TestConfig.testPort,
        timeout: 10.0
    )

    print("Received packet from \(sourceAddr):\(sourcePort)")

    // Verify packet structure
    guard packet.count >= 22 else {
        print("ERROR: Packet too small")
        exit(1)
    }

    // Extract and verify HMAC. Wrap slices in Data(...) to rebase indices to 0;
    // Data slices keep absolute indices, so literal-offset slicing on a slice
    // traps (SIGTRAP) once startIndex != 0.
    let receivedHMAC = packet.prefix(16)
    let message = Data(packet.suffix(from: 16))

    let hmacKey = SymmetricKey(data: TestConfig.testKey)
    var expectedHMAC = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
    expectedHMAC = expectedHMAC.prefix(16)

    guard receivedHMAC == expectedHMAC else {
        print("ERROR: Invalid HMAC")
        exit(1)
    }

    // Extract payload (skip GUID); rebase to 0 so payload[0]/suffix work.
    let payload = Data(message.suffix(from: 6))

    // Verify protocol ID
    guard payload.count > 0, payload[0] == 0x00 else {
        print("ERROR: Expected protocol ID 0x00")
        exit(1)
    }

    // Extract JSON
    let jsonData = payload.suffix(from: 1)

    // Try to decode as JSON
    if let json = try? JSONSerialization.jsonObject(with: jsonData) {
        print("RECEIVED: Valid JSON")
        if let dict = json as? [String: Any] {
            if let method = dict["method"] as? String {
                print("Method: \(method)")
            }
        }
        exit(0)
    } else {
        print("ERROR: Invalid JSON")
        exit(1)
    }

} catch {
    print("ERROR: \(error)")
    exit(1)
}
