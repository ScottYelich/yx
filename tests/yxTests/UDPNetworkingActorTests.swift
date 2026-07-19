// filename: UDPTransportTests.swift

import XCTest
@testable import Transport
import CryptoKit
import Foundation

@MainActor
final class UDPTransportTests: XCTestCase {

    func testActorInitialization() async {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let key = SymmetricKey(size: .bits256)
        let router = ProtocolRouter()

        let actor = UDPTransport(guid: guid, key: key, router: router)
        let localGUID = await actor.localGUID

        XCTAssertEqual(localGUID, guid)
    }

    func testKeyManagement() async {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let key = SymmetricKey(size: .bits256)
        let router = ProtocolRouter()

        let actor = UDPTransport(guid: guid, key: key, router: router)

        // Set key for peer
        let peerGUID = Data([0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA])
        let peerKey = SymmetricKey(size: .bits256)
        await actor.setKey(for: peerGUID, key: peerKey)

        // Retrieve key
        let retrieved = await actor.key(for: peerGUID)
        XCTAssertNotNil(retrieved)
    }

    func testGracefulShutdown() async throws {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let key = SymmetricKey(size: .bits256)
        let router = ProtocolRouter()

        let actor = UDPTransport(guid: guid, key: key, router: router)

        // This should not crash or hang
        await actor.stop()

        // Can call stop multiple times
        await actor.stop()
    }

    func testProcessOwnPacketsFlag() async {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let key = SymmetricKey(size: .bits256)
        let router = ProtocolRouter()

        let actor = UDPTransport(guid: guid, key: key, router: router)

        // Default should be false
        let initialValue = await actor.processOwnPackets
        XCTAssertFalse(initialValue)

        // Set to true
        await actor.setProcessOwnPackets(true)
        let newValue = await actor.processOwnPackets
        XCTAssertTrue(newValue)
    }

    func testAllKeysRetrieval() async {
        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let key = SymmetricKey(size: .bits256)
        let router = ProtocolRouter()

        let actor = UDPTransport(guid: guid, key: key, router: router)

        // Initially empty
        var allKeys = await actor.allKeys()
        XCTAssertTrue(allKeys.isEmpty)

        // Add some keys
        let peer1 = Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
        let peer2 = Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
        await actor.setKey(for: peer1, key: SymmetricKey(size: .bits256))
        await actor.setKey(for: peer2, key: SymmetricKey(size: .bits256))

        // Should have 2 keys now
        allKeys = await actor.allKeys()
        XCTAssertEqual(allKeys.count, 2)
        XCTAssertTrue(allKeys.keys.contains(peer1))
        XCTAssertTrue(allKeys.keys.contains(peer2))
    }
}
