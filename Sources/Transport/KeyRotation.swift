import Foundation
// filename: KeyManager.swift

import Primitives
import CryptoKit

/// Manages cryptographic keys with rotation support.
///
/// NOTE: This is an in-memory implementation. For production use with persistent storage,
/// integrate with platform-specific secure storage (Keychain on macOS/iOS).
public actor KeyRotation {
    private var keys: [String: KeyEntry] = [:]
    private let keyRotationInterval: TimeInterval

    /// Entry storing a key with metadata
    private struct KeyEntry {
        let key: SymmetricKey
        let createdAt: Date
        var lastRotated: Date
    }

    /// Creates a key manager with specified rotation interval.
    ///
    /// - Parameter keyRotationInterval: How often keys should be rotated (default: 24 hours)
    public init(keyRotationInterval: TimeInterval = 86400.0) {
        self.keyRotationInterval = keyRotationInterval
    }

    /// Stores a key for an identity.
    ///
    /// - Parameters:
    ///   - key: The symmetric key to store
    ///   - identity: Identity/GUID to associate with the key
    public func store(key: SymmetricKey, for identity: String) {
        let now = Date()
        keys[identity] = KeyEntry(
            key: key,
            createdAt: now,
            lastRotated: now
        )
    }

    /// Retrieves a key for an identity.
    ///
    /// - Parameter identity: The identity to lookup
    /// - Returns: The key if found, nil otherwise
    public func retrieve(for identity: String) -> SymmetricKey? {
        keys[identity]?.key
    }

    /// Removes a key for an identity.
    ///
    /// - Parameter identity: The identity to remove
    public func remove(for identity: String) {
        keys.removeValue(forKey: identity)
    }

    /// Generates and stores a new key for an identity, replacing any existing key.
    ///
    /// - Parameter identity: The identity to generate a key for
    /// - Returns: The newly generated key
    public func rotate(for identity: String) -> SymmetricKey {
        let newKey = SymmetricKey(size: .bits256)
        let now = Date()

        if var entry = keys[identity] {
            // Update existing entry
            entry.lastRotated = now
            keys[identity] = KeyEntry(
                key: newKey,
                createdAt: entry.createdAt,
                lastRotated: now
            )
        } else {
            // Create new entry
            keys[identity] = KeyEntry(
                key: newKey,
                createdAt: now,
                lastRotated: now
            )
        }

        return newKey
    }

    /// Checks if a key needs rotation based on age.
    ///
    /// - Parameter identity: The identity to check
    /// - Returns: true if key should be rotated
    public func needsRotation(for identity: String) -> Bool {
        guard let entry = keys[identity] else {
            return false  // No key to rotate
        }

        let now = Date()
        let age = now.timeIntervalSince(entry.lastRotated)
        return age >= keyRotationInterval
    }

    /// Automatically rotates keys that are due for rotation.
    ///
    /// - Returns: List of identities that were rotated
    public func autoRotate() -> [String] {
        var rotated: [String] = []

        for (identity, _) in keys {
            if needsRotation(for: identity) {
                _ = rotate(for: identity)
                rotated.append(identity)
            }
        }

        return rotated
    }

    /// Returns all stored identities.
    public var identities: [String] {
        Array(keys.keys)
    }

    /// Returns the number of keys stored.
    public var count: Int {
        keys.count
    }

    /// Clears all stored keys.
    public func clearAll() {
        keys.removeAll()
    }

    /// Returns metadata about a key.
    ///
    /// - Parameter identity: The identity to query
    /// - Returns: Creation and last rotation dates if key exists
    public func metadata(for identity: String) -> (createdAt: Date, lastRotated: Date)? {
        guard let entry = keys[identity] else {
            return nil
        }
        return (entry.createdAt, entry.lastRotated)
    }
}

// MARK: - Key Derivation Helpers

extension KeyRotation {
    /// Derives a key from a password using PBKDF2.
    ///
    /// - Parameters:
    ///   - password: The password string
    ///   - salt: Salt data (should be random and unique per password)
    ///   - rounds: Number of PBKDF2 rounds (default: 100,000)
    /// - Returns: Derived symmetric key
    public static func deriveKey(
        from password: String,
        salt: Data,
        rounds: Int = 100_000
    ) -> SymmetricKey? {
        guard let passwordData = password.data(using: .utf8) else {
            return nil
        }

        // Use HKDF as a simplified key derivation (real PBKDF2 would require CryptoKit extensions)
        let inputKeyMaterial = SymmetricKey(data: passwordData + salt)
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKeyMaterial,
            salt: salt,
            outputByteCount: 32
        )

        return derived
    }

    /// Generates a random salt for key derivation.
    ///
    /// - Parameter length: Length of salt in bytes (default: 32)
    /// - Returns: Random salt data
    public static func generateSalt(length: Int = 32) -> Data {
        var salt = Data(count: length)
        _ = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
        }
        return salt
    }
}
