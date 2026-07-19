# YBS Step: SimplePacketBuilder.swift and TestConfig.swift

**Step ID:** `ybs-step_sw4a0b1c2d3e`
**Language:** Swift
**Prerequisites:** All sw2x and sw3x steps complete

---

## What This Step Builds

Create two files in `Sources/{{CONFIG:swift_module_name}}/Testing/`:
1. `TestConfig.swift` — shared test configuration
2. `SimplePacketBuilder.swift` — synchronous packet builder for test programs

---

## File 1: `Sources/{{CONFIG:swift_module_name}}/Testing/TestConfig.swift`

```swift
import Foundation

/// Shared test configuration for interop testing.
///
/// Traceability:
/// - protocol/specs/technical/default-values.md (test_port = 49999)
/// - protocol/specs/testing/interoperability-requirements.md (Shared Configuration)
public struct TestConfig {

    /// Test port (default: 49999)
    public static var testPort: UInt16 {
        if let s = ProcessInfo.processInfo.environment["TEST_YX_PORT"], let p = UInt16(s) { return p }
        return 49999
    }

    /// Fixed 6-byte GUID for reproducible tests (0x01 × 6)
    public static var testGUID: Data { Data(repeating: 0x01, count: 6) }

    /// Fixed 32-byte key for reproducible tests (0x00 × 32)
    public static var testKey: Data { Data(repeating: 0x00, count: 32) }
}
```

---

## File 2: `Sources/{{CONFIG:swift_module_name}}/Testing/SimplePacketBuilder.swift`

```swift
import Foundation
import Network

/// Synchronous packet builder for test senders.
///
/// Pattern: Build → Send → Exit (no async needed)
///
/// Traceability:
/// - protocol/specs/architecture/api-contracts.md (SimplePacketBuilder)
public struct SimplePacketBuilder {

    /// Build a Protocol 0 (text/JSON) packet.
    /// Returns: HMAC(16) + GUID(6) + [0x00] + JSON bytes
    public static func buildTextPacket(
        _ message: [String: Any],
        guid: Data,
        key: Data
    ) throws -> Data {
        let json = try JSONSerialization.data(withJSONObject: message)
        var payload = Data([0x00])
        payload.append(json)
        return try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: key)
    }

    /// Build Protocol 1 (binary) packets.
    /// Returns: Array of packets (one per chunk)
    /// Order: compress → encrypt → chunk
    public static func buildBinaryPackets(
        _ data: Data,
        guid: Data,
        key: Data,
        protoOpts: UInt8 = 0x00,
        channelID: UInt16 = 0,
        sequence: UInt32 = 0,
        chunkSize: Int = 1024
    ) throws -> [Data] {
        var processed = data

        if protoOpts & 0x01 != 0 {
            processed = try processed.zlibCompress()
        }
        if protoOpts & 0x02 != 0 {
            let symKey = try Data.symmetricKey(from: key)
            processed = try processed.aesGCMEncrypt(key: symKey)
        }

        let chunks = processed.chunked(size: chunkSize)
        let total = UInt32(chunks.count)

        return try chunks.enumerated().map { (index, chunk) -> Data in
            var header = Data()
            header.append(0x01) // Protocol ID
            header.append(protoOpts)
            withUnsafeBytes(of: channelID.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: sequence.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt32(index).bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: total.bigEndian) { header.append(contentsOf: $0) }
            let payload = header + chunk
            return try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: key)
        }
    }
}

/// Send a single UDP packet synchronously.
public func sendUDPPacket(_ packet: Data, to host: String, port: UInt16) throws {
    let sock = try Socket.createUDP()
    defer { sock.close() }
    try sock.send(packet, to: host, port: port)
}

/// Send multiple UDP packets synchronously.
public func sendUDPPackets(_ packets: [Data], to host: String, port: UInt16) throws {
    let sock = try Socket.createUDP()
    defer { sock.close() }
    for packet in packets {
        try sock.send(packet, to: host, port: port)
    }
}
```

---

## Tests

**File:** `Tests/{{CONFIG:swift_module_name}}Tests/SimplePacketBuilderTests.swift`

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class SimplePacketBuilderTests: XCTestCase {

    func testBuildTextPacket() throws {
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let message: [String: Any] = ["method": "test", "id": 1]

        let packet = try SimplePacketBuilder.buildTextPacket(message, guid: guid, key: key)
        XCTAssertGreaterThanOrEqual(packet.count, 22) // HMAC(16) + GUID(6)

        let parsed = try PacketBuilder.parse(packet)
        XCTAssertNotNil(parsed)
        XCTAssertTrue(try PacketBuilder.validateHMAC(parsed!, key: key))
        XCTAssertEqual(parsed!.payload.first, 0x00) // Protocol 0 marker
    }

    func testBuildBinarySingleChunk() throws {
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let data = "Small data".data(using: .utf8)!

        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x00)
        XCTAssertEqual(packets.count, 1)

        let parsed = try PacketBuilder.parse(packets[0])
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.payload.first, 0x01) // Protocol 1 marker
    }

    func testBuildBinaryMultiChunk() throws {
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let data = Data(repeating: 0xAA, count: 2500)

        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, chunkSize: 1024)
        XCTAssertEqual(packets.count, 3)
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter SimplePacketBuilder
```

All 3 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw4a0b1c2d3e-DONE.txt`:

```
STEP: ybs-step_sw4a0b1c2d3e
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Testing/TestConfig.swift, SimplePacketBuilder.swift, Tests/SimplePacketBuilderTests.swift
VERIFICATION: PASSED
NEXT: ybs-step_sw5a0b1c2d3e
```

Update `BUILD_STATUS.md`: add `- [x] sw4a0b1c2d3e`.
