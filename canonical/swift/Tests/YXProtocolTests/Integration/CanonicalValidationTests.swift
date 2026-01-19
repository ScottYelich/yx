import Testing
import CryptoKit
@testable import YXProtocol

@Suite struct CanonicalValidationTests {
    struct TestCase: Codable {
        let name: String
        let guid: String
        let key: String
        let payload_hex: String?
        let expected_hmac: String
        let expected_packet: String
    }

    struct TestVectors: Codable {
        let version: String
        let test_cases: [TestCase]
    }

    @Test func validateCanonicalTestVectors() throws {
        // Load canonical test vectors
        let testVectorsPath = "../../canonical/test-vectors/text-protocol-packets.json"
        let url = URL(fileURLWithPath: testVectorsPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            Issue.record("Canonical test vectors not found. Run Python Step 10 first.")
            return
        }

        let data = try Data(contentsOf: url)
        let vectors = try JSONDecoder().decode(TestVectors.self, from: data)

        print("Validating \(vectors.test_cases.count) test vectors...")

        for testCase in vectors.test_cases {
            print("Testing: \(testCase.name)")

            // Parse test case
            let guidData = Data(hex: testCase.guid)!
            let keyData = Data(hex: testCase.key)!
            let key = SymmetricKey(data: keyData)

            let payloadData: Data
            if let payloadHex = testCase.payload_hex {
                payloadData = Data(hex: payloadHex)!
            } else {
                payloadData = Data()
            }

            // Build packet with Swift
            let packet = try PacketBuilder.buildPacket(guid: guidData, payload: payloadData, key: key)

            // Validate HMAC matches
            let expectedHMAC = Data(hex: testCase.expected_hmac)!
            #expect(packet.hmac == expectedHMAC, "HMAC mismatch for: \(testCase.name)")

            // Validate full packet matches
            let expectedPacket = Data(hex: testCase.expected_packet)!
            let actualPacket = packet.toBytes()
            #expect(actualPacket == expectedPacket, "Full packet mismatch for: \(testCase.name)")

            print("  ✓ HMAC matches")
            print("  ✓ Full packet matches")
        }

        print("✓ All \(vectors.test_cases.count) test vectors validated")
    }
}

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
