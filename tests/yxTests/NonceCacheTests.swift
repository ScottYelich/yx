// filename: ReplayProtectionTests.swift

import XCTest
@testable import Transport

final class ReplayProtectionTests: XCTestCase {

    func testNewNonceNotSeen() async {
        let cache = ReplayProtection()
        let nonce = Data([1, 2, 3, 4])

        let seen = await cache.hasSeen(nonce)
        XCTAssertFalse(seen, "New nonce should not be seen")
    }

    func testRecordedNonceIsSeen() async {
        let cache = ReplayProtection()
        let nonce = Data([1, 2, 3, 4])

        await cache.record(nonce)
        let seen = await cache.hasSeen(nonce)

        XCTAssertTrue(seen, "Recorded nonce should be seen")
    }

    func testCheckAndRecordNewNonce() async {
        let cache = ReplayProtection()
        let nonce = Data([1, 2, 3, 4])

        let allowed = await cache.checkAndRecord(nonce)
        XCTAssertTrue(allowed, "New nonce should be allowed")

        // Second attempt should be rejected
        let replay = await cache.checkAndRecord(nonce)
        XCTAssertFalse(replay, "Replay should be rejected")
    }

    func testDifferentNoncesAreIndependent() async {
        let cache = ReplayProtection()
        let nonce1 = Data([1, 2, 3, 4])
        let nonce2 = Data([5, 6, 7, 8])

        await cache.record(nonce1)

        let seen1 = await cache.hasSeen(nonce1)
        let seen2 = await cache.hasSeen(nonce2)

        XCTAssertTrue(seen1, "First nonce should be seen")
        XCTAssertFalse(seen2, "Second nonce should not be seen")
    }

    func testNonceExpiry() async throws {
        let cache = ReplayProtection(maxAge: 0.1) // 100ms expiry
        let nonce = Data([1, 2, 3, 4])

        await cache.record(nonce)

        // Should be seen immediately
        let seenBefore = await cache.hasSeen(nonce)
        XCTAssertTrue(seenBefore, "Should be seen before expiry")

        // Wait for expiry
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Should be expired now
        let seenAfter = await cache.hasSeen(nonce)
        XCTAssertFalse(seenAfter, "Should not be seen after expiry")
    }

    func testCount() async {
        let cache = ReplayProtection()

        let count0 = await cache.count
        XCTAssertEqual(count0, 0, "Should start empty")

        await cache.record(Data([1, 2, 3, 4]))
        await cache.record(Data([5, 6, 7, 8]))

        let count2 = await cache.count
        XCTAssertEqual(count2, 2, "Should have 2 nonces")
    }

    func testClear() async {
        let cache = ReplayProtection()

        await cache.record(Data([1, 2, 3, 4]))
        await cache.record(Data([5, 6, 7, 8]))

        let before = await cache.count
        XCTAssertEqual(before, 2, "Should have 2 before clear")

        await cache.clear()

        let after = await cache.count
        XCTAssertEqual(after, 0, "Should be empty after clear")
    }

    func testDateIsRecent() {
        let now = Date()
        let recent = now.addingTimeInterval(-100) // 100 seconds ago
        let old = now.addingTimeInterval(-400) // 400 seconds ago

        XCTAssertTrue(recent.isRecent(maxAge: 300), "Should be recent")
        XCTAssertFalse(old.isRecent(maxAge: 300), "Should not be recent")
    }

    func testFutureTimestampRejected() {
        let future = Date().addingTimeInterval(100) // 100 seconds in future

        XCTAssertFalse(future.isRecent(maxAge: 300), "Future timestamp should be rejected")
    }

    func testCleanupReducesMemory() async {
        let cache = ReplayProtection(maxAge: 0.05) // 50ms expiry

        // Add 10 nonces
        for i in 0..<10 {
            await cache.record(Data([UInt8(i)]))
        }

        let before = await cache.count
        XCTAssertEqual(before, 10, "Should have 10 nonces")

        // Wait for expiry
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Trigger cleanup by checking a nonce
        _ = await cache.hasSeen(Data([99]))

        let after = await cache.count
        XCTAssertEqual(after, 0, "Old nonces should be cleaned up")
    }
}
