import XCTest
import Foundation
@testable import Transport
@testable import Primitives
import CryptoKit

/// Integration tests for Binary Protocol v2.0
///
/// Tests the new channelID + sequence header format and interoperability.
final class BinaryProtocolV2Tests: XCTestCase {

    var binaryProtocol: BinaryProtocol!
    var testKey: SymmetricKey!

    override func setUp() async throws {
        // Use fixed test key for deterministic testing
        let keyHex = "D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD"
        let keyData = Data(hex: keyHex)!
        testKey = SymmetricKey(data: keyData)

        binaryProtocol = BinaryProtocol(chunkSize: 1024)
        await binaryProtocol.setKey(testKey)
    }

    override func tearDown() async throws {
        // Clean up between tests
        // Uninstall the send API to break capture cycles
        if binaryProtocol != nil {
            await binaryProtocol.installSendAPI { _, _, _ in
                // No-op to replace the old closure
            }
        }
        binaryProtocol = nil
        testKey = nil

        // Give actors time to clean up
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }

    // MARK: - Header Format Tests

    func testHeaderEncoding() async throws {
        let testData = "Hello from Swift!".data(using: .utf8)!
        let channelID: UInt16 = 42

        // Capture sent packets
        let collector = PacketCollector()
        await binaryProtocol.installSendAPI { data, host, port in
            await collector.append(data)
        }

        // Send
        await binaryProtocol.send(payload: testData, protoOpts: 0x00, to: "localhost", port: 9999, channelID: channelID)

        let sentPackets = await collector.getPackets()
        XCTAssertEqual(sentPackets.count, 1, "Should send single chunk")

        let payload = sentPackets[0]
        XCTAssertGreaterThanOrEqual(payload.count, 16, "Payload should have at least 16-byte header")

        // Parse header
        let protoID = payload[0]
        let protoOpts = payload[1]
        let parsedChannelID = UInt16(bigEndian: payload[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) })
        let sequence = UInt32(bigEndian: payload[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) })
        let chunkIndex = UInt32(bigEndian: payload[8..<12].withUnsafeBytes { $0.load(as: UInt32.self) })
        let totalChunks = UInt32(bigEndian: payload[12..<16].withUnsafeBytes { $0.load(as: UInt32.self) })

        XCTAssertEqual(protoID, 0x01, "Protocol ID should be 0x01")
        XCTAssertEqual(protoOpts, 0x00, "Protocol options should be 0x00")
        XCTAssertEqual(parsedChannelID, channelID, "Channel ID should match")
        XCTAssertEqual(sequence, 0, "First message should have sequence 0")
        XCTAssertEqual(chunkIndex, 0, "First chunk index should be 0")
        XCTAssertEqual(totalChunks, 1, "Should be single chunk")
    }

    func testSequenceIncrement() async throws {
        let channelID: UInt16 = 10
        let collector = PacketCollector()

        await binaryProtocol.installSendAPI { data, host, port in
            await collector.append(data)
        }

        // Send 5 messages on same channel
        for _ in 0..<5 {
            await binaryProtocol.send(payload: "test".data(using: .utf8)!, protoOpts: 0x00, to: "localhost", port: 9999, channelID: channelID)
        }

        // Verify sequences increment
        let sentPackets = await collector.getPackets()
        for (i, packet) in sentPackets.enumerated() {
            let sequence = UInt32(bigEndian: packet[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) })
            XCTAssertEqual(sequence, UInt32(i), "Sequence should be \(i)")
        }
    }

    func testChannelIsolation() async throws {
        let tupleCollector = TupleCollector()

        await binaryProtocol.installSendAPI { data, host, port in
            let channelID = UInt16(bigEndian: data[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) })
            let sequence = UInt32(bigEndian: data[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) })
            await tupleCollector.append((channelID, sequence))
        }

        // Send on channel 1
        await binaryProtocol.send(payload: "ch1-msg1".data(using: .utf8)!, protoOpts: 0x00, to: "localhost", port: 9999, channelID: 1)

        // Send on channel 2
        await binaryProtocol.send(payload: "ch2-msg1".data(using: .utf8)!, protoOpts: 0x00, to: "localhost", port: 9999, channelID: 2)

        // Send on channel 1 again
        await binaryProtocol.send(payload: "ch1-msg2".data(using: .utf8)!, protoOpts: 0x00, to: "localhost", port: 9999, channelID: 1)

        let sentPackets = await tupleCollector.getTuples()
        XCTAssertEqual(sentPackets[0].channelID, 1, "First packet on channel 1")
        XCTAssertEqual(sentPackets[0].sequence, 0, "Channel 1 first sequence is 0")

        XCTAssertEqual(sentPackets[1].channelID, 2, "Second packet on channel 2")
        XCTAssertEqual(sentPackets[1].sequence, 0, "Channel 2 first sequence is 0")

        XCTAssertEqual(sentPackets[2].channelID, 1, "Third packet on channel 1")
        XCTAssertEqual(sentPackets[2].sequence, 1, "Channel 1 second sequence is 1")
    }

    // MARK: - Interoperability Tests

    func testPythonFormatDecoding() async throws {
        // Simulate receiving packet from Python
        let testData = "Hello from Python!".data(using: .utf8)!
        let channelID: UInt16 = 99
        let sequence: UInt32 = 5

        // Build packet as Python would (v2.0 format)
        var header = Data()
        header.append(0x01)  // protoID
        header.append(0x00)  // protoOpts
        header.append(contentsOf: channelID.bigEndian.bytes)
        header.append(contentsOf: sequence.bigEndian.bytes)
        header.append(contentsOf: UInt32(0).bigEndian.bytes)  // chunkIndex
        header.append(contentsOf: UInt32(1).bigEndian.bytes)  // totalChunks

        let pythonPacket = header + testData

        // Build complete packet with HMAC (as Python would send it)
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let payload = guid + pythonPacket
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: testKey)
        let fullPacket = Data(hmac.prefix(16)) + payload

        // Parse packet
        let packet = UDPPacketUtils.parse(fullPacket, key: testKey, sourceIP: "127.0.0.1", sourcePort: 9999)

        // Ingest (should decode successfully)
        await binaryProtocol.ingest(packet, key: testKey)

        // Verify no errors (if it crashes, test fails)
    }

    func testBigEndianEncoding() async throws {
        let channelID: UInt16 = 0x1234  // 4660 in decimal
        let collector = PacketCollector()

        await binaryProtocol.installSendAPI { data, host, port in
            await collector.append(data)
        }

        await binaryProtocol.send(payload: "test".data(using: .utf8)!, protoOpts: 0x00, to: "localhost", port: 9999, channelID: channelID)

        let packets = await collector.getPackets()
        XCTAssertEqual(packets.count, 1, "Should have exactly 1 packet")
        let packet = packets[0]
        let channelIDBytes = packet[2..<4]

        // Verify big-endian encoding
        // 0x1234 should be stored as [0x12, 0x34]
        XCTAssertEqual(Array(channelIDBytes)[0], 0x12, "First byte should be 0x12 (MSB)")
        XCTAssertEqual(Array(channelIDBytes)[1], 0x34, "Second byte should be 0x34 (LSB)")
    }

    func testHeaderSizeConstant() async throws {
        let collector = PacketCollector()

        await binaryProtocol.installSendAPI { data, host, port in
            await collector.append(data)
        }

        // Try various payload sizes
        for size in [1, 10, 100, 1000] {
            let data = Data(repeating: 0x58, count: size)  // 'X' repeated
            await binaryProtocol.send(payload: data, protoOpts: 0x00, to: "localhost", port: 9999, channelID: 1)
        }

        // All packets should have 16-byte header
        let sentPackets = await collector.getPackets()
        for packet in sentPackets {
            XCTAssertGreaterThanOrEqual(packet.count, 16, "All packets should have at least 16-byte header")
        }
    }

    // MARK: - Multi-chunk Tests

    func testMultiChunkConsistency() async throws {
        let largeData = Data(repeating: 0x58, count: 3000)
        let channelID: UInt16 = 15
        let collector = PacketCollector()

        await binaryProtocol.installSendAPI { data, host, port in
            await collector.append(data)
        }

        await binaryProtocol.send(payload: largeData, protoOpts: 0x00, to: "localhost", port: 9999, channelID: channelID)

        let sentPackets = await collector.getPackets()
        XCTAssertGreaterThan(sentPackets.count, 1, "Should be chunked")

        // Extract channelID and sequence from first chunk
        let firstPacket = sentPackets[0]
        let expectedChannelID = UInt16(bigEndian: firstPacket[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) })
        let expectedSequence = UInt32(bigEndian: firstPacket[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) })

        // Verify all chunks have same channelID and sequence
        for (i, packet) in sentPackets.enumerated() {
            let channelID = UInt16(bigEndian: packet[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) })
            let sequence = UInt32(bigEndian: packet[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) })
            let chunkIndex = UInt32(bigEndian: packet[8..<12].withUnsafeBytes { $0.load(as: UInt32.self) })
            let totalChunks = UInt32(bigEndian: packet[12..<16].withUnsafeBytes { $0.load(as: UInt32.self) })

            XCTAssertEqual(channelID, expectedChannelID, "Channel ID should be consistent across chunks")
            XCTAssertEqual(sequence, expectedSequence, "Sequence should be consistent across chunks")
            XCTAssertEqual(chunkIndex, UInt32(i), "Chunk index should match position")
            XCTAssertEqual(totalChunks, UInt32(sentPackets.count), "Total chunks should match")
        }
    }

    // MARK: - Compression/Encryption Tests

    func testCompressionPreservesFormat() async throws {
        let compressibleData = Data(repeating: 0x41, count: 2000)  // 'A' repeated
        let collector = PacketCollector()

        await binaryProtocol.installSendAPI { data, host, port in
            await collector.append(data)
        }

        await binaryProtocol.send(payload: compressibleData, protoOpts: 0x01, to: "localhost", port: 9999, channelID: 5)

        let packet = await collector.getPackets()[0]

        // Verify protoOpts flag
        XCTAssertEqual(packet[1], 0x01, "Compression flag should be set")

        // Verify channel ID is still parseable
        let channelID = UInt16(bigEndian: packet[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(channelID, 5)
    }

    func testEncryptionPreservesFormat() async throws {
        let secretData = "Secret message".data(using: .utf8)!
        let collector = PacketCollector()

        await binaryProtocol.installSendAPI { data, host, port in
            await collector.append(data)
        }

        await binaryProtocol.send(payload: secretData, protoOpts: 0x02, to: "localhost", port: 9999, channelID: 6)

        let packet = await collector.getPackets()[0]

        // Verify protoOpts flag
        XCTAssertEqual(packet[1], 0x02, "Encryption flag should be set")

        // Verify channel ID is still parseable
        let channelID = UInt16(bigEndian: packet[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) })
        XCTAssertEqual(channelID, 6)
    }
}

// MARK: - Helper Actor for Swift 6 Concurrency

/// Thread-safe packet collector for testing
actor PacketCollector {
    private var packets: [Data] = []

    func append(_ data: Data) {
        packets.append(data)
    }

    func getPackets() -> [Data] {
        return packets
    }

    func count() -> Int {
        return packets.count
    }
}

/// Thread-safe tuple collector for testing
actor TupleCollector {
    private var tuples: [(channelID: UInt16, sequence: UInt32)] = []

    func append(_ tuple: (UInt16, UInt32)) {
        tuples.append(tuple)
    }

    func getTuples() -> [(channelID: UInt16, sequence: UInt32)] {
        return tuples
    }
}

// MARK: - Helper Extensions

extension UInt16 {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}

extension UInt32 {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self.bigEndian) { Array($0) }
    }
}
