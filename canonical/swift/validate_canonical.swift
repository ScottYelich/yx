#!/usr/bin/env swift

import Foundation
import CryptoKit

// Import YXProtocol types manually (copied inline for standalone execution)

struct GUIDFactory {
    static func pad(guid: Data) -> Data {
        if guid.count == 6 {
            return guid
        } else if guid.count < 6 {
            return guid + Data(repeating: 0, count: 6 - guid.count)
        } else {
            return guid.prefix(6)
        }
    }
}

struct DataCrypto {
    static func computePacketHMAC(guid: Data, payload: Data, key: SymmetricKey) -> Data {
        let combined = guid + payload
        let hmac = HMAC<SHA256>.authenticationCode(for: combined, using: key)
        return Data(hmac.prefix(16))
    }
}

struct Packet {
    let hmac: Data
    let guid: Data
    let payload: Data

    func toBytes() -> Data {
        return hmac + guid + payload
    }
}

struct PacketBuilder {
    static func buildPacket(guid: Data, payload: Data, key: SymmetricKey) throws -> Packet {
        let paddedGUID = GUIDFactory.pad(guid: guid)
        let hmac = DataCrypto.computePacketHMAC(guid: paddedGUID, payload: payload, key: key)
        return Packet(hmac: hmac, guid: paddedGUID, payload: payload)
    }
}

// Test vector structures
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

    func toHex() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// Main validation
let testVectorsPath = "../../canonical/test-vectors/text-protocol-packets.json"
let url = URL(fileURLWithPath: testVectorsPath)

guard FileManager.default.fileExists(atPath: url.path) else {
    print("❌ FAILED: Canonical test vectors not found at: \(testVectorsPath)")
    exit(1)
}

do {
    let data = try Data(contentsOf: url)
    let vectors = try JSONDecoder().decode(TestVectors.self, from: data)

    print("🧪 Validating \(vectors.test_cases.count) canonical test vectors...")
    print("")

    var passCount = 0
    var failCount = 0

    for testCase in vectors.test_cases {
        print("Testing: \(testCase.name)")

        guard let guidData = Data(hex: testCase.guid),
              let keyData = Data(hex: testCase.key),
              let expectedHMAC = Data(hex: testCase.expected_hmac),
              let expectedPacket = Data(hex: testCase.expected_packet) else {
            print("  ❌ Failed to parse test case hex data")
            failCount += 1
            continue
        }

        let key = SymmetricKey(data: keyData)

        let payloadData: Data
        if let payloadHex = testCase.payload_hex {
            guard let parsed = Data(hex: payloadHex) else {
                print("  ❌ Failed to parse payload hex")
                failCount += 1
                continue
            }
            payloadData = parsed
        } else {
            payloadData = Data()
        }

        do {
            let packet = try PacketBuilder.buildPacket(guid: guidData, payload: payloadData, key: key)

            // Validate HMAC
            if packet.hmac != expectedHMAC {
                print("  ❌ HMAC MISMATCH")
                print("     Expected: \(expectedHMAC.toHex())")
                print("     Got:      \(packet.hmac.toHex())")
                failCount += 1
                continue
            }

            // Validate full packet
            let actualPacket = packet.toBytes()
            if actualPacket != expectedPacket {
                print("  ❌ PACKET MISMATCH")
                print("     Expected: \(expectedPacket.toHex())")
                print("     Got:      \(actualPacket.toHex())")
                failCount += 1
                continue
            }

            print("  ✅ HMAC matches")
            print("  ✅ Full packet matches")
            passCount += 1

        } catch {
            print("  ❌ Error building packet: \(error)")
            failCount += 1
        }
    }

    print("")
    print(String(repeating: "=", count: 60))
    print("Results: \(passCount) passed, \(failCount) failed out of \(vectors.test_cases.count) total")
    print(String(repeating: "=", count: 60))

    if failCount == 0 {
        print("✅ ALL CANONICAL TEST VECTORS PASSED")
        print("✅ Wire format compatible with Python implementation")
        exit(0)
    } else {
        print("❌ SOME TESTS FAILED")
        exit(1)
    }

} catch {
    print("❌ Error: \(error)")
    exit(1)
}
