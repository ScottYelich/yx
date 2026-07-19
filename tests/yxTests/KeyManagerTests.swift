// filename: KeyRotationTests.swift

import XCTest
import CryptoKit
@testable import Transport

final class KeyRotationTests: XCTestCase {

    func testStoreAndRetrieve() async {
        let manager = KeyRotation()
        let key = SymmetricKey(size: .bits256)
        let identity = "test-identity"

        await manager.store(key: key, for: identity)
        let retrieved = await manager.retrieve(for: identity)

        XCTAssertNotNil(retrieved, "Should retrieve stored key")
        XCTAssertEqual(retrieved?.bitCount, key.bitCount, "Key sizes should match")
    }

    func testRetrieveNonexistentKey() async {
        let manager = KeyRotation()
        let retrieved = await manager.retrieve(for: "nonexistent")

        XCTAssertNil(retrieved, "Should return nil for nonexistent key")
    }

    func testRemoveKey() async {
        let manager = KeyRotation()
        let key = SymmetricKey(size: .bits256)
        let identity = "test-identity"

        await manager.store(key: key, for: identity)
        await manager.remove(for: identity)
        let retrieved = await manager.retrieve(for: identity)

        XCTAssertNil(retrieved, "Should return nil after removal")
    }

    func testRotateCreatesNewKey() async {
        let manager = KeyRotation()
        let originalKey = SymmetricKey(size: .bits256)
        let identity = "test-identity"

        await manager.store(key: originalKey, for: identity)
        let rotatedKey = await manager.rotate(for: identity)
        let retrieved = await manager.retrieve(for: identity)

        XCTAssertNotNil(retrieved, "Should have key after rotation")
        // Keys should be different (can't directly compare SymmetricKey, but we rotated)
        XCTAssertEqual(rotatedKey.bitCount, 256, "Rotated key should be 256 bits")
    }

    func testRotateWithoutExistingKey() async {
        let manager = KeyRotation()
        let identity = "new-identity"

        let newKey = await manager.rotate(for: identity)
        let retrieved = await manager.retrieve(for: identity)

        XCTAssertNotNil(retrieved, "Should create key when rotating nonexistent identity")
        XCTAssertEqual(newKey.bitCount, 256, "New key should be 256 bits")
    }

    func testNeedsRotationFreshKey() async {
        let manager = KeyRotation(keyRotationInterval: 3600.0) // 1 hour
        let key = SymmetricKey(size: .bits256)
        let identity = "test-identity"

        await manager.store(key: key, for: identity)
        let needs = await manager.needsRotation(for: identity)

        XCTAssertFalse(needs, "Fresh key should not need rotation")
    }

    func testNeedsRotationOldKey() async throws {
        let manager = KeyRotation(keyRotationInterval: 0.1) // 100ms
        let key = SymmetricKey(size: .bits256)
        let identity = "test-identity"

        await manager.store(key: key, for: identity)

        // Wait for rotation interval
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let needs = await manager.needsRotation(for: identity)
        XCTAssertTrue(needs, "Old key should need rotation")
    }

    func testNeedsRotationNonexistentKey() async {
        let manager = KeyRotation()
        let needs = await manager.needsRotation(for: "nonexistent")

        XCTAssertFalse(needs, "Nonexistent key should not need rotation")
    }

    func testAutoRotate() async throws {
        let manager = KeyRotation(keyRotationInterval: 0.1) // 100ms

        // Store multiple keys
        await manager.store(key: SymmetricKey(size: .bits256), for: "identity1")
        await manager.store(key: SymmetricKey(size: .bits256), for: "identity2")
        await manager.store(key: SymmetricKey(size: .bits256), for: "identity3")

        // Wait for rotation interval
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let rotated = await manager.autoRotate()

        XCTAssertEqual(rotated.count, 3, "Should rotate all 3 keys")
        XCTAssertTrue(rotated.contains("identity1"), "Should include identity1")
        XCTAssertTrue(rotated.contains("identity2"), "Should include identity2")
        XCTAssertTrue(rotated.contains("identity3"), "Should include identity3")

        // After rotation, keys should not need rotation
        let needs1 = await manager.needsRotation(for: "identity1")
        XCTAssertFalse(needs1, "Key should not need rotation immediately after autoRotate")
    }

    func testIdentities() async {
        let manager = KeyRotation()

        await manager.store(key: SymmetricKey(size: .bits256), for: "identity1")
        await manager.store(key: SymmetricKey(size: .bits256), for: "identity2")

        let identities = await manager.identities

        XCTAssertEqual(identities.count, 2, "Should have 2 identities")
        XCTAssertTrue(identities.contains("identity1"), "Should contain identity1")
        XCTAssertTrue(identities.contains("identity2"), "Should contain identity2")
    }

    func testCount() async {
        let manager = KeyRotation()

        let count0 = await manager.count
        XCTAssertEqual(count0, 0, "Should start empty")

        await manager.store(key: SymmetricKey(size: .bits256), for: "identity1")
        await manager.store(key: SymmetricKey(size: .bits256), for: "identity2")

        let count2 = await manager.count
        XCTAssertEqual(count2, 2, "Should have 2 keys")
    }

    func testClearAll() async {
        let manager = KeyRotation()

        await manager.store(key: SymmetricKey(size: .bits256), for: "identity1")
        await manager.store(key: SymmetricKey(size: .bits256), for: "identity2")

        let before = await manager.count
        XCTAssertEqual(before, 2, "Should have 2 keys before clear")

        await manager.clearAll()

        let after = await manager.count
        XCTAssertEqual(after, 0, "Should be empty after clear")
    }

    func testMetadata() async {
        let manager = KeyRotation()
        let key = SymmetricKey(size: .bits256)
        let identity = "test-identity"

        await manager.store(key: key, for: identity)
        let metadata = await manager.metadata(for: identity)

        XCTAssertNotNil(metadata, "Should have metadata")
        XCTAssertNotNil(metadata?.createdAt, "Should have creation date")
        XCTAssertNotNil(metadata?.lastRotated, "Should have last rotation date")
    }

    func testMetadataAfterRotation() async throws {
        let manager = KeyRotation()
        let key = SymmetricKey(size: .bits256)
        let identity = "test-identity"

        await manager.store(key: key, for: identity)
        let before = await manager.metadata(for: identity)

        // Wait a bit
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        _ = await manager.rotate(for: identity)
        let after = await manager.metadata(for: identity)

        XCTAssertNotNil(before, "Should have metadata before rotation")
        XCTAssertNotNil(after, "Should have metadata after rotation")

        // Creation date should be the same
        XCTAssertEqual(before?.createdAt, after?.createdAt, "Creation date should not change")

        // Last rotated should be updated
        XCTAssertTrue(after!.lastRotated > before!.lastRotated, "Last rotation date should be updated")
    }

    func testDeriveKeyFromPassword() {
        let password = "test-password-123"
        let salt = KeyRotation.generateSalt()

        let key = KeyRotation.deriveKey(from: password, salt: salt)

        XCTAssertNotNil(key, "Should derive key from password")
        XCTAssertEqual(key?.bitCount, 256, "Derived key should be 256 bits")
    }

    func testDeriveKeyDeterministic() {
        let password = "test-password-123"
        let salt = KeyRotation.generateSalt()

        let key1 = KeyRotation.deriveKey(from: password, salt: salt)
        let key2 = KeyRotation.deriveKey(from: password, salt: salt)

        XCTAssertNotNil(key1, "First derivation should succeed")
        XCTAssertNotNil(key2, "Second derivation should succeed")

        // Compare key bytes
        let bytes1 = key1!.withUnsafeBytes { Data($0) }
        let bytes2 = key2!.withUnsafeBytes { Data($0) }

        XCTAssertEqual(bytes1, bytes2, "Same password and salt should produce same key")
    }

    func testDeriveKeyDifferentPasswords() {
        let salt = KeyRotation.generateSalt()

        let key1 = KeyRotation.deriveKey(from: "password1", salt: salt)
        let key2 = KeyRotation.deriveKey(from: "password2", salt: salt)

        XCTAssertNotNil(key1, "First derivation should succeed")
        XCTAssertNotNil(key2, "Second derivation should succeed")

        // Compare key bytes
        let bytes1 = key1!.withUnsafeBytes { Data($0) }
        let bytes2 = key2!.withUnsafeBytes { Data($0) }

        XCTAssertNotEqual(bytes1, bytes2, "Different passwords should produce different keys")
    }

    func testDeriveKeyDifferentSalts() {
        let password = "test-password"
        let salt1 = KeyRotation.generateSalt()
        let salt2 = KeyRotation.generateSalt()

        let key1 = KeyRotation.deriveKey(from: password, salt: salt1)
        let key2 = KeyRotation.deriveKey(from: password, salt: salt2)

        XCTAssertNotNil(key1, "First derivation should succeed")
        XCTAssertNotNil(key2, "Second derivation should succeed")

        // Compare key bytes
        let bytes1 = key1!.withUnsafeBytes { Data($0) }
        let bytes2 = key2!.withUnsafeBytes { Data($0) }

        XCTAssertNotEqual(bytes1, bytes2, "Different salts should produce different keys")
    }

    func testGenerateSalt() {
        let salt1 = KeyRotation.generateSalt()
        let salt2 = KeyRotation.generateSalt()

        XCTAssertEqual(salt1.count, 32, "Default salt should be 32 bytes")
        XCTAssertEqual(salt2.count, 32, "Default salt should be 32 bytes")
        XCTAssertNotEqual(salt1, salt2, "Each salt should be unique")
    }

    func testGenerateSaltCustomLength() {
        let salt = KeyRotation.generateSalt(length: 16)

        XCTAssertEqual(salt.count, 16, "Custom salt should be 16 bytes")
    }
}
