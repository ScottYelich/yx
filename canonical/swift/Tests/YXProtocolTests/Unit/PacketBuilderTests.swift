import Testing
import CryptoKit
@testable import YXProtocol

@Suite struct PacketBuilderTests {
    @Test func buildPacket() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let packet = try PacketBuilder.buildPacket(guid: guid, payload: payload, key: key)

        #expect(packet.guid == guid)
        #expect(packet.payload == payload)
        #expect(packet.hmac.count == 16)
    }

    @Test func buildAndSerialize() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        let data = try PacketBuilder.buildAndSerialize(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: key)

        #expect(data.count == 26)
    }

    @Test func parseAndValidate() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        let data = try PacketBuilder.buildAndSerialize(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: key)
        let packet = PacketBuilder.parseAndValidate(data, key: key)

        #expect(packet != nil)
        #expect(packet?.payload == Data("test".utf8))
    }
}
