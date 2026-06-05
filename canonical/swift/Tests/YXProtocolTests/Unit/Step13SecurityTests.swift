import XCTest
import Foundation
@testable import YXProtocol

final class ReplayProtectionTests: XCTestCase {

    func testFirstRequestAllowed() async {
        let rp = ReplayProtection()
        let allowed = await rp.checkAndRecord(nonce: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        XCTAssertTrue(allowed)
    }

    func testDuplicateRequestBlocked() async {
        let rp = ReplayProtection()
        let nonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        _ = await rp.checkAndRecord(nonce: nonce)
        let allowed = await rp.checkAndRecord(nonce: nonce)
        XCTAssertFalse(allowed)
    }

    func testDifferentNoncesAllowed() async {
        let rp = ReplayProtection()
        let allowed1 = await rp.checkAndRecord(nonce: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
        let allowed2 = await rp.checkAndRecord(nonce: Data([0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C]))
        XCTAssertTrue(allowed1)
        XCTAssertTrue(allowed2)
    }

    func testHasSeen() async {
        let rp = ReplayProtection()
        let nonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let seenBefore = await rp.hasSeen(nonce: nonce)
        XCTAssertFalse(seenBefore)
        _ = await rp.checkAndRecord(nonce: nonce)
        let seenAfter = await rp.hasSeen(nonce: nonce)
        XCTAssertTrue(seenAfter)
    }

    func testCleanup() async {
        let rp = ReplayProtection(maxAge: 1.0, cleanupInterval: 5)
        for i in 0..<10 {
            _ = await rp.checkAndRecord(nonce: Data([UInt8(i)]))
        }
        let before = await rp.count()
        XCTAssertEqual(before, 10)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        for i in 10..<15 {
            _ = await rp.checkAndRecord(nonce: Data([UInt8(i)]))
        }
        let count = await rp.count()
        XCTAssertLessThan(count, 15)
    }
}

final class RateLimiterTests: XCTestCase {

    func testDefaultIs10000() async {
        let rl = RateLimiter()
        let config = await rl.getConfig()
        XCTAssertEqual(config.maxRequests, 10_000, "CRITICAL: Default maxRequests must be 10,000 (SDTS Issue #2)")
        XCTAssertEqual(config.windowSeconds, 60.0)
    }

    func testRequestsAllowedUnderLimit() async {
        let rl = RateLimiter(maxRequests: 5, windowSeconds: 60.0)
        for i in 0..<5 {
            let allowed = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
            XCTAssertTrue(allowed, "Request \(i) should be allowed")
        }
    }

    func testRequestBlockedOverLimit() async {
        let rl = RateLimiter(maxRequests: 5, windowSeconds: 60.0)
        for _ in 0..<5 { _ = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000") }
        let allowed = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        XCTAssertFalse(allowed)
    }

    func testSlidingWindow() async {
        let rl = RateLimiter(maxRequests: 3, windowSeconds: 1.0)
        for _ in 0..<3 { _ = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000") }
        let blocked = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        XCTAssertFalse(blocked)
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        let allowedAfter = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        XCTAssertTrue(allowedAfter)
    }

    func testPerPeerLimits() async {
        let rl = RateLimiter(maxRequests: 2, windowSeconds: 60.0)
        let p1a = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        let p1b = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        let p2a = await rl.checkRateLimit(peerID: "peer2", sourceAddr: "127.0.0.1:5001")
        let p2b = await rl.checkRateLimit(peerID: "peer2", sourceAddr: "127.0.0.1:5001")
        let p1c = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        let p2c = await rl.checkRateLimit(peerID: "peer2", sourceAddr: "127.0.0.1:5001")
        XCTAssertTrue(p1a); XCTAssertTrue(p1b)
        XCTAssertTrue(p2a); XCTAssertTrue(p2b)
        XCTAssertFalse(p1c); XCTAssertFalse(p2c)
    }

    func testHighFrequencyTrading() async {
        let rl = RateLimiter(maxRequests: 10_000, windowSeconds: 60.0)
        var blockedCount = 0
        for _ in 0..<10_000 {
            let allowed = await rl.checkRateLimit(peerID: "hft-peer", sourceAddr: "127.0.0.1:6000")
            if !allowed { blockedCount += 1 }
        }
        XCTAssertEqual(blockedCount, 0, "No requests should be blocked with 10,000 limit")
        let blocked = await rl.checkRateLimit(peerID: "hft-peer", sourceAddr: "127.0.0.1:6000")
        XCTAssertFalse(blocked)
    }
}

final class KeyStoreTests: XCTestCase {

    func testSetAndGetHMACKey() async {
        let ks = KeyStore()
        let hmacKey = Data(repeating: 0x42, count: 32)
        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey)
        let retrieved = await ks.getHMACKey(peerID: "peer1")
        XCTAssertEqual(retrieved, hmacKey)
    }

    func testSetAndGetEncryptionKey() async {
        let ks = KeyStore()
        let encKey = Data(repeating: 0x99, count: 32)
        await ks.setKeys(peerID: "peer1", hmacKey: Data(repeating: 0x42, count: 32), encryptionKey: encKey)
        let retrieved = await ks.getEncryptionKey(peerID: "peer1")
        XCTAssertEqual(retrieved, encKey)
    }

    func testMissingKeys() async {
        let ks = KeyStore()
        let hmac = await ks.getHMACKey(peerID: "unknown")
        let enc = await ks.getEncryptionKey(peerID: "unknown")
        let both = await ks.getKeys(peerID: "unknown")
        XCTAssertNil(hmac)
        XCTAssertNil(enc)
        XCTAssertNil(both)
    }

    func testRemoveKeys() async {
        let ks = KeyStore()
        await ks.setKeys(peerID: "peer1", hmacKey: Data(repeating: 0x42, count: 32))
        let has1 = await ks.hasKeys(peerID: "peer1")
        XCTAssertTrue(has1)
        await ks.removeKeys(peerID: "peer1")
        let has2 = await ks.hasKeys(peerID: "peer1")
        XCTAssertFalse(has2)
    }

    func testGetAllPeerIDs() async {
        let ks = KeyStore()
        let hmacKey = Data(repeating: 0x42, count: 32)
        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey)
        await ks.setKeys(peerID: "peer2", hmacKey: hmacKey)
        await ks.setKeys(peerID: "peer3", hmacKey: hmacKey)
        let peerIDs = await ks.getAllPeerIDs()
        XCTAssertEqual(peerIDs.count, 3)
    }
}

final class SecurityIntegrationTests: XCTestCase {

    func testSecurityStack() async throws {
        let rl = RateLimiter(maxRequests: 3, windowSeconds: 60.0)
        let rp = ReplayProtection()
        let ks = KeyStore()
        await ks.setKeys(peerID: "peer1", hmacKey: Data(repeating: 0x42, count: 32))

        for i in 0..<3 {
            let rateOK = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
            let replayOK = await rp.checkAndRecord(nonce: Data([UInt8(i)]))
            XCTAssertTrue(rateOK)
            XCTAssertTrue(replayOK)
        }

        let rateBlocked = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        let replayBlocked = await rp.checkAndRecord(nonce: Data([0x00]))
        XCTAssertFalse(rateBlocked)
        XCTAssertFalse(replayBlocked)
    }
}
