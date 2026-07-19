import XCTest
@testable import YXProtocol

final class KeyStoreTests: XCTestCase {

    func testDefaultKey() async throws {
        let defaultKey = Data(repeating: 0x00, count: 32)
        let ks = try KeyStore(defaultKey: defaultKey)
        let key = await ks.getKey(peerID: "unknown")
        XCTAssertEqual(key, defaultKey)
    }

    func testPeerSpecific() async throws {
        let defaultKey = Data(repeating: 0x00, count: 32)
        let peerKey = Data(repeating: 0xFF, count: 32)
        let ks = try KeyStore(defaultKey: defaultKey)
        try await ks.setKey(peerKey, for: "peer1")
        let key = await ks.getKey(peerID: "peer1")
        XCTAssertEqual(key, peerKey)
    }

    func testInvalidSize() async throws {
        let ks = try KeyStore(defaultKey: Data(repeating: 0, count: 32))
        do {
            try await ks.setKey(Data([1,2,3]), for: "peer1")
            XCTFail("Expected KeyStoreError.invalidKeySize to be thrown")
        } catch KeyStoreError.invalidKeySize {
            // expected
        }
    }

    func testRemoveKey() async throws {
        let defaultKey = Data(repeating: 0x00, count: 32)
        let ks = try KeyStore(defaultKey: defaultKey)
        try await ks.setKey(Data(repeating: 0xFF, count: 32), for: "peer1")
        let hasBefore = await ks.hasPeerKey("peer1")
        XCTAssertTrue(hasBefore)
        await ks.removeKey(for: "peer1")
        let hasAfter = await ks.hasPeerKey("peer1")
        XCTAssertFalse(hasAfter)
        let key = await ks.getKey(peerID: "peer1")
        XCTAssertEqual(key, defaultKey)
    }
}
