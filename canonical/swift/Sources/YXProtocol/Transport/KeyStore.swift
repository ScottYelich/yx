import Foundation
import CryptoKit

/// Per-peer key management
///
/// Stores HMAC keys and optional encryption keys per peer.
actor KeyStore {

    struct KeyEntry {
        let hmacKey: Data
        let encryptionKey: Data?
        let timestamp: Date
    }

    private var keys: [String: KeyEntry] = [:]

    /// Add or update peer keys.
    func setKeys(peerID: String, hmacKey: Data, encryptionKey: Data? = nil) {
        let entry = KeyEntry(hmacKey: hmacKey, encryptionKey: encryptionKey, timestamp: Date())
        keys[peerID] = entry
    }

    func getHMACKey(peerID: String) -> Data? {
        return keys[peerID]?.hmacKey
    }

    func getEncryptionKey(peerID: String) -> Data? {
        return keys[peerID]?.encryptionKey
    }

    func getKeys(peerID: String) -> (hmacKey: Data, encryptionKey: Data?)? {
        guard let entry = keys[peerID] else {
            return nil
        }
        return (entry.hmacKey, entry.encryptionKey)
    }

    func removeKeys(peerID: String) {
        keys.removeValue(forKey: peerID)
    }

    func hasKeys(peerID: String) -> Bool {
        return keys[peerID] != nil
    }

    func getAllPeerIDs() -> [String] {
        return Array(keys.keys)
    }

    func clear() {
        keys.removeAll()
    }

    func count() -> Int {
        return keys.count
    }
}
