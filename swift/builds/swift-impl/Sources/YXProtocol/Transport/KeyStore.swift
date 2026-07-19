import Foundation
import CryptoKit

/// Per-peer symmetric key manager.
///
/// Falls back to defaultKey when no peer-specific key is set.
///
/// Traceability:
/// - protocol/specs/architecture/security-architecture.md (Per-Peer Keys)
actor KeyStore {

    private let defaultKey: Data
    private var peerKeys: [String: Data] = [:]

    /// - Parameter defaultKey: 32-byte fallback key
    init(defaultKey: Data) throws {
        guard defaultKey.count == 32 else {
            throw KeyStoreError.invalidKeySize
        }
        self.defaultKey = defaultKey
    }

    /// Get key for peer (or default).
    func getKey(peerID: String) -> Data {
        return peerKeys[peerID] ?? defaultKey
    }

    /// Set peer-specific key.
    func setKey(_ key: Data, for peerID: String) throws {
        guard key.count == 32 else { throw KeyStoreError.invalidKeySize }
        peerKeys[peerID] = key
    }

    func removeKey(for peerID: String) { peerKeys.removeValue(forKey: peerID) }
    func hasPeerKey(_ peerID: String) -> Bool { peerKeys[peerID] != nil }
    var peerCount: Int { peerKeys.count }
}

enum KeyStoreError: Error, CustomStringConvertible {
    case invalidKeySize
    var description: String { "Key must be 32 bytes for AES-256" }
}
