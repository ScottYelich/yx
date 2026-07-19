// filename: CommonUtilsTests.swift

import XCTest
import Foundation
@testable import Primitives

final class CommonUtilsTests: XCTestCase {

    func testGUIDFactory() {
        // Example test case for GUIDFactory
        let guid = GUIDFactory.random()
        XCTAssertNotNil(guid, "GUID should not be nil")
        XCTAssertEqual(guid.count, 6, "GUID should be exactly 6 bytes")
    }

    func testHexStringConversion() {
        // Example test for hexString method
        let data = Data([0x12, 0x34, 0x56])
        let hexString = data.hexString
        XCTAssertEqual(hexString, "123456", "Hex string conversion failed")
    }
}
