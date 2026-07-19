import XCTest
import CryptoKit
@testable import YXProtocol

final class SimplePacketBuilderTests: XCTestCase {

    func testBuildTextPacket() throws {
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let message: [String: Any] = ["method": "test"]

        let packet = try SimplePacketBuilder.buildTextPacket(message, guid: guid, key: key)
        XCTAssertGreaterThanOrEqual(packet.count, 22) // HMAC(16) + GUID(6)

        // Validate HMAC
        let symKey = try Data.symmetricKey(from: key)
        let parsed = PacketBuilder.parseAndValidate(packet, key: symKey)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.payload.first, 0x00) // Protocol 0 marker
    }

    func testBuildBinarySingleChunk() throws {
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let data = "Small data".data(using: .utf8)!

        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x00)
        XCTAssertEqual(packets.count, 1)

        let symKey = try Data.symmetricKey(from: key)
        let parsed = PacketBuilder.parseAndValidate(packets[0], key: symKey)
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

    func testBuildBinaryCompressed() throws {
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let data = Data(repeating: 0xBB, count: 500)

        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x01)
        XCTAssertEqual(packets.count, 1)
    }

    func testBuildBinaryEncrypted() throws {
        let guid = TestConfig.testGUID
        let key = TestConfig.testKey
        let data = Data("secret data".utf8)

        let packets = try SimplePacketBuilder.buildBinaryPackets(data, guid: guid, key: key, protoOpts: 0x02)
        XCTAssertEqual(packets.count, 1)
    }
}
