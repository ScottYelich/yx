import Foundation
import CryptoKit

public struct DataCrypto {
    public static func computeHMAC(data: Data, key: SymmetricKey, truncateTo: Int = 16) -> Data {
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac.prefix(truncateTo))
    }

    public static func validateHMAC(data: Data, key: SymmetricKey, expectedHMAC: Data, truncateTo: Int = 16) -> Bool {
        let computed = computeHMAC(data: data, key: key, truncateTo: truncateTo)
        return computed == expectedHMAC
    }

    public static func computePacketHMAC(guid: Data, payload: Data, key: SymmetricKey) -> Data {
        let combined = guid + payload
        return computeHMAC(data: combined, key: key, truncateTo: 16)
    }

    public static func validatePacketHMAC(guid: Data, payload: Data, key: SymmetricKey, expectedHMAC: Data) -> Bool {
        let computed = computePacketHMAC(guid: guid, payload: payload, key: key)
        return computed == expectedHMAC
    }
}

/// AES-256-GCM encryption parameters
struct AESGCMParams {
    static let keySize = 32  // 256 bits
    static let nonceSize = 12  // 96 bits
    static let tagSize = 16  // 128 bits
}

extension Data {

    /// Encrypt data using AES-256-GCM
    /// - Parameter key: 32-byte encryption key
    /// - Returns: [nonce(12)] + [ciphertext] + [tag(16)]
    /// - Throws: CryptoError if encryption fails
    public func aesGCMEncrypt(key: SymmetricKey) throws -> Data {
        guard key.bitCount == 256 else {
            throw CryptoError.invalidKeySize
        }

        let nonce = try AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(self, using: key, nonce: nonce)

        // CRITICAL: Wire format is [nonce(12)] + [ciphertext] + [tag(16)]
        // This matches Python implementation for interoperability.
        var result = Data(capacity: AESGCMParams.nonceSize + sealedBox.ciphertext.count + AESGCMParams.tagSize)
        result.append(contentsOf: nonce)
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)

        return result
    }

    /// Decrypt data using AES-256-GCM
    /// - Parameter key: 32-byte encryption key
    /// - Returns: Decrypted plaintext
    /// - Throws: CryptoError if decryption fails
    public func aesGCMDecrypt(key: SymmetricKey) throws -> Data {
        guard key.bitCount == 256 else {
            throw CryptoError.invalidKeySize
        }

        // CRITICAL: Wire format is [nonce(12)] + [ciphertext] + [tag(16)]
        let totalSize = self.count
        guard totalSize >= AESGCMParams.nonceSize + AESGCMParams.tagSize else {
            throw CryptoError.invalidCiphertext
        }

        let nonceData = self.prefix(AESGCMParams.nonceSize)
        let ciphertextAndTag = Data(self.suffix(from: self.startIndex + AESGCMParams.nonceSize))
        let ciphertext = ciphertextAndTag.prefix(ciphertextAndTag.count - AESGCMParams.tagSize)
        let tag = ciphertextAndTag.suffix(AESGCMParams.tagSize)

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let plaintext = try AES.GCM.open(sealedBox, using: key)

        return plaintext
    }

    /// Create SymmetricKey from raw bytes
    /// - Parameter keyData: 32-byte key data
    /// - Returns: SymmetricKey for AES-256
    public static func symmetricKey(from keyData: Data) throws -> SymmetricKey {
        guard keyData.count == AESGCMParams.keySize else {
            throw CryptoError.invalidKeySize
        }
        return SymmetricKey(data: keyData)
    }
}

enum CryptoError: Error, CustomStringConvertible {
    case invalidKeySize
    case invalidCiphertext
    case encryptionFailed
    case decryptionFailed

    var description: String {
        switch self {
        case .invalidKeySize:
            return "Invalid key size (must be 32 bytes for AES-256)"
        case .invalidCiphertext:
            return "Invalid ciphertext format"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}
