// filename: RateLimiterTests.swift

import XCTest
@testable import Transport

final class RateLimiterTests: XCTestCase {

    func testRateLimitAllowsUnderLimit() async {
        let limiter = RateLimiter(maxRequests: 10, windowDuration: 60.0)

        // Make 10 requests - all should be allowed
        for _ in 0..<10 {
            let allowed = await limiter.checkLimit(for: "peer1")
            XCTAssertTrue(allowed, "Request should be allowed under limit")
        }
    }

    func testRateLimitBlocksOverLimit() async {
        let limiter = RateLimiter(maxRequests: 5, windowDuration: 60.0)

        // Make 5 requests - all allowed
        for i in 0..<5 {
            let allowed = await limiter.checkLimit(for: "peer1")
            XCTAssertTrue(allowed, "Request \(i) should be allowed")
        }

        // 6th request should be blocked
        let blockedRequest = await limiter.checkLimit(for: "peer1")
        XCTAssertFalse(blockedRequest, "Request over limit should be blocked")
    }

    func testRateLimitWindowExpiry() async throws {
        let limiter = RateLimiter(maxRequests: 2, windowDuration: 0.1) // 100ms window

        // Make 2 requests
        _ = await limiter.checkLimit(for: "peer1")
        _ = await limiter.checkLimit(for: "peer1")

        // 3rd request blocked
        let blocked = await limiter.checkLimit(for: "peer1")
        XCTAssertFalse(blocked, "Should be rate limited")

        // Wait for window to expire
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // Should be allowed again after window expires
        let allowed = await limiter.checkLimit(for: "peer1")
        XCTAssertTrue(allowed, "Should be allowed after window expires")
    }

    func testRateLimitPerPeerIsolation() async {
        let limiter = RateLimiter(maxRequests: 2, windowDuration: 60.0)

        // Peer1 makes 2 requests
        _ = await limiter.checkLimit(for: "peer1")
        _ = await limiter.checkLimit(for: "peer1")

        // Peer1 is now limited
        let peer1Blocked = await limiter.checkLimit(for: "peer1")
        XCTAssertFalse(peer1Blocked, "Peer1 should be limited")

        // Peer2 should still be allowed
        let peer2Allowed = await limiter.checkLimit(for: "peer2")
        XCTAssertTrue(peer2Allowed, "Peer2 should be independent")
    }

    func testRequestCount() async {
        let limiter = RateLimiter(maxRequests: 10, windowDuration: 60.0)

        // Make 3 requests
        for _ in 0..<3 {
            _ = await limiter.checkLimit(for: "peer1")
        }

        let count = await limiter.requestCount(for: "peer1")
        XCTAssertEqual(count, 3, "Should track 3 requests")
    }

    func testReset() async {
        let limiter = RateLimiter(maxRequests: 2, windowDuration: 60.0)

        // Fill up the limit
        _ = await limiter.checkLimit(for: "peer1")
        _ = await limiter.checkLimit(for: "peer1")

        // Should be blocked
        let blocked = await limiter.checkLimit(for: "peer1")
        XCTAssertFalse(blocked)

        // Reset peer1
        await limiter.reset(for: "peer1")

        // Should be allowed again
        let allowed = await limiter.checkLimit(for: "peer1")
        XCTAssertTrue(allowed, "Should be allowed after reset")
    }

    func testCleanup() async {
        let limiter = RateLimiter(maxRequests: 10, windowDuration: 60.0)

        // Add some requests
        _ = await limiter.checkLimit(for: "peer1")
        _ = await limiter.checkLimit(for: "peer2")

        // Cleanup shouldn't affect recent requests
        await limiter.cleanup()

        let count1 = await limiter.requestCount(for: "peer1")
        let count2 = await limiter.requestCount(for: "peer2")

        XCTAssertEqual(count1, 1, "Peer1 request should still exist")
        XCTAssertEqual(count2, 1, "Peer2 request should still exist")
    }

    func testResetAll() async {
        let limiter = RateLimiter(maxRequests: 10, windowDuration: 60.0)

        // Add requests for multiple peers
        _ = await limiter.checkLimit(for: "peer1")
        _ = await limiter.checkLimit(for: "peer2")
        _ = await limiter.checkLimit(for: "peer3")

        // Reset all
        await limiter.resetAll()

        // All counts should be 0
        let count1 = await limiter.requestCount(for: "peer1")
        let count2 = await limiter.requestCount(for: "peer2")
        let count3 = await limiter.requestCount(for: "peer3")

        XCTAssertEqual(count1, 0, "All peers should be reset")
        XCTAssertEqual(count2, 0, "All peers should be reset")
        XCTAssertEqual(count3, 0, "All peers should be reset")
    }
}
