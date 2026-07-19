import XCTest
@testable import YXProtocol

final class GUIDFactoryTests: XCTestCase {
    func testGenerateReturns6Bytes() {
        let guid = GUIDFactory.generate()
        XCTAssertEqual(guid.count, 6)
    }

    func testGenerateProducesDifferentGUIDs() {
        let guid1 = GUIDFactory.generate()
        let guid2 = GUIDFactory.generate()
        XCTAssertNotEqual(guid1, guid2)
    }

    func testPadGUID() {
        let short = Data([0x01, 0x02])
        let padded = GUIDFactory.pad(guid: short)
        XCTAssertEqual(padded.count, 6)
        XCTAssertEqual(padded, Data([0x01, 0x02, 0x00, 0x00, 0x00, 0x00]))
    }

    func testPadGUIDExact6Bytes() {
        let exact = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let padded = GUIDFactory.pad(guid: exact)
        XCTAssertEqual(padded, exact)
    }

    func testFromHex() {
        let guid = GUIDFactory.fromHex("010203040506")
        XCTAssertEqual(guid, Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
    }

    func testToHex() {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let hex = GUIDFactory.toHex(guid)
        XCTAssertEqual(hex, "010203040506")
    }

    func testHexRoundtrip() {
        let original = Data([0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff])
        let hex = GUIDFactory.toHex(original)
        let restored = GUIDFactory.fromHex(hex)
        XCTAssertEqual(restored, original)
    }

    func testGUIDToHex() {
        let guid = Data([0xE3, 0x2E, 0x3C, 0xA7, 0x02, 0xDE])
        XCTAssertEqual(GUIDFactory.guidToHex(guid), "E32E3CA702DE")
        XCTAssertEqual(GUIDFactory.guidToHex(Data(repeating: 0, count: 6)), "000000000000")
    }
}
