import XCTest
import Foundation
import CryptoKit
@testable import YXProtocol

final class DataCompressionTests: XCTestCase {

    func testZlibCompress() throws {
        let original = String(repeating: "Hello, World! ", count: 50).data(using: .utf8)!
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

final class DataCryptoAESGCMTests: XCTestCase {

    func testAESGCMEncrypt() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Secret message".data(using: .utf8)!
        let ciphertext = try plaintext.aesGCMEncrypt(key: key)
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
        // Format: [nonce(12)] + [ciphertext(4)] + [tag(16)] = 32 for a 4-byte plaintext
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Test".data(using: .utf8)!
        let ciphertext = try plaintext.aesGCMEncrypt(key: key)
        XCTAssertEqual(ciphertext.count, 12 + 4 + 16)
    }
}

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

private actor DataBox {
    var v: Data?
    func set(_ d: Data) { v = d }
}

final class BinaryProtocolTests: XCTestCase {

    func testEncodeSingleChunk() async throws {
        let bp = BinaryProtocol(onMessage: { _ in })
        let message = "Hello".data(using: .utf8)!
        let packets = try await bp.encode(data: message, protoOpts: 0x00, channelID: 0)
        XCTAssertEqual(packets.count, 1)
        XCTAssertEqual(packets[0][packets[0].startIndex], 0x01)
    }

    func testEncodeMultipleChunks() async throws {
        let bp = BinaryProtocol(onMessage: { _ in }, chunkSize: 10)
        let message = Data(repeating: 0xAB, count: 25)
        let packets = try await bp.encode(data: message, protoOpts: 0x00, channelID: 0)
        XCTAssertEqual(packets.count, 3)
    }

    func testHandleAndReassemble() async throws {
        let box = DataBox()
        let bp = BinaryProtocol(onMessage: { d in await box.set(d) }, chunkSize: 10)
        let message = Data(repeating: 0xCD, count: 25)
        let packets = try await bp.encode(data: message, protoOpts: 0x00, channelID: 0)
        for packet in packets { try await bp.handle(payload: packet) }
        let received = await box.v
        XCTAssertEqual(received, message)
    }

    func testCompression() async throws {
        let box = DataBox()
        let bp = BinaryProtocol(onMessage: { d in await box.set(d) })
        let message = Data(repeating: 0xAA, count: 1000)
        let packets = try await bp.encode(data: message, protoOpts: 0x01, channelID: 0)
        let totalSize = packets.reduce(0) { $0 + $1.count }
        XCTAssertLessThan(totalSize, message.count + 100)
        for packet in packets { try await bp.handle(payload: packet) }
        let received = await box.v
        XCTAssertEqual(received, message)
    }

    func testEncryption() async throws {
        let key = Data(repeating: 0x42, count: 32)
        let box = DataBox()
        let bp = BinaryProtocol(key: key, onMessage: { d in await box.set(d) })
        let message = "Secret".data(using: .utf8)!
        let packets = try await bp.encode(data: message, protoOpts: 0x02, channelID: 0)
        for packet in packets { try await bp.handle(payload: packet) }
        let received = await box.v
        XCTAssertEqual(received, message)
    }

    func testCompressionAndEncryption() async throws {
        let key = Data(repeating: 0x42, count: 32)
        let box = DataBox()
        let bp = BinaryProtocol(key: key, onMessage: { d in await box.set(d) })
        let message = Data(repeating: 0xBB, count: 1000)
        let packets = try await bp.encode(data: message, protoOpts: 0x03, channelID: 0)
        for packet in packets { try await bp.handle(payload: packet) }
        let received = await box.v
        XCTAssertEqual(received, message)
    }
}
