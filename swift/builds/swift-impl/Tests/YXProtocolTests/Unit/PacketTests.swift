import XCTest
@testable import YXProtocol

final class PacketTests: XCTestCase {
    func testCreateValidPacket() throws {
        let packet = try Packet(
            hmac: Data(repeating: 0x00, count: 16),
            guid: Data(repeating: 0x01, count: 6),
            payload: Data("test".utf8)
        )

        XCTAssertEqual(packet.hmac.count, 16)
        XCTAssertEqual(packet.guid.count, 6)
        XCTAssertEqual(packet.payload, Data("test".utf8))
    }

    func testToBytes() throws {
        let packet = try Packet(
            hmac: Data(repeating: 0xaa, count: 16),
            guid: Data(repeating: 0xbb, count: 6),
            payload: Data("test".utf8)
        )

        let data = packet.toBytes()
        XCTAssertEqual(data.count, 26)
        XCTAssertEqual(data[0..<16], Data(repeating: 0xaa, count: 16))
        XCTAssertEqual(data[16..<22], Data(repeating: 0xbb, count: 6))
    }

    func testFromBytes() {
        let data = Data(repeating: 0xaa, count: 16) +
                   Data(repeating: 0xbb, count: 6) +
                   Data("test".utf8)

        let packet = Packet.fromBytes(data)
        XCTAssertNotNil(packet)
        XCTAssertEqual(packet?.payload, Data("test".utf8))
    }

    func testRoundtrip() throws {
        let original = try Packet(
            hmac: Data(repeating: 0x01, count: 16),
            guid: Data(repeating: 0x02, count: 6),
            payload: Data("payload".utf8)
        )

        let data = original.toBytes()
        let restored = Packet.fromBytes(data)

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.hmac, original.hmac)
        XCTAssertEqual(restored?.guid, original.guid)
        XCTAssertEqual(restored?.payload, original.payload)
    }
}
