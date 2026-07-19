// filename: MockNetworkingTests.swift

import XCTest
import CryptoKit
@testable import Transport

final class MockNetworkingTests: XCTestCase {

    func testMockNetworkingInitialization() async {
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let mock = MockNetworking(guid: guid, key: key)

        let mockGuid = await mock.guid
        let mockKey = await mock.key

        XCTAssertEqual(mockGuid, guid, "GUID should match")
        XCTAssertEqual(mockKey.bitCount, key.bitCount, "Key sizes should match")
    }

    func testSendCapturesPacket() async {
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let mock = MockNetworking(guid: guid, key: key)

        let packet = MockPacket.text(from: guid, message: "Hello")
        await mock.send(packet, to: "127.0.0.1", port: 9999)

        let sentCount = await mock.sentCount
        XCTAssertEqual(sentCount, 1, "Should have captured 1 packet")

        let last = await mock.lastSentPacket
        XCTAssertNotNil(last, "Should have last sent packet")
        XCTAssertEqual(last?.host, "127.0.0.1", "Host should match")
        XCTAssertEqual(last?.port, 9999, "Port should match")
    }

    func testInjectPacket() async {
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let mock = MockNetworking(guid: guid, key: key)

        await mock.inject(MockPacket.text(from: guid, message: "Test"))

        let drained = await mock.drainInjectQueue()
        XCTAssertEqual(drained.count, 1, "Should have 1 injected packet")
        XCTAssertEqual(drained.first?.protocolID, 0x00, "Should be text protocol")
    }

    func testOnReceiveHandler() async {
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let mock = MockNetworking(guid: guid, key: key)

        let expectation = XCTestExpectation(description: "onReceive called")
        await mock.setOnReceive { packet in
            XCTAssertEqual(packet.protocolID, 0x00, "Should be text protocol")
            expectation.fulfill()
        }

        await mock.inject(MockPacket.text(from: guid, message: "Test"))

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testStartStop() async {
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let mock = MockNetworking(guid: guid, key: key)

        var running = await mock.isRunning
        XCTAssertFalse(running, "Should not be running initially")

        await mock.start(port: 9999)
        running = await mock.isRunning
        XCTAssertTrue(running, "Should be running after start")

        await mock.stop()
        running = await mock.isRunning
        XCTAssertFalse(running, "Should not be running after stop")
    }

    func testClearSentPackets() async {
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let mock = MockNetworking(guid: guid, key: key)

        await mock.send(MockPacket.text(from: guid, message: "Test1"), to: "127.0.0.1", port: 9999)
        await mock.send(MockPacket.text(from: guid, message: "Test2"), to: "127.0.0.1", port: 9999)

        var count = await mock.sentCount
        XCTAssertEqual(count, 2, "Should have 2 packets before clear")

        await mock.clearSentPackets()
        count = await mock.sentCount
        XCTAssertEqual(count, 0, "Should have 0 packets after clear")
    }

    func testMockPacketCreation() {
        let guid = Data([1, 2, 3, 4])

        let textPacket = MockPacket.text(from: guid, message: "Hello")
        XCTAssertEqual(textPacket.protocolID, 0x00, "Text packet should have protocol 0x00")
        XCTAssertEqual(textPacket.guid, guid, "GUID should match")

        let binaryPacket = MockPacket.binary(from: guid, data: Data([5, 6, 7, 8]))
        XCTAssertEqual(binaryPacket.protocolID, 0x01, "Binary packet should have protocol 0x01")

        let rpcPacket = MockPacket.rpc(from: guid, json: "{\"method\":\"ping\"}")
        XCTAssertEqual(rpcPacket.protocolID, 0x22, "RPC packet should have protocol 0x22")
    }

    func testMockRouter() async {
        let router = MockRouter()
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let packet = MockPacket.text(from: guid, message: "Test")

        await router.route(packet, key: key)

        let count = await router.routedCount
        XCTAssertEqual(count, 1, "Should have 1 routed packet")

        await router.clear()
        let clearedCount = await router.routedCount
        XCTAssertEqual(clearedCount, 0, "Should have 0 packets after clear")
    }

    func testMockRouterOnRouteHandler() async {
        let router = MockRouter()
        let guid = Data([1, 2, 3, 4])
        let key = SymmetricKey(size: .bits256)
        let packet = MockPacket.text(from: guid, message: "Test")

        let expectation = XCTestExpectation(description: "onRoute called")
        await router.setOnRoute { packet, key in
            XCTAssertEqual(packet.protocolID, 0x00, "Should be text protocol")
            expectation.fulfill()
        }

        await router.route(packet, key: key)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testMockRateLimiter() async {
        let limiter = MockRateLimiter()
        let peer = "peer-123"

        let allowed1 = await limiter.checkLimit(for: peer)
        XCTAssertTrue(allowed1, "Should allow first request")

        await limiter.block(peer: peer)

        let allowed2 = await limiter.checkLimit(for: peer)
        XCTAssertFalse(allowed2, "Should block after blocking")

        await limiter.unblock(peer: peer)

        let allowed3 = await limiter.checkLimit(for: peer)
        XCTAssertTrue(allowed3, "Should allow after unblocking")
    }

    func testMockRateLimiterRequestCount() async {
        let limiter = MockRateLimiter()
        let peer = "peer-123"

        _ = await limiter.checkLimit(for: peer)
        _ = await limiter.checkLimit(for: peer)
        _ = await limiter.checkLimit(for: peer)

        let count = await limiter.requestCount(for: peer)
        XCTAssertEqual(count, 3, "Should have 3 requests")

        await limiter.reset()
        let resetCount = await limiter.requestCount(for: peer)
        XCTAssertEqual(resetCount, 0, "Should have 0 requests after reset")
    }

    func testMockReplayProtection() async {
        let cache = MockReplayProtection()
        let nonce = Data([1, 2, 3, 4])

        let allowed1 = await cache.checkAndRecord(nonce)
        XCTAssertTrue(allowed1, "Should allow new nonce")

        let allowed2 = await cache.checkAndRecord(nonce)
        XCTAssertFalse(allowed2, "Should reject duplicate nonce")

        let count = await cache.count
        XCTAssertEqual(count, 1, "Should have 1 nonce")

        await cache.clear()
        let clearedCount = await cache.count
        XCTAssertEqual(clearedCount, 0, "Should have 0 nonces after clear")
    }

    func testMockReplayProtectionRejectNext() async {
        let cache = MockReplayProtection()
        let nonce = Data([1, 2, 3, 4])

        await cache.rejectNext()

        let allowed = await cache.checkAndRecord(nonce)
        XCTAssertFalse(allowed, "Should reject when rejectNext is set")

        // Next one should work
        let allowed2 = await cache.checkAndRecord(Data([5, 6, 7, 8]))
        XCTAssertTrue(allowed2, "Should allow after rejectNext is consumed")
    }
}
