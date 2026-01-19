# Step 10: Swift Integration Tests

**Version**: 0.1.0

## Overview

Create end-to-end integration tests for Swift implementation.

## Step Objectives

1. Test complete packet flow
2. Test send/receive (when async supported)
3. Integration test coverage

## Prerequisites

- Step 9 completed (canonical validation passed)

## Traceability

**Implements**: specs/testing/testing-strategy.md § Category 5: Integration Tests

## Instructions

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
