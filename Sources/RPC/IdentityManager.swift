import Foundation
//
//  IdentityManager.swift
//  yx
//
//  Created by Scott Yelich on 5/12/25.
//


// filename: IdentityManager.swift

import Primitives
import CryptoKit

public final class IdentityManager {

    public let guid: String

    // ECDH for symmetric key derivation
    private let agreementKey: Curve25519.KeyAgreement.PrivateKey
    public let agreementPublicKeyBase64: String

    // P256 signing keypair
    private let signingKey: P256.Signing.PrivateKey
    public let signingPublicKeyBase64: String

    public init(guid: String) {
        self.guid = guid

        // In future: load from disk if needed
        self.agreementKey = Curve25519.KeyAgreement.PrivateKey()
        self.signingKey = P256.Signing.PrivateKey()

        self.agreementPublicKeyBase64 = agreementKey.publicKey.rawRepresentation.base64EncodedString()
        self.signingPublicKeyBase64 = signingKey.publicKey.rawRepresentation.base64EncodedString()
    }

    // MARK: - Export Hello Payload Fields

    public func exportHelloFields(timestamp: Int) -> [String: String] {
        let payload = "\(guid)|\(timestamp)|\(agreementPublicKeyBase64)"
        let signature = sign(message: payload)

        return [
            "guid": guid,
            "timestamp": String(timestamp),
            "publicKey": agreementPublicKeyBase64,
            "signingKey": signingPublicKeyBase64,
            "signature": signature.base64EncodedString()
        ]
    }

    // MARK: - Verify Incoming Hello

    public func verifyHelloSignature(
        guid: String,
        timestamp: Int,
        publicKeyBase64: String,
        signingKeyBase64: String,
        signatureBase64: String
    ) -> Bool {
        let payload = "\(guid)|\(timestamp)|\(publicKeyBase64)"
        guard
            let signingKeyData = Data(base64Encoded: signingKeyBase64),
            let signatureData = Data(base64Encoded: signatureBase64)
        else {
            return false
        }

        do {
            let publicKey = try P256.Signing.PublicKey(rawRepresentation: signingKeyData)
            return publicKey.isValidSignature(try P256.Signing.ECDSASignature(derRepresentation: signatureData), for: Data(payload.utf8))
        } catch {
            log("❌ [PKI] Signature verification failed: \(error)", level: .error)
            return false
        }
    }

    // MARK: - Key Derivation

    public func deriveSymmetricKey(with peerPublicKeyBase64: String) -> SymmetricKey? {
        guard let peerData = Data(base64Encoded: peerPublicKeyBase64) else { return nil }

        do {
            let peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerData)
            let sharedSecret = try agreementKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
            let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data(),
                sharedInfo: Data(guid.utf8),
                outputByteCount: 32
            )
            return symmetricKey
        } catch {
            log("🔐 [PKI] Failed to derive symmetric key: \(error)", level: .error)
            return nil
        }
    }

    // MARK: - Internal Signing

    private func sign(message: String) -> Data {
        let data = Data(message.utf8)
        do {
            let signature = try signingKey.signature(for: data)
            return signature.derRepresentation
        } catch {
            fatalError("💥 Failed to sign message: \(error)")
        }
    }
}
