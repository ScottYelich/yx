import Testing
@testable import YXProtocol

@Suite struct GUIDFactoryTests {
    @Test func generateReturns6Bytes() {
        let guid = GUIDFactory.generate()
        #expect(guid.count == 6)
    }

    @Test func generateProducesDifferentGUIDs() {
        let guid1 = GUIDFactory.generate()
        let guid2 = GUIDFactory.generate()
        #expect(guid1 != guid2)
    }

    @Test func padGUID() {
        let short = Data([0x01, 0x02])
        let padded = GUIDFactory.pad(guid: short)
        #expect(padded.count == 6)
        #expect(padded == Data([0x01, 0x02, 0x00, 0x00, 0x00, 0x00]))
    }

    @Test func padGUIDExact6Bytes() {
        let exact = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let padded = GUIDFactory.pad(guid: exact)
        #expect(padded == exact)
    }

    @Test func fromHex() {
        let guid = GUIDFactory.fromHex("010203040506")
        #expect(guid == Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
    }

    @Test func toHex() {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let hex = GUIDFactory.toHex(guid)
        #expect(hex == "010203040506")
    }

    @Test func hexRoundtrip() {
        let original = Data([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff])
        let hex = GUIDFactory.toHex(original)
        let restored = GUIDFactory.fromHex(hex)
        #expect(restored == original)
    }
}
