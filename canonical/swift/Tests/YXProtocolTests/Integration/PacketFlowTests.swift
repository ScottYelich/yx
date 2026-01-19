import Testing
import CryptoKit
@testable import YXProtocol

@Suite struct PacketFlowTests {
    @Test func completePacketFlow() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0xaa, count: 6)
        let payload = Data("integration test payload".utf8)

        // Build
        let packet = try PacketBuilder.buildPacket(guid: guid, payload: payload, key: key)

        // Serialize
        let data = packet.toBytes()

        // Parse
        let parsed = PacketBuilder.parsePacket(data)
        #expect(parsed != nil)

        // Validate
        let isValid = PacketBuilder.validateHMAC(parsed!, key: key)
        #expect(isValid)

        // Verify payload
        #expect(parsed?.payload == payload)
    }

    @Test func multiplePackets() throws {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

        for i in 0..<10 {
            let payload = Data("packet \(i)".utf8)
            let packet = try PacketBuilder.buildPacket(guid: Data(repeating: 0x01, count: 6), payload: payload, key: key)

            let data = packet.toBytes()
            let parsed = PacketBuilder.parseAndValidate(data, key: key)

            #expect(parsed != nil)
            #expect(parsed?.payload == payload)
        }
    }

    @Test func invalidKeyRejected() throws {
        let sendKey = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let recvKey = SymmetricKey(data: Data(repeating: 0xff, count: 32))

        let data = try PacketBuilder.buildAndSerialize(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: sendKey)

        let packet = PacketBuilder.parseAndValidate(data, key: recvKey)

        #expect(packet == nil, "Packet with wrong key should be rejected")
    }
}
