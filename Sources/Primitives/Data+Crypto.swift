import Foundation
// filename: Data+Crypto.swift

import CryptoKit

public extension Data {
    /// Encrypts the Data using AES-GCM with a fresh random nonce (12 bytes)
    func encryptedAES(using key: SymmetricKey) -> Data? {
        do {
            let nonce = AES.GCM.Nonce()
            let sealed = try AES.GCM.seal(self, using: key, nonce: nonce)
            return Data(nonce) + sealed.ciphertext + sealed.tag
        } catch {
            return nil
        }
    }

    enum DecryptionError: Error {
        case invalidLength
    }

    /// Decrypts AES-GCM-encrypted Data, assuming layout: [nonce (12)] + [ciphertext] + [tag (16)]
    func decryptedAES(using key: SymmetricKey) throws -> Data {
        guard self.count >= 12 + 16 else {
            throw DecryptionError.invalidLength
        }

        let nonceData = self.prefix(12)
        let tag = self.suffix(16)
        let ciphertext = self.dropFirst(12).dropLast(16)

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key)
    }

}
