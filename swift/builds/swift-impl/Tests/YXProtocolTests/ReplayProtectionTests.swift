import XCTest
@testable import YXProtocol

final class ReplayProtectionTests: XCTestCase {

    func testAllowsNew() async {
        let rp = ReplayProtection()
        let result = await rp.checkAndRecord(nonce: Data([1, 2, 3, 4, 5, 6]))
        XCTAssertTrue(result)
    }

    func testBlocksDuplicate() async {
        let rp = ReplayProtection()
        let nonce = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        _ = await rp.checkAndRecord(nonce: nonce)
        let result = await rp.checkAndRecord(nonce: nonce)
        XCTAssertFalse(result)
    }

    func testCount() async {
        let rp = ReplayProtection()
        let c0 = await rp.count
        XCTAssertEqual(c0, 0)
        _ = await rp.checkAndRecord(nonce: Data([1]))
        _ = await rp.checkAndRecord(nonce: Data([2]))
        let c2 = await rp.count
        XCTAssertEqual(c2, 2)
    }

    func testClear() async {
        let rp = ReplayProtection()
        _ = await rp.checkAndRecord(nonce: Data([1]))
        await rp.clear()
        let count = await rp.count
        XCTAssertEqual(count, 0)
    }

    func testDifferentNoncesAllowed() async {
        let rp = ReplayProtection()
        let r1 = await rp.checkAndRecord(nonce: Data([0x01]))
        let r2 = await rp.checkAndRecord(nonce: Data([0x02]))
        XCTAssertTrue(r1)
        XCTAssertTrue(r2)
    }
}
