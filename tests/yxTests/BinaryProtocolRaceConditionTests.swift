import XCTest
import Foundation
import CryptoKit
@testable import Transport
@testable import Primitives

// Import HMAC
import CommonCrypto

/// Unit tests to verify that BinaryProtocol handles simultaneous duplicate chunks
/// without processing the same message multiple times.
///
/// This test suite simulates the race condition that was causing "Received response for
/// unknown request" errors when multiple chunks arrived simultaneously via UDP
/// broadcast with SO_REUSEPORT enabled.
final class BinaryProtocolRaceConditionTests: XCTestCase {

    private var binaryProtocol: BinaryProtocol!
    private var messageCounter: MessageCounter!
    private var key: SymmetricKey!

    override func setUp() async throws {
        // Shared test key (same as Python tests)
        let keyData = Data(hex: "D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD")!
        key = SymmetricKey(data: keyData)

        messageCounter = MessageCounter()
        binaryProtocol = BinaryProtocol(chunkSize: 1024, bufferTimeout: 60.0, dedupWindow: 5.0)

        await binaryProtocol.setKey(key)

        // Capture counter to avoid Sendable warning
        let counter = messageCounter!
        await binaryProtocol.setReceiveHandler { data in
            await counter.onMessage(data)
        }
    }

    override func tearDown() async throws {
        binaryProtocol = nil
        messageCounter = nil
        key = nil
    }

    // MARK: - Test 1: Single Chunk Duplicate

    func testNoDuplicateProcessingSingleChunk() async throws {
        // Test that a single-chunk message received twice is only processed once.
        // Simulates: UDP packet duplication or SO_REUSEPORT delivering same packet twice

        // Create a single-chunk message (small JSON payload)
        let testMessage = Data(#"{"method": "test", "params": {"value": 42}}"#.utf8)

        // Build binary protocol packet (no encryption/compression for simplicity)
        let protoID: UInt8 = 1
        let protoOpts: UInt8 = 0x00  // No compression or encryption
        let channelID: UInt16 = 1
        let sequence: UInt32 = 1
        let chunkIndex: UInt32 = 0
        let totalChunks: UInt32 = 1

        var header = Data()
        header.append(protoID)
        header.append(protoOpts)
        header.append(contentsOf: channelID.bigEndianBytes)
        header.append(contentsOf: sequence.bigEndianBytes)
        header.append(contentsOf: chunkIndex.bigEndianBytes)
        header.append(contentsOf: totalChunks.bigEndianBytes)

        let packet = header + testMessage

        // Build complete packet with HMAC (as would be sent over UDP)
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let payload = guid + packet
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let fullPacket = Data(hmac.prefix(16)) + payload

        // Parse packet
        let udpPacket = UDPPacketUtils.parse(fullPacket, key: key, sourceIP: "127.0.0.1", sourcePort: 9999)

        // Simulate receiving the SAME packet TWICE (UDP duplication)
        await binaryProtocol.ingest(udpPacket, key: key)
        await binaryProtocol.ingest(udpPacket, key: key)

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Verify: Message should only be processed ONCE despite receiving packet twice
        let count = await messageCounter.count
        XCTAssertEqual(count, 1, "Message processed \(count) times, expected 1")

        let messages = await messageCounter.messages
        XCTAssertEqual(messages.count, 1, "Got \(messages.count) messages, expected 1")
    }

    // MARK: - Test 2: Multi-Chunk Duplicate

    func testNoDuplicateProcessingMultiChunk() async throws {
        // Test that a multi-chunk message with duplicate final chunk is only processed once.
        // Simulates: Final chunk arriving twice before buffer cleanup completes

        // Create a multi-chunk message (large payload that will be chunked)
        let testMessage = Data(#"{"method": "test", "data": ""#.utf8) + Data(repeating: UInt8(ascii: "x"), count: 500) + Data(#""}"#.utf8)

        // Build protocol with small chunk size to force multiple chunks
        let smallChunkProtocol = BinaryProtocol(chunkSize: 100, bufferTimeout: 60.0, dedupWindow: 5.0)
        await smallChunkProtocol.setKey(key)

        let smallChunkCounter = MessageCounter()
        await smallChunkProtocol.setReceiveHandler { [weak smallChunkCounter] data in
            await smallChunkCounter?.onMessage(data)
        }

        // Manually chunk the data
        let chunks = testMessage.chunked(into: 100)
        XCTAssertGreaterThan(chunks.count, 1, "Test payload should be split into multiple chunks")

        // Build packets
        let protoID: UInt8 = 1
        let protoOpts: UInt8 = 0x00
        let channelID: UInt16 = 1
        let sequence: UInt32 = 1
        let totalChunks = UInt32(chunks.count)

        var packets: [UDPPacket] = []
        for (index, chunk) in chunks.enumerated() {
            var header = Data()
            header.append(protoID)
            header.append(protoOpts)
            header.append(contentsOf: channelID.bigEndianBytes)
            header.append(contentsOf: sequence.bigEndianBytes)
            header.append(contentsOf: UInt32(index).bigEndianBytes)
            header.append(contentsOf: totalChunks.bigEndianBytes)

            let packetData = header + chunk

            // Build complete packet with HMAC
            let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
            let packetPayload = guid + packetData
            let hmac = HMAC<SHA256>.authenticationCode(for: packetPayload, using: key)
            let fullPacket = Data(hmac.prefix(16)) + packetPayload

            // Parse packet
            let udpPacket = UDPPacketUtils.parse(fullPacket, key: key, sourceIP: "127.0.0.1", sourcePort: 9999)
            packets.append(udpPacket)
        }

        // Send all chunks EXCEPT the last one
        for packet in packets.dropLast() {
            await smallChunkProtocol.ingest(packet, key: key)
        }

        // Wait a bit
        try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

        // Verify message NOT processed yet
        var count = await smallChunkCounter.count
        XCTAssertEqual(count, 0, "Message should not be processed until all chunks received")

        // Now send the LAST chunk TWICE (simulating race condition)
        if let lastPacket = packets.last {
            await smallChunkProtocol.ingest(lastPacket, key: key)
            await smallChunkProtocol.ingest(lastPacket, key: key)  // DUPLICATE!
        }

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Verify: Message should only be processed ONCE despite duplicate final chunk
        count = await smallChunkCounter.count
        XCTAssertEqual(count, 1, "Message processed \(count) times, expected 1")

        let messages = await smallChunkCounter.messages
        XCTAssertEqual(messages.count, 1, "Got \(messages.count) messages, expected 1")
    }

    // MARK: - Test 3: Concurrent Chunk Arrival

    func testConcurrentChunkArrival() async throws {
        // Test that all chunks arriving simultaneously only process message once.
        // Simulates: Broadcast storm where all chunks arrive at exact same time

        // Create multi-chunk message
        let testMessage = Data(#"{"method": "test", "data": ""#.utf8) + Data(repeating: UInt8(ascii: "y"), count: 300) + Data(#""}"#.utf8)

        // Build protocol with small chunk size
        let smallChunkProtocol = BinaryProtocol(chunkSize: 100, bufferTimeout: 60.0, dedupWindow: 5.0)
        await smallChunkProtocol.setKey(key)

        let smallChunkCounter = MessageCounter()
        await smallChunkProtocol.setReceiveHandler { [weak smallChunkCounter] data in
            await smallChunkCounter?.onMessage(data)
        }

        // Manually chunk the data
        let chunks = testMessage.chunked(into: 100)

        // Build all packets
        let protoID: UInt8 = 1
        let protoOpts: UInt8 = 0x00
        let channelID: UInt16 = 1
        let sequence: UInt32 = 1
        let totalChunks = UInt32(chunks.count)

        var packets: [UDPPacket] = []
        for (index, chunk) in chunks.enumerated() {
            var header = Data()
            header.append(protoID)
            header.append(protoOpts)
            header.append(contentsOf: channelID.bigEndianBytes)
            header.append(contentsOf: sequence.bigEndianBytes)
            header.append(contentsOf: UInt32(index).bigEndianBytes)
            header.append(contentsOf: totalChunks.bigEndianBytes)

            let packetData = header + chunk

            // Build complete packet with HMAC
            let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
            let packetPayload = guid + packetData
            let hmac = HMAC<SHA256>.authenticationCode(for: packetPayload, using: key)
            let fullPacket = Data(hmac.prefix(16)) + packetPayload

            // Parse packet
            let udpPacket = UDPPacketUtils.parse(fullPacket, key: key, sourceIP: "127.0.0.1", sourcePort: 9999)
            packets.append(udpPacket)
        }

        // Send ALL chunks concurrently (simulate simultaneous arrival)
        let testKey = key!
        await withTaskGroup(of: Void.self) { group in
            for packet in packets {
                group.addTask {
                    await smallChunkProtocol.ingest(packet, key: testKey)
                }
            }
        }

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Verify: Message processed exactly once
        let count = await smallChunkCounter.count
        XCTAssertEqual(count, 1, "Message processed \(count) times, expected 1")
    }

    // MARK: - Test 4: Multiple Messages No Crosstalk

    func testMultipleMessagesNoCrosstalk() async throws {
        // Test that multiple different messages don't interfere with each other.
        // Ensures the race condition fix doesn't break normal multi-message handling.

        // Create 3 different messages with different sequence numbers
        let messages: [(UInt32, String)] = [
            (1, #"{"id": 1}"#),
            (2, #"{"id": 2}"#),
            (3, #"{"id": 3}"#),
        ]

        // Send all messages
        for (sequence, msg) in messages {
            let testMessage = Data(msg.utf8)

            let protoID: UInt8 = 1
            let protoOpts: UInt8 = 0x00
            let channelID: UInt16 = 1
            let chunkIndex: UInt32 = 0
            let totalChunks: UInt32 = 1

            var header = Data()
            header.append(protoID)
            header.append(protoOpts)
            header.append(contentsOf: channelID.bigEndianBytes)
            header.append(contentsOf: sequence.bigEndianBytes)
            header.append(contentsOf: chunkIndex.bigEndianBytes)
            header.append(contentsOf: totalChunks.bigEndianBytes)

            let packetData = header + testMessage

            // Build complete packet with HMAC
            let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
            let packetPayload = guid + packetData
            let hmac = HMAC<SHA256>.authenticationCode(for: packetPayload, using: key)
            let fullPacket = Data(hmac.prefix(16)) + packetPayload

            // Parse packet
            let udpPacket = UDPPacketUtils.parse(fullPacket, key: key, sourceIP: "127.0.0.1", sourcePort: 9999)

            await binaryProtocol.ingest(udpPacket, key: key)
        }

        // Wait for processing
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Verify: All 3 messages processed exactly once
        let count = await messageCounter.count
        XCTAssertEqual(count, 3, "Expected 3 messages, got \(count)")

        let receivedMessages = await messageCounter.messages
        let uniqueMessages = Set(receivedMessages.map { String(decoding: $0, as: UTF8.self) })
        XCTAssertEqual(uniqueMessages.count, 3, "Messages should be unique")
    }
}

// MARK: - Helper Classes

/// Helper actor to count how many times a message is received
actor MessageCounter {
    private(set) var count = 0
    private(set) var messages: [Data] = []

    func onMessage(_ data: Data) {
        count += 1
        messages.append(data)
    }
}

// MARK: - Extensions

extension Data {
    /// Initialize Data from hex string
    init?(hex: String) {
        let hex = hex.replacingOccurrences(of: " ", with: "")
        guard hex.count % 2 == 0 else { return nil }

        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}

extension UInt16 {
    /// Convert to big-endian byte array
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}

extension UInt32 {
    /// Convert to big-endian byte array
    var bigEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}

extension Data {
    /// Chunk data into fixed-size pieces
    func chunked(into size: Int) -> [Data] {
        stride(from: 0, to: count, by: size).map {
            self[$0..<Swift.min($0 + size, count)]
        }
    }
}
