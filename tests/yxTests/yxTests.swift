// filename: yxTests.swift

import XCTest
import CryptoKit

@testable import Primitives
@testable import Transport
@testable import RPC

class yxTests: XCTestCase {

    // Example test case for CommonUtils
    func testHexString() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let hexString = data.hexString
        XCTAssertEqual(hexString, "01020304")
    }

    // Example test case for PacketCore
    func testPacketCreation() {
        let guid = Data([0x01, 0x02, 0x03])
        let packet = UDPPacketUtils.build(
            guid: guid,
            bytesAfterGUID: Data([0x05, 0x06]),
            key: SymmetricKey(size: .bits256)
        )
        XCTAssertNotNil(packet)
    }
}


