# Step 9: Swift Canonical Artifact Validation

**Version**: 0.1.0

## Overview

Validate Swift implementation against Python-generated canonical test vectors.

## What This Step Builds

Validates the Swift implementation against Python-generated canonical test vectors — loading JSON from `canonical/test-vectors/` and verifying byte-identical HMAC computation and packet serialization.

## Step Objectives

1. Load canonical test vectors
2. Validate Swift produces identical HMACs
3. Validate packet parsing
4. Ensure wire format compatibility

## Prerequisites

- All previous Swift steps completed
- Python canonical artifacts generated

## Traceability

**Implements**: Canonical artifact validation workflow

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Create Validation Test

Create `Tests/YXProtocolTests/Integration/CanonicalValidationTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import YXProtocol

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
        // Load canonical test vectors
        let testVectorsPath = "../../canonical/test-vectors/text-protocol-packets.json"
        let url = URL(fileURLWithPath: testVectorsPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("Canonical test vectors not found. Run Python Step 10 first.")
            return
        }

        let data = try Data(contentsOf: url)
        let vectors = try JSONDecoder().decode(TestVectors.self, from: data)

        print("Validating \\(vectors.test_cases.count) test vectors...")

        for testCase in vectors.test_cases {
            print("Testing: \\(testCase.name)")

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
            XCTAssertEqual(packet.hmac, expectedHMAC, "HMAC mismatch for: \\(testCase.name)")

            // Validate full packet matches
            let expectedPacket = Data(hex: testCase.expected_packet)!
            let actualPacket = packet.toBytes()
            XCTAssertEqual(actualPacket, expectedPacket, "Full packet mismatch for: \\(testCase.name)")

            print("  ✓ HMAC matches")
            print("  ✓ Full packet matches")
        }

        print("✓ All \\(vectors.test_cases.count) test vectors validated")
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
```

### 2. Run Validation

```bash
cd builds/swift-impl
swift test --filter CanonicalValidationTests
```

## Verification

- [ ] Test vectors load
- [ ] All HMACs match Python
- [ ] All packets match Python
- [ ] Wire format compatible

```bash
swift test --filter CanonicalValidationTests
```

## Notes

- This step REQUIRES Python Step 10 completed first
- Validates wire format compatibility
- Ensures Python ↔ Swift interoperability
- Critical for cross-language validation

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_a2b3c4d5e6f7-DONE.txt`:

```
STEP ybs-step_a2b3c4d5e6f7: Swift Canonical Artifact Validation
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- Tests/YXProtocolTests/Integration/CanonicalValidationTests.swift

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_b3c4d5e6f7a2 (Integration Tests)
```

Update `BUILD_STATUS.md`: mark this step `[x]` and update **Last Updated** timestamp.

## Success Criteria

This step is successful when:
1. All verification checks pass (within 3 attempts)
2. All required files exist and are valid
3. Build compiles/runs without errors
4. DONE file created in `docs/build-history/`
5. `BUILD_STATUS.md` updated

## Next Steps

After completing this step, proceed to:
- **Next**: `ybs-step_b3c4d5e6f7a2` — Integration Tests

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
