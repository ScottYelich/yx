import Testing
@testable import YXProtocol

@Suite struct PacketTests {
    @Test func createValidPacket() throws {
        let packet = try Packet(
            hmac: Data(repeating: 0x00, count: 16),
            guid: Data(repeating: 0x01, count: 6),
            payload: Data("test".utf8)
        )

        #expect(packet.hmac.count == 16)
        #expect(packet.guid.count == 6)
        #expect(packet.payload == Data("test".utf8))
    }

    @Test func toBytes() throws {
        let packet = try Packet(
            hmac: Data(repeating: 0xaa, count: 16),
            guid: Data(repeating: 0xbb, count: 6),
            payload: Data("test".utf8)
        )

        let data = packet.toBytes()
        #expect(data.count == 26)
        #expect(data[0..<16] == Data(repeating: 0xaa, count: 16))
        #expect(data[16..<22] == Data(repeating: 0xbb, count: 6))
    }

    @Test func fromBytes() {
        let data = Data(repeating: 0xaa, count: 16) +
                   Data(repeating: 0xbb, count: 6) +
                   Data("test".utf8)

        let packet = Packet.fromBytes(data)
        #expect(packet != nil)
        #expect(packet?.payload == Data("test".utf8))
    }

    @Test func roundtrip() throws {
        let original = try Packet(
            hmac: Data(repeating: 0x01, count: 16),
            guid: Data(repeating: 0x02, count: 6),
            payload: Data("payload".utf8)
        )

        let data = original.toBytes()
        let restored = Packet.fromBytes(data)

        #expect(restored != nil)
        #expect(restored?.hmac == original.hmac)
        #expect(restored?.guid == original.guid)
        #expect(restored?.payload == original.payload)
    }
}
