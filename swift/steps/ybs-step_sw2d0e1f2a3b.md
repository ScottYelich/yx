# YBS Step: BinaryProtocol.swift

**Step ID:** `ybs-step_sw2d0e1f2a3b`
**Language:** Swift
**Prerequisites:** Steps sw2a, sw2b, sw2c complete (AES-GCM, DataCompression, DataChunking)

---

## What This Step Builds

Create `Sources/{{CONFIG:swift_module_name}}/Transport/BinaryProtocol.swift` — Protocol 1 binary/chunked actor.

---

## Implementation

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/BinaryProtocol.swift`

```swift
import Foundation
import CryptoKit

/// Protocol 1: Binary/Chunked handler (v2.0)
///
/// Header format (16 bytes):
/// [proto(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] +
/// [chunkIndex(4)] + [totalChunks(4)]
///
/// protoOpts: 0x00=base, 0x01=compressed, 0x02=encrypted, 0x03=both
actor BinaryProtocol {

    static let protocolID: UInt8 = 0x01
    static let headerSize = 16

    private let key: SymmetricKey?
    private let onMessage: (Data) async -> Void
    private let chunkSize: Int
    private let bufferTimeout: TimeInterval

    // (channelID, sequence) -> BufferEntry
    private var buffers: [UInt64: BufferEntry] = [:]
    private var processed: [UInt64: Date] = [:]
    private var sequences: [UInt16: UInt32] = [:]

    init(key: Data? = nil,
         onMessage: @escaping (Data) async -> Void,
         chunkSize: Int = 1024,
         bufferTimeout: TimeInterval = 60.0) {
        self.key = key.flatMap { try? Data.symmetricKey(from: $0) }
        self.onMessage = onMessage
        self.chunkSize = chunkSize
        self.bufferTimeout = bufferTimeout
    }

    /// Handle incoming Protocol 1 payload.
    func handle(payload: Data) async throws {
        guard payload.count >= Self.headerSize, payload[0] == Self.protocolID else { return }
        let header = try parseHeader(payload)
        let data = payload.dropFirst(Self.headerSize)
        let bufKey = makeKey(channelID: header.channelID, sequence: header.sequence)

        if processed[bufKey] != nil { return } // duplicate

        if header.totalChunks == 1 {
            let msg = try processMessage(Data(data), protoOpts: header.protoOpts)
            await onMessage(msg)
            processed[bufKey] = Date()
        } else {
            if buffers[bufKey] == nil {
                buffers[bufKey] = BufferEntry(chunks: [:], totalChunks: header.totalChunks, timestamp: Date())
            }
            buffers[bufKey]!.chunks[header.chunkIndex] = Data(data)
            if buffers[bufKey]!.isComplete {
                let reassembled = try buffers[bufKey]!.reassemble()
                let msg = try processMessage(reassembled, protoOpts: header.protoOpts)
                await onMessage(msg)
                processed[bufKey] = Date()
                buffers.removeValue(forKey: bufKey)
            }
        }
        if buffers.count > 10 { cleanupBuffers() }
    }

    /// Encode data for sending as Protocol 1 packets.
    func encode(data: Data, protoOpts: UInt8 = 0x00, channelID: UInt16 = 0) throws -> [Data] {
        let sequence = nextSequence(channelID: channelID)
        var processed = data
        if protoOpts & 0x01 != 0 { processed = try processed.zlibCompress() }
        if protoOpts & 0x02 != 0 {
            guard let key = key else { throw ProtocolError.missingKey }
            processed = try processed.aesGCMEncrypt(key: key)
        }
        let chunks = processed.chunked(size: chunkSize)
        let total = UInt32(chunks.count)
        return try chunks.enumerated().map { (index, chunk) in
            try buildPacket(proto: Self.protocolID, protoOpts: protoOpts,
                            channelID: channelID, sequence: sequence,
                            chunkIndex: UInt32(index), totalChunks: total, data: chunk)
        }
    }

    private func processMessage(_ data: Data, protoOpts: UInt8) throws -> Data {
        var result = data
        if protoOpts & 0x02 != 0 {
            guard let key = key else { throw ProtocolError.missingKey }
            result = try result.aesGCMDecrypt(key: key)
        }
        if protoOpts & 0x01 != 0 { result = try result.zlibDecompress() }
        return result
    }

    private func nextSequence(channelID: UInt16) -> UInt32 {
        let seq = sequences[channelID, default: 0]
        sequences[channelID] = seq + 1
        return seq
    }

    private func makeKey(channelID: UInt16, sequence: UInt32) -> UInt64 {
        return UInt64(channelID) << 32 | UInt64(sequence)
    }

    private func parseHeader(_ payload: Data) throws -> BinaryHeader {
        return payload.withUnsafeBytes { buf in
            let proto = buf.load(fromByteOffset: 0, as: UInt8.self)
            let protoOpts = buf.load(fromByteOffset: 1, as: UInt8.self)
            let channelID = UInt16(bigEndian: buf.load(fromByteOffset: 2, as: UInt16.self))
            let sequence = UInt32(bigEndian: buf.load(fromByteOffset: 4, as: UInt32.self))
            let chunkIndex = UInt32(bigEndian: buf.load(fromByteOffset: 8, as: UInt32.self))
            let totalChunks = UInt32(bigEndian: buf.load(fromByteOffset: 12, as: UInt32.self))
            return BinaryHeader(proto: proto, protoOpts: protoOpts,
                                channelID: channelID, sequence: sequence,
                                chunkIndex: chunkIndex, totalChunks: totalChunks)
        }
    }

    private func buildPacket(proto: UInt8, protoOpts: UInt8,
                             channelID: UInt16, sequence: UInt32,
                             chunkIndex: UInt32, totalChunks: UInt32,
                             data: Data) throws -> Data {
        var pkt = Data(capacity: Self.headerSize + data.count)
        pkt.append(proto); pkt.append(protoOpts)
        withUnsafeBytes(of: channelID.bigEndian) { pkt.append(contentsOf: $0) }
        withUnsafeBytes(of: sequence.bigEndian) { pkt.append(contentsOf: $0) }
        withUnsafeBytes(of: chunkIndex.bigEndian) { pkt.append(contentsOf: $0) }
        withUnsafeBytes(of: totalChunks.bigEndian) { pkt.append(contentsOf: $0) }
        pkt.append(data)
        return pkt
    }

    private func cleanupBuffers() {
        let cutoff = Date().addingTimeInterval(-bufferTimeout)
        buffers = buffers.filter { $0.value.timestamp > cutoff }
        processed = processed.filter { $0.value > cutoff }
    }
}

struct BinaryHeader {
    let proto: UInt8
    let protoOpts: UInt8
    let channelID: UInt16
    let sequence: UInt32
    let chunkIndex: UInt32
    let totalChunks: UInt32
}

enum ProtocolError: Error {
    case missingKey
    case invalidFormat(String)
}
```

---

## Tests

**File:** `Tests/{{CONFIG:swift_module_name}}Tests/BinaryProtocolTests.swift`

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class BinaryProtocolTests: XCTestCase {

    func testSingleChunkRoundtrip() async throws {
        var received: Data?
        let proto = BinaryProtocol(onMessage: { received = $0 })
        let msg = "Hello".data(using: .utf8)!
        let packets = try await proto.encode(data: msg, protoOpts: 0x00)
        XCTAssertEqual(packets.count, 1)
        for p in packets { try await proto.handle(payload: p) }
        XCTAssertEqual(received, msg)
    }

    func testCompression() async throws {
        var received: Data?
        let proto = BinaryProtocol(onMessage: { received = $0 })
        let msg = Data(repeating: 0xAA, count: 1000)
        let packets = try await proto.encode(data: msg, protoOpts: 0x01)
        for p in packets { try await proto.handle(payload: p) }
        XCTAssertEqual(received, msg)
    }

    func testEncryption() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: Data?
        let proto = BinaryProtocol(key: key, onMessage: { received = $0 })
        let msg = "Secret".data(using: .utf8)!
        let packets = try await proto.encode(data: msg, protoOpts: 0x02)
        for p in packets { try await proto.handle(payload: p) }
        XCTAssertEqual(received, msg)
    }

    func testBoth() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: Data?
        let proto = BinaryProtocol(key: key, onMessage: { received = $0 })
        let msg = Data(repeating: 0xBB, count: 1000)
        let packets = try await proto.encode(data: msg, protoOpts: 0x03)
        for p in packets { try await proto.handle(payload: p) }
        XCTAssertEqual(received, msg)
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter BinaryProtocol
```

All 4 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw2d0e1f2a3b-DONE.txt`:

```
STEP: ybs-step_sw2d0e1f2a3b
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Transport/BinaryProtocol.swift, Tests/BinaryProtocolTests.swift
VERIFICATION: PASSED
NEXT: ybs-step_sw3a0b1c2d3e
```

Update `BUILD_STATUS.md`: add `- [x] sw2d0e1f2a3b`.
