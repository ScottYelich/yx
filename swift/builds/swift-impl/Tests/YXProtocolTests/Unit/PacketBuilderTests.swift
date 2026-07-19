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

        let data = try PacketBuilder.buildAndSerialize(
            guid: Data(repeating: 0x01, count: 6),
            payload: Data("test".utf8),
            key: key
        )

        XCTAssertEqual(data.count, 26)
    }

    func testParseAndValidate() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        let data = try PacketBuilder.buildAndSerialize(
            guid: Data(repeating: 0x01, count: 6),
            payload: Data("test".utf8),
            key: key
        )
        let packet = PacketBuilder.parseAndValidate(data, key: key)

        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.payload, Data("test".utf8))
    }

    func testInvalidKeyRejected() throws {
        let sendKey = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let recvKey = SymmetricKey(data: Data(repeating: 0xff, count: 32))

        let data = try PacketBuilder.buildAndSerialize(
            guid: Data(repeating: 0x01, count: 6),
            payload: Data("test".utf8),
            key: sendKey
        )
        let packet = PacketBuilder.parseAndValidate(data, key: recvKey)

        XCTAssertNil(packet)
    }
}
