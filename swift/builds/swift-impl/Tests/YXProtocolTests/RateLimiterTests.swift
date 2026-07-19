import XCTest
@testable import YXProtocol

final class RateLimiterTests: XCTestCase {

    func testDefaultIs10000() async {
        let rl = RateLimiter()
        let max = await rl.configuredMaxRequests
        XCTAssertEqual(max, 10000, "CRITICAL: default must be 10,000 per SDTS Issue #2")
    }

    func testAllowsRequests() async {
        let rl = RateLimiter(maxRequests: 5)
        for _ in 0..<5 {
            let allowed = await rl.checkRateLimit(peerID: "peer1")
            XCTAssertTrue(allowed)
        }
    }

    func testBlocksExcessRequests() async {
        let rl = RateLimiter(maxRequests: 3)
        for _ in 0..<3 {
            _ = await rl.checkRateLimit(peerID: "peer1")
        }
        let blocked = await rl.checkRateLimit(peerID: "peer1")
        XCTAssertFalse(blocked)
    }

    func testTrustedGUIDBypass() async {
        let rl = RateLimiter(maxRequests: 1)
        await rl.addTrustedGUID("TRUSTED-PEER")
        _ = await rl.checkRateLimit(peerID: "TRUSTED-PEER")
        let allowed = await rl.checkRateLimit(peerID: "TRUSTED-PEER")
        XCTAssertTrue(allowed, "Trusted GUIDs bypass rate limits")
    }

    func testResetPeer() async {
        let rl = RateLimiter(maxRequests: 2)
        _ = await rl.checkRateLimit(peerID: "peer1")
        _ = await rl.checkRateLimit(peerID: "peer1")
        let blocked = await rl.checkRateLimit(peerID: "peer1")
        XCTAssertFalse(blocked)

        await rl.resetPeer("peer1")
        let allowed = await rl.checkRateLimit(peerID: "peer1")
        XCTAssertTrue(allowed)
    }

    func testDifferentPeersIndependent() async {
        let rl = RateLimiter(maxRequests: 1)
        _ = await rl.checkRateLimit(peerID: "peer1")
        let peer1Blocked = await rl.checkRateLimit(peerID: "peer1")
        XCTAssertFalse(peer1Blocked)

        let peer2Allowed = await rl.checkRateLimit(peerID: "peer2")
        XCTAssertTrue(peer2Allowed)
    }
}
