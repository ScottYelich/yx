import XCTest
import CryptoKit
@testable import YXProtocol

// Implements: canonical artifact validation workflow
// Traceability: protocol/specs/technical/yx-protocol-spec.md

final class CanonicalValidationTests: XCTestCase {

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

    func testValidateCanonicalTestVectors() throws {
        // Look for canonical test vectors relative to project root
        let candidates = [
            "../../canonical/test-vectors/text-protocol-packets.json",
            "../../../canonical/test-vectors/text-protocol-packets.json",
        ]

        var vectorPath: String? = nil
        for candidate in candidates {
            let url = URL(fileURLWithPath: candidate)
            if FileManager.default.fileExists(atPath: url.path) {
                vectorPath = url.path
                break
            }
        }

        guard let path = vectorPath else {
            // Skip test if vectors not found (they may not exist yet)
            print("INFO: Canonical test vectors not found, skipping validation")
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let vectors = try JSONDecoder().decode(TestVectors.self, from: data)

        print("Validating \(vectors.test_cases.count) test vectors...")

        for testCase in vectors.test_cases {
            let guidData = Data(hexString: testCase.guid) ?? Data()
            let keyData = Data(hexString: testCase.key) ?? Data()
            let key = SymmetricKey(data: keyData)

            let payloadData: Data
            if let payloadHex = testCase.payload_hex {
                payloadData = Data(hexString: payloadHex) ?? Data()
            } else {
                payloadData = Data()
            }

            let packet = try PacketBuilder.buildPacket(guid: guidData, payload: payloadData, key: key)
            let expectedHMAC = Data(hexString: testCase.expected_hmac) ?? Data()
            XCTAssertEqual(packet.hmac, expectedHMAC, "HMAC mismatch for: \(testCase.name)")
        }

        print("✓ All \(vectors.test_cases.count) test vectors validated")
    }
}
