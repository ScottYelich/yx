import Foundation
// filename: KeyStore.swift

import Primitives
import CryptoKit

public struct IdentityKeyPair: Sendable {
    public let name: String
    public let signingPrivateKey: Curve25519.Signing.PrivateKey
    public var signingPublicKey: Curve25519.Signing.PublicKey {
        signingPrivateKey.publicKey
    }
}

public actor KeyStore {
    private var trustedPublicKeys: [String: Curve25519.Signing.PublicKey] = [:]
    private var identityKeyPair: IdentityKeyPair?

    public init() {}

    public func loadTrustedPublicKeys(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let raw = try JSONDecoder().decode([String: String].self, from: data)
        var parsed: [String: Curve25519.Signing.PublicKey] = [:]
        for (name, base64) in raw {
            guard let keyData = Data(base64Encoded: base64) else { continue }
            parsed[name] = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        }
        trustedPublicKeys = parsed
    }

    public func loadPrivateKey(named name: String, from url: URL) throws {
        let data = try Data(contentsOf: url)
        let raw = try JSONDecoder().decode([String: String].self, from: data)
        guard let base64 = raw[name],
              let keyData = Data(base64Encoded: base64) else {
            throw NSError(domain: "KeyStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Private key for '\(name)' not found"])
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        identityKeyPair = IdentityKeyPair(name: name, signingPrivateKey: privateKey)
    }

    public func getTrustedPublicKey(for name: String) -> Curve25519.Signing.PublicKey? {
        return trustedPublicKeys[name]
    }

    public func getIdentity() -> IdentityKeyPair? {
        return identityKeyPair
    }

    public func getTrustedNames() -> [String] {
        return Array(trustedPublicKeys.keys)
    }
}
