# YBS Step 14 (Swift): SimplePacketBuilder (Test Helpers)

**Step ID:** `ybs-step_j4k5l6m7n8o9`
**Language:** Swift
**System:** YX Protocol
**Focus:** Test helpers for interoperability testing

## Prerequisites

- ✅ Step 13 completed (Security - Replay Protection + Rate Limiting)
- ✅ Python Step 14 completed (reference implementation)
- ✅ Specifications: `specs/architecture/api-contracts.md`

## Overview

Implement **SimplePacketBuilder** - a synchronous test helper pattern that enables clean interop testing.

**Purpose:**
- Build complete YX packets (HMAC + GUID + payload) without async complexity
- Support Protocol 0 (Text) and Protocol 1 (Binary) packet building
- Enable simple sender programs: build → send → exit
- Match Python API exactly for cross-language testing

**Key Insight:**
This pattern took SDTS 3-4 days to discover. The problem: Full YX implementation uses actors/async, making simple test senders complex. Solution: Provide synchronous packet-building utilities that don't require event loops or actors.

**Pattern:**
```swift
// Test sender (simple, synchronous)
let packet = try SimplePacketBuilder.buildTextPacket(message, guid: guid, key: key)
try UDPHelper.send(packet: packet, to: "127.0.0.1", port: 49999)
exit(0)

// Test receiver (full async implementation)
actor Receiver {
    // Full YX stack with protocol routing, etc.
}
```

## Traceability

**Specifications:**
- `specs/architecture/api-contracts.md` § SimplePacketBuilder API
- `specs/architecture/api-contracts.md` § Test Configuration

**Gaps Addressed:**
- Gap 4.8: SimplePacketBuilder pattern
- Gap 5.1: Test helpers
- Gap 6.3: Interop test infrastructure

**SDTS Lessons:**
- Pattern discovery took 3-4 days in SDTS
- Critical for 48-test interop framework
- Enables Python ↔ Swift cross-language testing

## Build Instructions

### 1. Create Test Configuration

**File:** `Sources/{{CONFIG:swift_module_name}}/Testing/TestConfig.swift`

```swift
import Foundation

/// Shared test configuration for interop testing
///
/// Provides standardized test values across Python and Swift implementations
public struct TestConfig {

    /// Test UDP port (can be overridden via environment variable TEST_YX_PORT)
    public static var testPort: UInt16 {
        if let portStr = ProcessInfo.processInfo.environment["TEST_YX_PORT"],
           let port = UInt16(portStr) {
            return port
        }
        return 49999
    }

    /// Test GUID (6 bytes, all 0x01)
    public static var testGUID: Data {
        return Data(repeating: 0x01, count: 6)
    }

    /// Test HMAC key (32 bytes, all 0x00)
    public static var testKey: Data {
        return Data(repeating: 0x00, count: 32)
    }

    /// Test encryption key (32 bytes, all 0x42)
    public static var testEncryptionKey: Data {
        return Data(repeating: 0x42, count: 32)
    }

    /// Test host
    public static var testHost: String {
        return "127.0.0.1"
    }

    /// Default chunk size
    public static var chunkSize: Int {
        return 1024
    }
}
```

**Key Design:**
- Environment variable override for TEST_YX_PORT
- Standardized test values matching Python
- All test programs use these values for consistency

### 2. Create UDP Helper

**File:** `Sources/{{CONFIG:swift_module_name}}/Testing/UDPHelper.swift`

```swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Simple UDP send/receive helpers for testing
///
/// Synchronous, blocking operations - suitable for test programs
public struct UDPHelper {

    /// Send UDP packet
    /// - Parameters:
    ///   - packet: Packet data to send
    ///   - host: Destination host
    ///   - port: Destination port
    /// - Throws: UDPError if send fails
    public static func send(packet: Data, to host: String, port: UInt16) throws {
        // Create socket
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else {
            throw UDPError.socketCreationFailed
        }
        defer {
            close(sock)
        }

        // Setup address
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian

        // Convert host to in_addr
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            throw UDPError.invalidAddress
        }

        // Send packet
        let sent = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(sock, buffer.baseAddress, buffer.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        guard sent >= 0 else {
            throw UDPError.sendFailed
        }
    }

    /// Receive UDP packet (blocking, with timeout)
    /// - Parameters:
    ///   - port: Port to bind to
    ///   - timeout: Receive timeout in seconds (default 5.0)
    /// - Returns: Received packet data and source address
    /// - Throws: UDPError if receive fails
    public static func receive(port: UInt16, timeout: TimeInterval = 5.0) throws -> (data: Data, sourceAddr: String, sourcePort: UInt16) {
        // Create socket
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else {
            throw UDPError.socketCreationFailed
        }
        defer {
            close(sock)
        }

        // Set receive timeout
        var tv = timeval()
        tv.tv_sec = Int(timeout)
        tv.tv_usec = Int32((timeout.truncatingRemainder(dividingBy: 1.0)) * 1_000_000)

        guard setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size)) >= 0 else {
            throw UDPError.socketOptionFailed
        }

        // Bind socket
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult >= 0 else {
            throw UDPError.bindFailed
        }

        // Receive packet
        var buffer = [UInt8](repeating: 0, count: 65536)
        var srcAddr = sockaddr_in()
        var srcAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let received = withUnsafeMutablePointer(to: &srcAddr) { srcAddrPtr in
            srcAddrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                recvfrom(sock, &buffer, buffer.count, 0, sockaddrPtr, &srcAddrLen)
            }
        }

        guard received > 0 else {
            throw UDPError.receiveFailed
        }

        let data = Data(buffer.prefix(received))

        // Extract source address
        var srcAddrStr = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &srcAddr.sin_addr, &srcAddrStr, socklen_t(INET_ADDRSTRLEN))
        let sourceAddr = String(cString: srcAddrStr)
        let sourcePort = UInt16(bigEndian: srcAddr.sin_port)

        return (data, sourceAddr, sourcePort)
    }
}

/// UDP helper errors
public enum UDPError: Error, CustomStringConvertible {
    case socketCreationFailed
    case invalidAddress
    case bindFailed
    case sendFailed
    case receiveFailed
    case socketOptionFailed
    case timeout

    public var description: String {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .invalidAddress:
            return "Invalid address"
        case .bindFailed:
            return "Failed to bind socket"
        case .sendFailed:
            return "Failed to send packet"
        case .receiveFailed:
            return "Failed to receive packet"
        case .socketOptionFailed:
            return "Failed to set socket option"
        case .timeout:
            return "Receive timeout"
        }
    }
}
```

**Key Design:**
- Synchronous, blocking UDP operations
- No async/await - suitable for simple test programs
- Matches Python's socket.sendto() simplicity

### 3. Create SimplePacketBuilder

**File:** `Sources/{{CONFIG:swift_module_name}}/Testing/SimplePacketBuilder.swift`

```swift
import Foundation
import CryptoKit

/// Simplified packet builder for testing
///
/// Builds complete YX packets without requiring async/actor infrastructure.
/// Enables simple test senders: build → send → exit.
///
/// CRITICAL: API must match Python implementation exactly for interop testing.
public struct SimplePacketBuilder {

    /// Build Protocol 0 (Text/JSON-RPC) packet
    /// - Parameters:
    ///   - message: JSON-encodable message
    ///   - guid: GUID (6 bytes)
    ///   - key: HMAC key
    /// - Returns: Complete packet ([HMAC(16)] + [GUID(6)] + [0x00] + [JSON])
    /// - Throws: BuildError if encoding fails
    public static func buildTextPacket<T: Encodable>(message: T, guid: Data, key: Data) throws -> Data {
        // Encode message to JSON
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)

        // Build payload: [0x00] + [JSON]
        var payload = Data(capacity: 1 + jsonData.count)
        payload.append(0x00)
        payload.append(jsonData)

        // Build complete packet: [HMAC] + [GUID] + [payload]
        return try buildPacket(guid: guid, payload: payload, key: key)
    }

    /// Build Protocol 1 (Binary) packets
    /// - Parameters:
    ///   - data: Binary data to send
    ///   - guid: GUID (6 bytes)
    ///   - key: HMAC key
    ///   - protoOpts: Protocol options (0x00=base, 0x01=compress, 0x02=encrypt, 0x03=both)
    ///   - encryptionKey: Encryption key (required if protoOpts & 0x02)
    ///   - channelID: Channel ID (default 0)
    ///   - sequence: Sequence number (default 0)
    ///   - chunkSize: Chunk size (default 1024)
    /// - Returns: Array of complete packets (one per chunk)
    /// - Throws: BuildError if encoding fails
    public static func buildBinaryPackets(
        data: Data,
        guid: Data,
        key: Data,
        protoOpts: UInt8 = 0x00,
        encryptionKey: Data? = nil,
        channelID: UInt16 = 0,
        sequence: UInt32 = 0,
        chunkSize: Int = 1024
    ) throws -> [Data] {
        // Process data (compress → encrypt)
        var processed = data

        // Compress (if protoOpts & 0x01)
        if protoOpts & 0x01 != 0 {
            processed = try processed.zlibCompress()
        }

        // Encrypt (if protoOpts & 0x02)
        if protoOpts & 0x02 != 0 {
            guard let encKey = encryptionKey else {
                throw BuildError.encryptionKeyRequired
            }
            let symmetricKey = try Data.symmetricKey(from: encKey)
            processed = try processed.aesGCMEncrypt(key: symmetricKey)
        }

        // Chunk
        let chunks = processed.chunked(size: chunkSize)
        let totalChunks = UInt32(chunks.count)

        // Build packets
        var packets: [Data] = []
        for (index, chunk) in chunks.enumerated() {
            // Build 16-byte header
            var header = Data(capacity: 16)
            header.append(0x01) // Protocol ID
            header.append(protoOpts) // Protocol options
            withUnsafeBytes(of: channelID.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: sequence.bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: UInt32(index).bigEndian) { header.append(contentsOf: $0) }
            withUnsafeBytes(of: totalChunks.bigEndian) { header.append(contentsOf: $0) }

            // Build payload: [header] + [chunk]
            var payload = Data(capacity: header.count + chunk.count)
            payload.append(header)
            payload.append(chunk)

            // Build complete packet: [HMAC] + [GUID] + [payload]
            let packet = try buildPacket(guid: guid, payload: payload, key: key)
            packets.append(packet)
        }

        return packets
    }

    /// Build complete packet with HMAC
    /// - Parameters:
    ///   - guid: GUID (6 bytes)
    ///   - payload: Payload data
    ///   - key: HMAC key
    /// - Returns: Complete packet ([HMAC(16)] + [GUID(6)] + [payload])
    private static func buildPacket(guid: Data, payload: Data, key: Data) throws -> Data {
        // Build message: [GUID] + [payload]
        var message = Data(capacity: guid.count + payload.count)
        message.append(guid)
        message.append(payload)

        // Compute HMAC-SHA256
        let hmacKey = SymmetricKey(data: key)
        var hmac = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))

        // Truncate to 16 bytes
        hmac = hmac.prefix(16)

        // Build final packet: [HMAC(16)] + [GUID] + [payload]
        var packet = Data(capacity: hmac.count + message.count)
        packet.append(hmac)
        packet.append(message)

        return packet
    }

    /// Verify packet HMAC
    /// - Parameters:
    ///   - packet: Complete packet
    ///   - key: HMAC key
    /// - Returns: true if HMAC valid, false otherwise
    public static func verifyPacket(packet: Data, key: Data) -> Bool {
        guard packet.count >= 22 else { // 16 (HMAC) + 6 (GUID)
            return false
        }

        // Extract components
        let receivedHMAC = packet.prefix(16)
        let message = packet.suffix(from: 16)

        // Compute expected HMAC
        let hmacKey = SymmetricKey(data: key)
        var expectedHMAC = Data(HMAC<SHA256>.authenticationCode(for: message, using: hmacKey))
        expectedHMAC = expectedHMAC.prefix(16)

        // Constant-time comparison
        return receivedHMAC == expectedHMAC
    }

    /// Extract GUID from packet
    /// - Parameter packet: Complete packet
    /// - Returns: GUID (6 bytes) or nil if packet invalid
    public static func extractGUID(packet: Data) -> Data? {
        guard packet.count >= 22 else {
            return nil
        }
        return packet[16..<22]
    }

    /// Extract payload from packet (after HMAC and GUID)
    /// - Parameter packet: Complete packet
    /// - Returns: Payload or nil if packet invalid
    public static func extractPayload(packet: Data) -> Data? {
        guard packet.count >= 22 else {
            return nil
        }
        return packet.suffix(from: 22)
    }
}

/// Build errors
public enum BuildError: Error, CustomStringConvertible {
    case encodingFailed
    case encryptionKeyRequired
    case invalidGUID
    case invalidKey

    public var description: String {
        switch self {
        case .encodingFailed:
            return "Failed to encode message"
        case .encryptionKeyRequired:
            return "Encryption key required when protoOpts includes encryption"
        case .invalidGUID:
            return "Invalid GUID (must be 6 bytes)"
        case .invalidKey:
            return "Invalid key"
        }
    }
}
```

**Key Design:**
- No actors, no async - pure synchronous functions
- Matches Python API exactly (same parameters, same order)
- Supports both Protocol 0 (Text) and Protocol 1 (Binary)
- Handles compression and encryption
- Helper functions for packet verification

### 4. Create Example Sender Program

**File:** `Sources/TestSender/main.swift` (example executable)

```swift
import Foundation
import {{CONFIG:swift_module_name}}

// Simple test sender: Build → Send → Exit
do {
    // Build message
    let message: [String: Any] = [
        "jsonrpc": "2.0",
        "method": "test.hello",
        "params": ["name": "SwiftSender"],
        "id": 1
    ]

    // Convert to encodable type
    struct RPCRequest: Codable {
        let jsonrpc: String
        let method: String
        let params: [String: String]
        let id: Int
    }

    let request = RPCRequest(
        jsonrpc: "2.0",
        method: "test.hello",
        params: ["name": "SwiftSender"],
        id: 1
    )

    // Build packet
    let packet = try SimplePacketBuilder.buildTextPacket(
        message: request,
        guid: TestConfig.testGUID,
        key: TestConfig.testKey
    )

    // Send packet
    try UDPHelper.send(
        packet: packet,
        to: TestConfig.testHost,
        port: TestConfig.testPort
    )

    print("SENT")
    exit(0)

} catch {
    print("ERROR: \(error)")
    exit(1)
}
```

**Usage:**
```bash
swift run TestSender
# Output: SENT
```

## Verification

### Unit Tests

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Testing/SimplePacketBuilderTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class SimplePacketBuilderTests: XCTestCase {

    func testBuildTextPacket() throws {
        struct Message: Codable {
            let method: String
            let id: Int
        }

        let message = Message(method: "test.echo", id: 1)
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey

        let packet = try SimplePacketBuilder.buildTextPacket(message: message, guid: guid, key: key)

        // Verify packet structure
        XCTAssertGreaterThanOrEqual(packet.count, 22) // HMAC + GUID + Protocol ID

        // Verify HMAC
        XCTAssertTrue(SimplePacketBuilder.verifyPacket(packet: packet, key: key))

        // Verify GUID
        XCTAssertEqual(SimplePacketBuilder.extractGUID(packet: packet), guid)

        // Verify protocol ID (0x00)
        let payload = SimplePacketBuilder.extractPayload(packet: packet)!
        XCTAssertEqual(payload[0], 0x00)
    }

    func testBuildBinaryPacketSingleChunk() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey

        let packets = try SimplePacketBuilder.buildBinaryPackets(
            data: data,
            guid: guid,
            key: key,
            protoOpts: 0x00,
            channelID: 0,
            sequence: 0,
            chunkSize: 1024
        )

        XCTAssertEqual(packets.count, 1)

        // Verify packet
        let packet = packets[0]
        XCTAssertTrue(SimplePacketBuilder.verifyPacket(packet: packet, key: key))

        // Verify protocol ID (0x01)
        let payload = SimplePacketBuilder.extractPayload(packet: packet)!
        XCTAssertEqual(payload[0], 0x01)
    }

    func testBuildBinaryPacketMultipleChunks() throws {
        let data = Data(repeating: 0xAB, count: 2500)
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey

        let packets = try SimplePacketBuilder.buildBinaryPackets(
            data: data,
            guid: guid,
            key: key,
            protoOpts: 0x00,
            channelID: 0,
            sequence: 0,
            chunkSize: 1024
        )

        XCTAssertEqual(packets.count, 3)

        // Verify all packets
        for packet in packets {
            XCTAssertTrue(SimplePacketBuilder.verifyPacket(packet: packet, key: key))
        }
    }

    func testBuildBinaryPacketCompressed() throws {
        let data = Data(repeating: 0xCC, count: 1000)
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey

        let packets = try SimplePacketBuilder.buildBinaryPackets(
            data: data,
            guid: guid,
            key: key,
            protoOpts: 0x01, // Compressed
            channelID: 0,
            sequence: 0
        )

        // Compressed data should be smaller
        let totalSize = packets.reduce(0) { $0 + $1.count }
        XCTAssertLessThan(totalSize, data.count + 100)
    }

    func testBuildBinaryPacketEncrypted() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let encKey = TestConfig.testEncryptionKey

        let packets = try SimplePacketBuilder.buildBinaryPackets(
            data: data,
            guid: guid,
            key: key,
            protoOpts: 0x02, // Encrypted
            encryptionKey: encKey,
            channelID: 0,
            sequence: 0
        )

        XCTAssertEqual(packets.count, 1)
        XCTAssertTrue(SimplePacketBuilder.verifyPacket(packet: packets[0], key: key))
    }

    func testBuildBinaryPacketCompressedAndEncrypted() throws {
        let data = Data(repeating: 0xDD, count: 1000)
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let encKey = TestConfig.testEncryptionKey

        let packets = try SimplePacketBuilder.buildBinaryPackets(
            data: data,
            guid: guid,
            key: key,
            protoOpts: 0x03, // Both
            encryptionKey: encKey,
            channelID: 0,
            sequence: 0
        )

        XCTAssertGreaterThan(packets.count, 0)

        // Verify all packets
        for packet in packets {
            XCTAssertTrue(SimplePacketBuilder.verifyPacket(packet: packet, key: key))
        }
    }

    func testVerifyPacket() throws {
        let message = ["method": "test"]
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey

        let packet = try SimplePacketBuilder.buildTextPacket(message: message, guid: guid, key: key)

        // Valid key
        XCTAssertTrue(SimplePacketBuilder.verifyPacket(packet: packet, key: key))

        // Invalid key
        let wrongKey = Data(repeating: 0xFF, count: 32)
        XCTAssertFalse(SimplePacketBuilder.verifyPacket(packet: packet, key: wrongKey))
    }

    func testExtractGUID() throws {
        let message = ["method": "test"]
        let guid = Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
        let key = TestConfig.testKey

        let packet = try SimplePacketBuilder.buildTextPacket(message: message, guid: guid, key: key)

        let extracted = SimplePacketBuilder.extractGUID(packet: packet)
        XCTAssertEqual(extracted, guid)
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Testing/UDPHelperTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class UDPHelperTests: XCTestCase {

    func testSendAndReceive() throws {
        let testPort: UInt16 = 55555
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])

        // Start receiver in background
        let receiverTask = Task {
            return try UDPHelper.receive(port: testPort, timeout: 3.0)
        }

        // Give receiver time to bind
        Thread.sleep(forTimeInterval: 0.1)

        // Send packet
        try UDPHelper.send(packet: testData, to: "127.0.0.1", port: testPort)

        // Wait for receiver
        let (receivedData, _, _) = try receiverTask.value

        XCTAssertEqual(receivedData, testData)
    }
}
```

### Integration Test

Create `Tests/{{CONFIG:swift_module_name}}Tests/Integration/SimplePacketBuilderIntegrationTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class SimplePacketBuilderIntegrationTests: XCTestCase {

    func testBuildAndSendTextPacket() throws {
        struct Message: Codable {
            let method: String
            let id: Int
        }

        let message = Message(method: "test.integration", id: 42)

        // Build packet
        let packet = try SimplePacketBuilder.buildTextPacket(
            message: message,
            guid: TestConfig.testGUID,
            key: TestConfig.testKey
        )

        // Verify packet structure
        XCTAssertTrue(SimplePacketBuilder.verifyPacket(packet: packet, key: TestConfig.testKey))

        // Extract and verify payload
        let payload = SimplePacketBuilder.extractPayload(packet: packet)!
        XCTAssertEqual(payload[0], 0x00) // Protocol 0

        // Decode JSON
        let jsonData = payload.suffix(from: 1)
        let decoded = try JSONDecoder().decode(Message.self, from: jsonData)
        XCTAssertEqual(decoded.method, "test.integration")
        XCTAssertEqual(decoded.id, 42)
    }
}
```

### Success Criteria

- [ ] All 10+ tests pass
- [ ] Text packet building works
- [ ] Binary packet building works (all protoOpts: 0x00, 0x01, 0x02, 0x03)
- [ ] Multi-chunk packets build correctly
- [ ] HMAC verification works
- [ ] GUID extraction works
- [ ] UDP send/receive works
- [ ] Integration test demonstrates full build → verify flow
- [ ] API matches Python implementation exactly
- [ ] Code coverage ≥ 80%

### Run Tests

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter SimplePacketBuilder
swift test --filter UDPHelper
swift test --filter Integration
```

## Implementation Notes

### Why SimplePacketBuilder?

**Problem:** Full YX implementation uses actors and async/await, making simple test senders complex.

**Solution:** Provide synchronous packet-building utilities that:
- Don't require event loops or actors
- Can be used in simple command-line programs
- Enable test pattern: build → send → exit

**SDTS Discovery:** This pattern took 3-4 days to discover during SDTS development.

### API Compatibility

**CRITICAL:** API must match Python implementation exactly:

| Python | Swift | Notes |
|--------|-------|-------|
| `SimplePacketBuilder.build_text_packet(message, guid, key)` | `SimplePacketBuilder.buildTextPacket(message:guid:key:)` | Same parameters |
| `SimplePacketBuilder.build_binary_packet(data, guid, key, proto_opts, ...)` | `SimplePacketBuilder.buildBinaryPackets(data:guid:key:protoOpts:...)` | Same parameters |
| `send_udp_packet(packet, host, port)` | `UDPHelper.send(packet:to:port:)` | Similar signature |
| `TestConfig.test_port()` | `TestConfig.testPort` | Property vs function |

### Test Configuration

All test programs use `TestConfig` for consistent values:
- Port: 49999 (override with TEST_YX_PORT env var)
- GUID: 6 bytes of 0x01
- HMAC key: 32 bytes of 0x00
- Encryption key: 32 bytes of 0x42

This ensures Python and Swift test programs interoperate.

## Traceability Matrix

| Gap ID | Specification | Implementation | Tests |
|--------|---------------|----------------|-------|
| 4.8 | api-contracts.md § SimplePacketBuilder | SimplePacketBuilder.swift | SimplePacketBuilderTests.swift |
| 5.1 | api-contracts.md § Test Helpers | UDPHelper.swift | UDPHelperTests.swift |
| 6.3 | api-contracts.md § Test Config | TestConfig.swift | Integration tests |

## Next Steps

After completing this step:

1. ✅ Protocol 0 (Text/JSON-RPC) working
2. ✅ Protocol 1 (Binary/Chunked) working
3. ✅ Security (Replay Protection + Rate Limiting) working
4. ✅ SimplePacketBuilder (Test Helpers) working
5. ⏭️ **Next:** Step 15 - Interoperability Test Suite (48 tests)

## References

- `specs/architecture/api-contracts.md` - SimplePacketBuilder API
- Python Step 14: `steps/python/ybs-step_j4k5l6m7n8o9.md`
- SDTS experience: Pattern took 3-4 days to discover
