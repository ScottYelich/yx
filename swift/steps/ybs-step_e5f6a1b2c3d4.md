# Step 5: Swift Packet Builder

**Version**: 0.1.0

## Overview

Build complete packets with HMAC.

## What This Step Builds

Implements `PacketBuilder` struct — assembles authenticated YX packets using CryptoKit for HMAC signing, plus `parse()` and `validate()` for deserializing and verifying received packets.

## Step Objectives

1. Build packets with HMAC computation
2. Serialize in one step
3. XCTest unit tests

## Prerequisites

- Step 4 completed

## Traceability

**Implements**: protocol/specs/technical/yx-protocol-spec.md § Packet Building

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Create Packet Builder

Create `Sources/YXProtocol/Transport/PacketBuilder.swift`:

```swift
import Foundation
import CryptoKit

public struct PacketBuilder {
    public static func buildPacket(guid: Data, payload: Data, key: SymmetricKey) throws -> Packet {
        let paddedGUID = GUIDFactory.pad(guid: guid)
        let hmac = DataCrypto.computePacketHMAC(guid: paddedGUID, payload: payload, key: key)
        return try Packet(hmac: hmac, guid: paddedGUID, payload: payload)
    }

    public static func buildAndSerialize(guid: Data, payload: Data, key: SymmetricKey) throws -> Data {
        let packet = try buildPacket(guid: guid, payload: payload, key: key)
        return packet.toBytes()
    }

    public static func parsePacket(_ data: Data) -> Packet? {
        return Packet.fromBytes(data)
    }

    public static func validateHMAC(_ packet: Packet, key: SymmetricKey) -> Bool {
        return DataCrypto.validatePacketHMAC(guid: packet.guid, payload: packet.payload, key: key, expectedHMAC: packet.hmac)
    }

    public static func parseAndValidate(_ data: Data, key: SymmetricKey) -> Packet? {
        guard let packet = parsePacket(data) else { return nil }
        guard validateHMAC(packet, key: key) else { return nil }
        return packet
    }
}
```

### 2. Create Tests

Create `Tests/YXProtocolTests/Unit/PacketBuilderTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import YXProtocol

final class PacketBuilderTests: XCTestCase {
    func testBuildPacket() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let packet = try PacketBuilder.buildPacket(guid: guid, payload: payload, key: key)

        XCTAssertEqual(packet.guid, guid)
        XCTAssertEqual(packet.payload, payload)
        XCTAssertEqual(packet.hmac.count, 16)
    }

    func testBuildAndSerialize() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        let data = try PacketBuilder.buildAndSerialize(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: key)

        XCTAssertEqual(data.count, 26)
    }

    func testParseAndValidate() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        let data = try PacketBuilder.buildAndSerialize(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: key)
        let packet = PacketBuilder.parseAndValidate(data, key: key)

        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.payload, Data("test".utf8))
    }
}
```

### 3. Run Tests

```bash
swift test --filter PacketBuilderTests
```

## Verification

- [ ] Build works
- [ ] Parse/validate works
- [ ] Tests pass

```bash
swift test --filter PacketBuilderTests
```

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_e5f6a1b2c3d4-DONE.txt`:

```
STEP ybs-step_e5f6a1b2c3d4: Swift Packet Builder
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- Sources/YXProtocol/Transport/PacketBuilder.swift
- Tests/YXProtocolTests/Unit/PacketBuilderTests.swift

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_f6a1b2c3d4e5 (UDP Socket + Send/Receive)
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
- **Next**: `ybs-step_f6a1b2c3d4e5` — UDP Socket + Send/Receive

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
