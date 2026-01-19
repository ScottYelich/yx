# Step 5: Swift Packet Builder

**Version**: 0.1.0

## Overview

Build complete packets with HMAC.

## Step Objectives

1. Build packets with HMAC computation
2. Serialize in one step
3. XCTest unit tests

## Prerequisites

- Step 4 completed

## Traceability

**Implements**: specs/technical/yx-protocol-spec.md § Packet Building

## Instructions

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
