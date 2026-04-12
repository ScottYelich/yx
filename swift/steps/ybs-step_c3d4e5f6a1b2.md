# Step 3: Swift Packet Structure

**Version**: 0.1.0

## Overview

Implement Packet struct in Swift with wire-format compatibility.

## What This Step Builds

Implements `Packet` struct — the YX wire-format data structure with `hmac: Data`, `guid: Data`, and `payload: Data` fields plus `Data` serialization/deserialization.

## Step Objectives

1. Packet struct (hmac, guid, payload)
2. Serialization/deserialization
3. XCTest unit tests
4. 100% coverage

## Prerequisites

- Step 2 completed

## Traceability

**Implements**: protocol/specs/technical/yx-protocol-spec.md § Wire Format

## Instructions

### Before Starting — Record Start Time

Record the current timestamp in ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`
This is used for duration calculation in the DONE file.

### 1. Create Packet

Create `Sources/YXProtocol/Transport/Packet.swift`:

```swift
import Foundation

public struct Packet {
    public let hmac: Data      // 16 bytes
    public let guid: Data      // 6 bytes
    public let payload: Data   // Variable

    public init(hmac: Data, guid: Data, payload: Data) throws {
        guard hmac.count == 16 else {
            throw PacketError.invalidHMACLength
        }
        guard guid.count == 6 else {
            throw PacketError.invalidGUIDLength
        }

        self.hmac = hmac
        self.guid = guid
        self.payload = payload
    }

    public func toBytes() -> Data {
        return hmac + guid + payload
    }

    public static func fromBytes(_ data: Data) -> Packet? {
        guard data.count >= 22 else { return nil }

        let hmac = data[0..<16]
        let guid = data[16..<22]
        let payload = data[22...]

        return try? Packet(hmac: Data(hmac), guid: Data(guid), payload: Data(payload))
    }
}

public enum PacketError: Error {
    case invalidHMACLength
    case invalidGUIDLength
}
```

### 2. Create Tests

Create `Tests/YXProtocolTests/Unit/PacketTests.swift`:

```swift
import XCTest
@testable import YXProtocol

final class PacketTests: XCTestCase {
    func testCreateValidPacket() throws {
        let packet = try Packet(
            hmac: Data(repeating: 0x00, count: 16),
            guid: Data(repeating: 0x01, count: 6),
            payload: Data("test".utf8)
        )

        XCTAssertEqual(packet.hmac.count, 16)
        XCTAssertEqual(packet.guid.count, 6)
        XCTAssertEqual(packet.payload, Data("test".utf8))
    }

    func testToBytes() throws {
        let packet = try Packet(
            hmac: Data(repeating: 0xaa, count: 16),
            guid: Data(repeating: 0xbb, count: 6),
            payload: Data("test".utf8)
        )

        let data = packet.toBytes()
        XCTAssertEqual(data.count, 26)
        XCTAssertEqual(data[0..<16], Data(repeating: 0xaa, count: 16))
        XCTAssertEqual(data[16..<22], Data(repeating: 0xbb, count: 6))
    }

    func testFromBytes() {
        let data = Data(repeating: 0xaa, count: 16) +
                   Data(repeating: 0xbb, count: 6) +
                   Data("test".utf8)

        let packet = Packet.fromBytes(data)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.payload, Data("test".utf8))
    }

    func testRoundtrip() throws {
        let original = try Packet(
            hmac: Data(repeating: 0x01, count: 16),
            guid: Data(repeating: 0x02, count: 6),
            payload: Data("payload".utf8)
        )

        let data = original.toBytes()
        let restored = Packet.fromBytes(data)

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.hmac, original.hmac)
        XCTAssertEqual(restored?.guid, original.guid)
        XCTAssertEqual(restored?.payload, original.payload)
    }
}
```

### 3. Run Tests

```bash
swift test --filter PacketTests
```

## Verification

- [ ] Tests pass
- [ ] Packet creation works
- [ ] Serialization works
- [ ] Roundtrip works

```bash
swift test --filter PacketTests
```

## Documentation

**Record end time** and calculate duration (end − start timestamp).

Create `docs/build-history/ybs-step_c3d4e5f6a1b2-DONE.txt`:

```
STEP ybs-step_c3d4e5f6a1b2: Swift Packet Structure
STARTED:    [start timestamp from Before Starting]
COMPLETED:  [ISO 8601 timestamp]
DURATION:   [minutes]

OBJECTIVES COMPLETED:
[copy from Step Objectives above]

FILES CREATED/MODIFIED:
- Sources/YXProtocol/Transport/Packet.swift
- Tests/YXProtocolTests/Unit/PacketTests.swift

VERIFICATION: PASSED (attempt [N])

NEXT STEP: ybs-step_d4e5f6a1b2c3 (HMAC Computation (CryptoKit))
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
- **Next**: `ybs-step_d4e5f6a1b2c3` — HMAC Computation (CryptoKit)

## Version History

### 0.1.0 (2026-04-11)
- Initial step creation
