// filename: ProtocolIDTests.swift

import XCTest
import Foundation
@testable import Transport

@MainActor
final class ProtocolIDTests: XCTestCase {

    func testAllIDsAreUnique() {
        let ids = ProtocolID.allCases.map(\.rawValue)
        let uniqueIds = Set(ids)

        XCTAssertEqual(ids.count, uniqueIds.count,
                      "Protocol IDs must be unique")
    }

    func testNoCollisions() {
        var seen: Set<UInt8> = []

        for proto in ProtocolID.allCases {
            XCTAssertFalse(seen.contains(proto.rawValue),
                          "Collision detected: \(proto.name) uses \(proto.rawValue)")
            seen.insert(proto.rawValue)
        }
    }

    func testNamesAreReadable() {
        for proto in ProtocolID.allCases {
            XCTAssertFalse(proto.name.isEmpty,
                          "Protocol \(proto.rawValue) has no name")
        }
    }

    func testValidationDoesNotCrash() {
        // Should not crash or throw assertion in tests
        ProtocolID.validateUniqueness()
    }
}
