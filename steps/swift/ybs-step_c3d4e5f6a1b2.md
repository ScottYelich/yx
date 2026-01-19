# Step 3: Swift Packet Structure

**Version**: 0.1.0

## Overview

Implement Packet struct in Swift with wire-format compatibility.

## Step Objectives

1. Packet struct (hmac, guid, payload)
2. Serialization/deserialization
3. XCTest unit tests
4. 100% coverage

## Prerequisites

- Step 2 completed

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § Wire Format

## Instructions

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
