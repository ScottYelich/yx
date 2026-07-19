// filename: PacketCoreTests.swift

import XCTest
import Transport
import CryptoKit

final class PacketCoreTests: XCTestCase {

    func testPacketCreation() {
        let guid = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
        let payload = Data([0x01, 0x02, 0x03])
        let key = SymmetricKey(size: .bits256)

        let packet = UDPPacketUtils.build(guid: guid, bytesAfterGUID: payload, key: key)

        XCTAssertNotNil(packet, "Packet should not be nil")
        XCTAssertEqual(packet.state, .valid, "Packet should be valid")
        XCTAssertEqual(packet.guid, guid, "GUID should match")
        XCTAssertEqual(packet.bytesAfterGUID, payload, "Payload mismatch")
    }

    func testPacketParsing() {
        let guid = Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let key = SymmetricKey(size: .bits256)

        let packet = UDPPacketUtils.build(guid: guid, bytesAfterGUID: payload, key: key)
        let parsed = UDPPacketUtils.parse(packet.bytes, key: key)

        XCTAssertEqual(parsed.guid, guid, "Parsed GUID mismatch")
        XCTAssertEqual(parsed.bytesAfterGUID, payload, "Parsed payload mismatch")
        XCTAssertEqual(parsed.state, .valid, "Packet should be valid")
    }
}

