# YBS Step 12 (Swift): Protocol 1 (Binary/Chunked)

**Step ID:** `ybs-step_h2i3j4k5l6m7`
**Language:** Swift
**System:** YX Protocol
**Focus:** Protocol 1 (Binary v2.0) with compression, encryption, and chunking

## Prerequisites

- ✅ Step 11 completed (Protocol 0 - Text/JSON-RPC)
- ✅ Python Step 12 completed (reference implementation)
- ✅ Specifications: `specs/architecture/protocol-layers.md`
- ✅ Specifications: `specs/architecture/security-architecture.md`

## Overview

Implement **Protocol 1** (Binary v2.0) with support for:
- **Compression:** ZLIB (protoOpts & 0x01)
- **Encryption:** AES-256-GCM (protoOpts & 0x02)
- **Chunking:** For messages > chunk_size (1024 bytes default)
- **Multiplexing:** Multiple channels with sequence numbers

**Wire Format (16-byte header + data):**
```
[proto(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] +
[chunkIndex(4)] + [totalChunks(4)] + [data(variable)]
```

**Pipeline:**
```
Send: Data → Compress → Encrypt → Chunk → Send chunks
Recv: Receive chunks → Reassemble → Decrypt → Decompress → Deliver
```

**Multiplexing Key:** `(channelID, sequence)` - Each message identified by channel + sequence

## Traceability

**Specifications:**
- `specs/architecture/protocol-layers.md` § Protocol 1 (Binary)
- `specs/architecture/security-architecture.md` § Encryption
- `specs/technical/yx-protocol-spec.md` § Wire Format
- `specs/technical/default-values.md` § chunk_size = 1024

**Gaps Addressed:**
- Gap 1.2: Protocol 1 implementation
- Gap 1.4: Chunking support
- Gap 2.3: AES-256-GCM encryption
- Gap 3.1: Compression support
- Gap 3.2: (channelID, sequence) multiplexing

**SDTS Lessons:**
- SDTS Issue #1: AES-GCM wire format MUST match across languages
- Compress → Encrypt → Chunk order is critical

## Build Instructions

### 1. Extend Data Encryption (Add AES-256-GCM)

**File:** `Sources/{{CONFIG:swift_module_name}}/Primitives/DataCrypto.swift` (extend existing)

Add to existing file:

```swift
import CryptoKit
import Foundation

/// AES-256-GCM encryption parameters
struct AESGCMParams {
    static let keySize = 32  // 256 bits
    static let nonceSize = 12  // 96 bits
    static let tagSize = 16  // 128 bits
}

extension Data {

    /// Encrypt data using AES-256-GCM
    /// - Parameter key: 32-byte encryption key
    /// - Returns: [nonce(12)] + [ciphertext] + [tag(16)]
    /// - Throws: CryptoError if encryption fails
    func aesGCMEncrypt(key: SymmetricKey) throws -> Data {
        // Ensure key is 256 bits
        guard key.bitCount == 256 else {
            throw CryptoError.invalidKeySize
        }

        // Generate random nonce (96 bits = 12 bytes)
        let nonce = try AES.GCM.Nonce()

        // Encrypt
        let sealedBox = try AES.GCM.seal(self, using: key, nonce: nonce)

        // CRITICAL: Wire format is [nonce(12)] + [ciphertext] + [tag(16)]
        // This matches Python implementation for interoperability
        var result = Data(capacity: AESGCMParams.nonceSize + sealedBox.ciphertext.count + AESGCMParams.tagSize)
        result.append(contentsOf: nonce)
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)

        return result
    }

    /// Decrypt data using AES-256-GCM
    /// - Parameter key: 32-byte encryption key
    /// - Returns: Decrypted plaintext
    /// - Throws: CryptoError if decryption fails
    func aesGCMDecrypt(key: SymmetricKey) throws -> Data {
        // Ensure key is 256 bits
        guard key.bitCount == 256 else {
            throw CryptoError.invalidKeySize
        }

        // CRITICAL: Wire format is [nonce(12)] + [ciphertext] + [tag(16)]
        let totalSize = self.count
        guard totalSize >= AESGCMParams.nonceSize + AESGCMParams.tagSize else {
            throw CryptoError.invalidCiphertext
        }

        // Extract components
        let nonceData = self.prefix(AESGCMParams.nonceSize)
        let ciphertextAndTag = self.suffix(from: AESGCMParams.nonceSize)
        let ciphertext = ciphertextAndTag.prefix(ciphertextAndTag.count - AESGCMParams.tagSize)
        let tag = ciphertextAndTag.suffix(AESGCMParams.tagSize)

        // Create nonce
        let nonce = try AES.GCM.Nonce(data: nonceData)

        // Create sealed box
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)

        // Decrypt
        let plaintext = try AES.GCM.open(sealedBox, using: key)

        return plaintext
    }

    /// Create SymmetricKey from raw bytes
    /// - Parameter keyData: 32-byte key data
    /// - Returns: SymmetricKey for AES-256
    static func symmetricKey(from keyData: Data) throws -> SymmetricKey {
        guard keyData.count == AESGCMParams.keySize else {
            throw CryptoError.invalidKeySize
        }
        return SymmetricKey(data: keyData)
    }
}

enum CryptoError: Error, CustomStringConvertible {
    case invalidKeySize
    case invalidCiphertext
    case encryptionFailed
    case decryptionFailed

    var description: String {
        switch self {
        case .invalidKeySize:
            return "Invalid key size (must be 32 bytes for AES-256)"
        case .invalidCiphertext:
            return "Invalid ciphertext format"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}
```

**CRITICAL - SDTS Issue #1:**
Wire format MUST be: `[nonce(12)] + [ciphertext] + [tag(16)]`

This matches Python's cryptography library format exactly.

### 2. Create Data Compression

**File:** `Sources/{{CONFIG:swift_module_name}}/Primitives/DataCompression.swift`

```swift
import Foundation
import Compression

extension Data {

    /// Compress data using ZLIB (RFC 1950)
    /// - Returns: Compressed data
    /// - Throws: CompressionError if compression fails
    func zlibCompress() throws -> Data {
        return try (self as NSData).compressed(using: .zlib) as Data
    }

    /// Decompress data using ZLIB (RFC 1950)
    /// - Returns: Decompressed data
    /// - Throws: CompressionError if decompression fails
    func zlibDecompress() throws -> Data {
        return try (self as NSData).decompressed(using: .zlib) as Data
    }
}

extension NSData {
    /// Compress NSData using specified algorithm
    func compressed(using algorithm: Algorithm) throws -> Data {
        guard !self.isEmpty else {
            return Data()
        }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer {
            streamPtr.deallocate()
        }

        var stream = streamPtr.pointee
        var status: compression_status

        status = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, algorithm.lowLevelType)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw CompressionError.initializationFailed
        }
        defer {
            compression_stream_destroy(&stream)
        }

        let dstBufferSize = 4096
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)
        defer {
            dstBuffer.deallocate()
        }

        stream.src_ptr = self.bytes.assumingMemoryBound(to: UInt8.self)
        stream.src_size = self.length
        stream.dst_ptr = dstBuffer
        stream.dst_size = dstBufferSize

        var compressedData = Data()

        repeat {
            status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

            if status == COMPRESSION_STATUS_ERROR {
                throw CompressionError.compressionFailed
            }

            if stream.dst_size == 0 || status == COMPRESSION_STATUS_END {
                let bytesWritten = dstBufferSize - stream.dst_size
                compressedData.append(dstBuffer, count: bytesWritten)

                stream.dst_ptr = dstBuffer
                stream.dst_size = dstBufferSize
            }
        } while status == COMPRESSION_STATUS_OK

        return compressedData
    }

    /// Decompress NSData using specified algorithm
    func decompressed(using algorithm: Algorithm) throws -> Data {
        guard !self.isEmpty else {
            return Data()
        }

        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer {
            streamPtr.deallocate()
        }

        var stream = streamPtr.pointee
        var status: compression_status

        status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, algorithm.lowLevelType)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw CompressionError.initializationFailed
        }
        defer {
            compression_stream_destroy(&stream)
        }

        let dstBufferSize = 4096
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)
        defer {
            dstBuffer.deallocate()
        }

        stream.src_ptr = self.bytes.assumingMemoryBound(to: UInt8.self)
        stream.src_size = self.length
        stream.dst_ptr = dstBuffer
        stream.dst_size = dstBufferSize

        var decompressedData = Data()

        repeat {
            status = compression_stream_process(&stream, 0)

            if status == COMPRESSION_STATUS_ERROR {
                throw CompressionError.decompressionFailed
            }

            if stream.dst_size == 0 || status == COMPRESSION_STATUS_END {
                let bytesWritten = dstBufferSize - stream.dst_size
                decompressedData.append(dstBuffer, count: bytesWritten)

                stream.dst_ptr = dstBuffer
                stream.dst_size = dstBufferSize
            }
        } while status == COMPRESSION_STATUS_OK

        return decompressedData
    }

    enum Algorithm {
        case zlib

        var lowLevelType: compression_algorithm {
            switch self {
            case .zlib:
                return COMPRESSION_ZLIB
            }
        }
    }
}

enum CompressionError: Error, CustomStringConvertible {
    case initializationFailed
    case compressionFailed
    case decompressionFailed

    var description: String {
        switch self {
        case .initializationFailed:
            return "Failed to initialize compression stream"
        case .compressionFailed:
            return "Compression failed"
        case .decompressionFailed:
            return "Decompression failed"
        }
    }
}
```

### 3. Create Chunking Utilities

**File:** `Sources/{{CONFIG:swift_module_name}}/Primitives/DataChunking.swift`

```swift
import Foundation

extension Data {

    /// Split data into chunks of specified size
    /// - Parameter chunkSize: Maximum chunk size (default 1024)
    /// - Returns: Array of data chunks
    func chunked(size chunkSize: Int = 1024) -> [Data] {
        guard !isEmpty else {
            return []
        }

        guard chunkSize > 0 else {
            return [self]
        }

        var chunks: [Data] = []
        var offset = 0

        while offset < count {
            let end = min(offset + chunkSize, count)
            let chunk = self[offset..<end]
            chunks.append(chunk)
            offset = end
        }

        return chunks
    }
}

/// Buffer entry for incomplete messages
struct BufferEntry {
    /// Received chunks (indexed by chunkIndex)
    var chunks: [UInt32: Data]

    /// Total number of chunks expected
    let totalChunks: UInt32

    /// Timestamp when first chunk received
    let timestamp: Date

    /// Check if message is complete
    var isComplete: Bool {
        return chunks.count == Int(totalChunks)
    }

    /// Reassemble chunks into complete message
    /// - Returns: Complete message data
    /// - Throws: ChunkingError if chunks are missing
    func reassemble() throws -> Data {
        guard isComplete else {
            throw ChunkingError.incompleteMessage
        }

        var result = Data()
        for index in 0..<totalChunks {
            guard let chunk = chunks[index] else {
                throw ChunkingError.missingChunk(index)
            }
            result.append(chunk)
        }

        return result
    }
}

enum ChunkingError: Error, CustomStringConvertible {
    case incompleteMessage
    case missingChunk(UInt32)
    case bufferTimeout

    var description: String {
        switch self {
        case .incompleteMessage:
            return "Message is incomplete (not all chunks received)"
        case .missingChunk(let index):
            return "Missing chunk at index \(index)"
        case .bufferTimeout:
            return "Buffer timeout (message incomplete)"
        }
    }
}
```

### 4. Create Binary Protocol Handler

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/BinaryProtocol.swift`

```swift
import Foundation
import CryptoKit

/// Protocol 1: Binary (Chunked) handler
///
/// Header format (16 bytes):
/// [proto(1)] + [protoOpts(1)] + [channelID(2)] + [sequence(4)] +
/// [chunkIndex(4)] + [totalChunks(4)]
///
/// protoOpts flags:
/// - 0x00: Base (no compression, no encryption)
/// - 0x01: Compressed (ZLIB)
/// - 0x02: Encrypted (AES-256-GCM)
/// - 0x03: Both (compress then encrypt)
actor BinaryProtocol {

    /// Protocol ID for Binary protocol
    static let protocolID: UInt8 = 0x01

    /// Header size (16 bytes)
    static let headerSize = 16

    /// protoOpts flags
    struct ProtoOpts: OptionSet {
        let rawValue: UInt8

        static let compressed = ProtoOpts(rawValue: 0x01)
        static let encrypted = ProtoOpts(rawValue: 0x02)
    }

    /// Encryption key (32 bytes for AES-256)
    private let key: SymmetricKey?

    /// Message handler
    private let onMessage: (Data) async -> Void

    /// Default chunk size
    private let chunkSize: Int

    /// Buffer timeout (seconds)
    private let bufferTimeout: TimeInterval

    /// Incomplete message buffers (keyed by (channelID, sequence))
    private var incompleteMessages: [BufferKey: BufferEntry] = [:]

    /// Processed message tracking (keyed by (channelID, sequence))
    private var processedMessages: [BufferKey: Date] = [:]

    /// Sequence counters per channel
    private var sequenceCounters: [UInt16: UInt32] = [:]

    /// Buffer key type
    typealias BufferKey = (channelID: UInt16, sequence: UInt32)

    /// Initialize binary protocol handler
    /// - Parameters:
    ///   - key: Encryption key (32 bytes), required if protoOpts uses encryption
    ///   - onMessage: Message handler callback
    ///   - chunkSize: Chunk size (default 1024)
    ///   - bufferTimeout: Buffer timeout in seconds (default 60.0)
    init(key: Data? = nil,
         onMessage: @escaping (Data) async -> Void,
         chunkSize: Int = 1024,
         bufferTimeout: TimeInterval = 60.0) {
        self.key = key != nil ? try? Data.symmetricKey(from: key!) : nil
        self.onMessage = onMessage
        self.chunkSize = chunkSize
        self.bufferTimeout = bufferTimeout
    }

    /// Handle incoming binary protocol payload
    /// - Parameter payload: Complete packet with header + data
    func handle(payload: Data) async throws {
        // Verify minimum size
        guard payload.count >= Self.headerSize else {
            throw ProtocolError.invalidFormat("Payload too small for header")
        }

        // Verify protocol ID
        guard payload[0] == Self.protocolID else {
            throw ProtocolError.invalidFormat("Expected protocol ID 0x01")
        }

        // Parse header (16 bytes)
        let header = try parseHeader(payload)

        // Extract data
        let data = payload.suffix(from: Self.headerSize)

        // Buffer or process chunk
        try await processChunk(header: header, data: data)

        // Cleanup old buffers
        cleanupBuffers()
    }

    /// Process incoming chunk
    private func processChunk(header: BinaryHeader, data: Data) async throws {
        let key = (header.channelID, header.sequence)

        // Check if already processed
        if processedMessages[key] != nil {
            // Duplicate - ignore
            return
        }

        // Single chunk message - process immediately
        if header.totalChunks == 1 {
            let message = try await processMessage(data: data, protoOpts: header.protoOpts)
            await onMessage(message)
            processedMessages[key] = Date()
            return
        }

        // Multi-chunk message - buffer
        if var entry = incompleteMessages[key] {
            // Add chunk to existing buffer
            entry.chunks[header.chunkIndex] = data
            incompleteMessages[key] = entry

            // Check if complete
            if entry.isComplete {
                let reassembled = try entry.reassemble()
                let message = try await processMessage(data: reassembled, protoOpts: header.protoOpts)
                await onMessage(message)

                // Move to processed
                processedMessages[key] = Date()
                incompleteMessages.removeValue(forKey: key)
            }
        } else {
            // Create new buffer entry
            var chunks: [UInt32: Data] = [:]
            chunks[header.chunkIndex] = data

            let entry = BufferEntry(
                chunks: chunks,
                totalChunks: header.totalChunks,
                timestamp: Date()
            )

            incompleteMessages[key] = entry
        }
    }

    /// Process complete message (decrypt → decompress)
    private func processMessage(data: Data, protoOpts: UInt8) async throws -> Data {
        var result = data
        let opts = ProtoOpts(rawValue: protoOpts)

        // Decrypt (if encrypted)
        if opts.contains(.encrypted) {
            guard let key = key else {
                throw ProtocolError.invalidFormat("Encryption key not provided")
            }
            result = try result.aesGCMDecrypt(key: key)
        }

        // Decompress (if compressed)
        if opts.contains(.compressed) {
            result = try result.zlibDecompress()
        }

        return result
    }

    /// Cleanup old buffer entries
    private func cleanupBuffers() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-bufferTimeout)

        // Remove incomplete messages older than timeout
        incompleteMessages = incompleteMessages.filter { _, entry in
            entry.timestamp > cutoff
        }

        // Remove processed messages older than timeout
        processedMessages = processedMessages.filter { _, timestamp in
            timestamp > cutoff
        }
    }

    /// Encode message for sending
    /// - Parameters:
    ///   - data: Message data
    ///   - protoOpts: Protocol options (0x00, 0x01, 0x02, 0x03)
    ///   - channelID: Channel ID (default 0)
    /// - Returns: Array of encoded packets (one per chunk)
    func encode(data: Data, protoOpts: UInt8 = 0x00, channelID: UInt16 = 0) throws -> [Data] {
        // Get next sequence number for this channel
        let sequence = nextSequence(for: channelID)

        // Process message (compress → encrypt)
        var processed = data
        let opts = ProtoOpts(rawValue: protoOpts)

        // Compress (if requested)
        if opts.contains(.compressed) {
            processed = try processed.zlibCompress()
        }

        // Encrypt (if requested)
        if opts.contains(.encrypted) {
            guard let key = key else {
                throw ProtocolError.invalidFormat("Encryption key not provided")
            }
            processed = try processed.aesGCMEncrypt(key: key)
        }

        // Chunk
        let chunks = processed.chunked(size: chunkSize)
        let totalChunks = UInt32(chunks.count)

        // Build packets
        var packets: [Data] = []
        for (index, chunk) in chunks.enumerated() {
            let header = BinaryHeader(
                proto: Self.protocolID,
                protoOpts: protoOpts,
                channelID: channelID,
                sequence: sequence,
                chunkIndex: UInt32(index),
                totalChunks: totalChunks
            )

            let packet = buildPacket(header: header, data: chunk)
            packets.append(packet)
        }

        return packets
    }

    /// Get next sequence number for channel
    private func nextSequence(for channelID: UInt16) -> UInt32 {
        let current = sequenceCounters[channelID, default: 0]
        sequenceCounters[channelID] = current + 1
        return current
    }

    /// Parse header from payload
    private func parseHeader(_ payload: Data) throws -> BinaryHeader {
        guard payload.count >= Self.headerSize else {
            throw ProtocolError.invalidFormat("Payload too small")
        }

        let proto = payload[0]
        let protoOpts = payload[1]
        let channelID = payload.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }.bigEndian
        let sequence = payload.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }.bigEndian
        let chunkIndex = payload.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self) }.bigEndian
        let totalChunks = payload.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt32.self) }.bigEndian

        return BinaryHeader(
            proto: proto,
            protoOpts: protoOpts,
            channelID: channelID,
            sequence: sequence,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks
        )
    }

    /// Build packet from header and data
    private func buildPacket(header: BinaryHeader, data: Data) -> Data {
        var packet = Data(capacity: Self.headerSize + data.count)

        // Write header (16 bytes, big-endian)
        packet.append(header.proto)
        packet.append(header.protoOpts)
        withUnsafeBytes(of: header.channelID.bigEndian) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: header.sequence.bigEndian) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: header.chunkIndex.bigEndian) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: header.totalChunks.bigEndian) { packet.append(contentsOf: $0) }

        // Write data
        packet.append(data)

        return packet
    }
}

/// Binary protocol header (16 bytes)
struct BinaryHeader {
    let proto: UInt8           // Protocol ID (0x01)
    let protoOpts: UInt8       // Options (compress, encrypt)
    let channelID: UInt16      // Channel ID
    let sequence: UInt32       // Sequence number
    let chunkIndex: UInt32     // Chunk index (0-based)
    let totalChunks: UInt32    // Total chunks
}

// Extension to make tuple hashable for dictionary keys
extension BinaryProtocol {
    struct BufferKeyWrapper: Hashable {
        let channelID: UInt16
        let sequence: UInt32

        init(_ key: BufferKey) {
            self.channelID = key.channelID
            self.sequence = key.sequence
        }

        var tuple: BufferKey {
            return (channelID, sequence)
        }
    }
}
```

## Verification

### Unit Tests

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Primitives/DataCompressionTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class DataCompressionTests: XCTestCase {

    func testZlibCompress() throws {
        let original = "Hello, World!".data(using: .utf8)!
        let compressed = try original.zlibCompress()

        XCTAssertLessThan(compressed.count, original.count)
    }

    func testZlibRoundtrip() throws {
        let original = String(repeating: "Test data ", count: 100).data(using: .utf8)!
        let compressed = try original.zlibCompress()
        let decompressed = try compressed.zlibDecompress()

        XCTAssertEqual(decompressed, original)
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Primitives/DataCryptoTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import {{CONFIG:swift_module_name}}

final class DataCryptoTests: XCTestCase {

    func testAESGCMEncrypt() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Secret message".data(using: .utf8)!

        let ciphertext = try plaintext.aesGCMEncrypt(key: key)

        // Verify format: nonce(12) + ciphertext + tag(16)
        XCTAssertGreaterThanOrEqual(ciphertext.count, 12 + 16)
    }

    func testAESGCMRoundtrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Secret message".data(using: .utf8)!

        let ciphertext = try plaintext.aesGCMEncrypt(key: key)
        let decrypted = try ciphertext.aesGCMDecrypt(key: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testAESGCMWireFormat() throws {
        // CRITICAL: Verify wire format matches SDTS
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Test".data(using: .utf8)!

        let ciphertext = try plaintext.aesGCMEncrypt(key: key)

        // Format: [nonce(12)] + [ciphertext(4)] + [tag(16)]
        XCTAssertEqual(ciphertext.count, 12 + 4 + 16)
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Primitives/DataChunkingTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class DataChunkingTests: XCTestCase {

    func testChunkSingleChunk() {
        let data = Data([1, 2, 3, 4])
        let chunks = data.chunked(size: 10)

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], data)
    }

    func testChunkMultipleChunks() {
        let data = Data(repeating: 0xFF, count: 2500)
        let chunks = data.chunked(size: 1024)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0].count, 1024)
        XCTAssertEqual(chunks[1].count, 1024)
        XCTAssertEqual(chunks[2].count, 452)
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Transport/BinaryProtocolTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import {{CONFIG:swift_module_name}}

final class BinaryProtocolTests: XCTestCase {

    func testEncodeSingleChunk() async throws {
        var received: Data?
        let protocol = BinaryProtocol(onMessage: { data in
            received = data
        })

        let message = "Hello".data(using: .utf8)!
        let packets = try await protocol.encode(data: message, protoOpts: 0x00, channelID: 0)

        XCTAssertEqual(packets.count, 1)
        XCTAssertEqual(packets[0][0], 0x01)  // Protocol ID
    }

    func testEncodeMultipleChunks() async throws {
        let protocol = BinaryProtocol(onMessage: { _ in }, chunkSize: 10)

        let message = Data(repeating: 0xAB, count: 25)
        let packets = try await protocol.encode(data: message, protoOpts: 0x00, channelID: 0)

        XCTAssertEqual(packets.count, 3)
    }

    func testHandleAndReassemble() async throws {
        var received: Data?
        let protocol = BinaryProtocol(onMessage: { data in
            received = data
        }, chunkSize: 10)

        // Encode
        let message = Data(repeating: 0xCD, count: 25)
        let packets = try await protocol.encode(data: message, protoOpts: 0x00, channelID: 0)

        // Handle chunks
        for packet in packets {
            try await protocol.handle(payload: packet)
        }

        // Verify reassembly
        XCTAssertEqual(received, message)
    }

    func testCompression() async throws {
        var received: Data?
        let protocol = BinaryProtocol(onMessage: { data in
            received = data
        })

        // Large repetitive data compresses well
        let message = Data(repeating: 0xAA, count: 1000)
        let packets = try await protocol.encode(data: message, protoOpts: 0x01, channelID: 0)

        // Verify compression reduced size
        let totalSize = packets.reduce(0) { $0 + $1.count }
        XCTAssertLessThan(totalSize, message.count + 100)

        // Handle and verify
        for packet in packets {
            try await protocol.handle(payload: packet)
        }
        XCTAssertEqual(received, message)
    }

    func testEncryption() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: Data?
        let protocol = BinaryProtocol(key: key, onMessage: { data in
            received = data
        })

        let message = "Secret".data(using: .utf8)!
        let packets = try await protocol.encode(data: message, protoOpts: 0x02, channelID: 0)

        // Handle and verify
        for packet in packets {
            try await protocol.handle(payload: packet)
        }
        XCTAssertEqual(received, message)
    }

    func testCompressionAndEncryption() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: Data?
        let protocol = BinaryProtocol(key: key, onMessage: { data in
            received = data
        })

        let message = Data(repeating: 0xBB, count: 1000)
        let packets = try await protocol.encode(data: message, protoOpts: 0x03, channelID: 0)

        // Handle and verify
        for packet in packets {
            try await protocol.handle(payload: packet)
        }
        XCTAssertEqual(received, message)
    }
}
```

### Success Criteria

- [ ] All 20+ tests pass
- [ ] Single-chunk messages work
- [ ] Multi-chunk messages reassemble correctly
- [ ] Compression (protoOpts 0x01) works
- [ ] Encryption (protoOpts 0x02) works
- [ ] Both compression + encryption (protoOpts 0x03) works
- [ ] (channelID, sequence) multiplexing works
- [ ] AES-GCM wire format matches Python implementation (SDTS Issue #1)
- [ ] Buffer cleanup works (no memory leaks)
- [ ] Code coverage ≥ 80%

### Run Tests

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter Protocol1
swift test --filter DataCompression
swift test --filter DataCrypto
swift test --filter DataChunking
```

## Implementation Notes

### Pipeline Order (CRITICAL)

**Send:** Data → Compress → Encrypt → Chunk
**Recv:** Reassemble → Decrypt → Decompress → Deliver

This order is REQUIRED for correct operation.

### SDTS Issue #1: AES-GCM Wire Format

**Wire format:** `[nonce(12)] + [ciphertext] + [tag(16)]`

This MUST match Python's cryptography library exactly:
```python
cipher = Cipher(algorithms.AES(key), modes.GCM(nonce))
encryptor = cipher.encryptor()
ciphertext = encryptor.update(data) + encryptor.finalize()
# Returns: nonce + ciphertext + tag
```

Swift's CryptoKit produces the same format.

### Multiplexing Design

**Buffer key:** `(channelID, sequence)`

Each message is uniquely identified by its channel and sequence number. This allows:
- Multiple concurrent streams on different channels
- Out-of-order chunk delivery (within same message)
- Duplicate detection

### Actor Safety

BinaryProtocol is an actor - all state modifications are serialized. This prevents:
- Race conditions on buffer access
- Sequence number conflicts
- Double-processing of messages

## Traceability Matrix

| Gap ID | Specification | Implementation | Tests |
|--------|---------------|----------------|-------|
| 1.2 | protocol-layers.md § Protocol 1 | BinaryProtocol.swift | BinaryProtocolTests.swift |
| 1.4 | protocol-layers.md § Chunking | DataChunking.swift | DataChunkingTests.swift |
| 2.3 | security-architecture.md § AES-GCM | DataCrypto.swift | DataCryptoTests.swift |
| 3.1 | protocol-layers.md § Compression | DataCompression.swift | DataCompressionTests.swift |
| 3.2 | protocol-layers.md § Multiplexing | BinaryProtocol.swift | BinaryProtocolTests.swift |

## Next Steps

After completing this step:

1. ✅ Protocol 0 (Text/JSON-RPC) working
2. ✅ Protocol 1 (Binary/Chunked) working
3. ⏭️ **Next:** Step 13 - Security (Replay Protection + Rate Limiting)
4. Then: Step 14 - SimplePacketBuilder (Test Helpers)
5. Then: Step 15 - Interoperability Test Suite

## References

- `specs/architecture/protocol-layers.md` - Protocol 1 specification
- `specs/architecture/security-architecture.md` - Encryption details
- `specs/technical/default-values.md` - Default chunk_size = 1024
- Python Step 12: `steps/python/ybs-step_h2i3j4k5l6m7.md`
- SDTS Issue #1: AES-GCM wire format compatibility
