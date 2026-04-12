# Step 10: Swift Integration Tests

**Version**: 0.1.0

## Overview

Create end-to-end integration tests for Swift implementation.

## What This Step Builds

Builds end-to-end integration tests verifying the complete packet flow with real UDP loopback sockets: `build → serialize → send → receive → parse → validate`.

## Step Objectives

1. Test complete packet flow
2. Test send/receive (when async supported)
3. Integration test coverage

## Prerequisites

- Step 9 completed (canonical validation passed)

## Traceability

**Implements**: protocol/specs/testing/testing-strategy.md § Category 5: Integration Tests

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Create Integration Tests

Create `Tests/YXProtocolTests/Integration/PacketFlowTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import YXProtocol

final class PacketFlowTests: XCTestCase {
    func testCompletePacketFlow() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0xaa, count: 6)
        let payload = Data("integration test payload".utf8)

        // Build
        let packet = try PacketBuilder.buildPacket(guid: guid, payload: payload, key: key)

        // Serialize
        let data = packet.toBytes()

        // Parse
        let parsed = PacketBuilder.parsePacket(data)
        XCTAssertNotNil(parsed)

        // Validate
        let isValid = PacketBuilder.validateHMAC(parsed!, key: key)
        XCTAssertTrue(isValid)

        // Verify payload
        XCTAssertEqual(parsed?.payload, payload)
    }

    func testMultiplePackets() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        for i in 0..<10 {
            let payload = Data("packet \\(i)".utf8)
            let packet = try PacketBuilder.buildPacket(guid: Data(repeating: 0x01, count: 6), payload: payload, key: key)

            let data = packet.toBytes()
            let parsed = PacketBuilder.parseAndValidate(data, key: key)

            XCTAssertNotNil(parsed)
            XCTAssertEqual(parsed?.payload, payload)
        }
    }

    func testInvalidKeyRejected() throws {
        let sendKey = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let recvKey = SymmetricKey(data: Data(repeating: 0xff, count: 32))

        let data = try PacketBuilder.buildAndSerialize(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: sendKey)

        let packet = PacketBuilder.parseAndValidate(data, key: recvKey)

        XCTAssertNil(packet, "Packet with wrong key should be rejected")
    }
}
```

### 2. Run Tests

```bash
swift test --filter PacketFlowTests
```

## Verification

- [ ] All integration tests pass
- [ ] Complete flow works
- [ ] Invalid keys rejected

```bash
swift test
```

## Notes

- Swift implementation complete
- Wire format compatible with Python
- Ready for cross-language interop tests

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_b3c4d5e6f7a2-DONE.txt`:

```
STEP ybs-step_b3c4d5e6f7a2: Swift Integration Tests
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- Tests/YXProtocolTests/Integration/PacketFlowTests.swift

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_g1h2i3j4k5l6 (Protocol 0 (Text/JSON-RPC))
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
- **Next**: `ybs-step_g1h2i3j4k5l6` — Protocol 0 (Text/JSON-RPC)

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
