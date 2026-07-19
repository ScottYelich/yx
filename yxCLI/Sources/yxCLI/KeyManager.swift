// filename: KeyManager.swift

import Foundation
import Transport

enum KeyManager {
    static func load(using config: CommandLineConfig) async throws -> KeyStore {
        let keyStore = KeyStore()

        if let pubkeys = config.pubkeysPath {
            try await keyStore.loadTrustedPublicKeys(from: pubkeys)
        }

        if let identity = config.identityName,
           let privkeys = config.privkeysPath {
            try await keyStore.loadPrivateKey(named: identity, from: privkeys)
        }

        return keyStore
    }
}
