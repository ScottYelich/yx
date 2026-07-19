import Foundation
import CryptoKit

// Implements: protocol/specs/technical/yx-protocol-spec.md § HMAC-SHA256 and AES-256-GCM

// MARK: - HMAC

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

// MARK: - AES-256-GCM

enum AESGCMParams {
    static let keySize = 32   // 256 bits
    static let nonceSize = 12 // 96 bits
    static let tagSize = 16   // 128 bits
}

public enum CryptoError: Error, CustomStringConvertible {
    case invalidKeySize
    case invalidCiphertext
    case encryptionFailed
    case decryptionFailed

    public var description: String {
        switch self {
        case .invalidKeySize: return "Key must be 32 bytes for AES-256"
        case .invalidCiphertext: return "Invalid ciphertext format"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed"
        }
    }
}

public extension Data {
    /// Encrypt using AES-256-GCM.
    /// Wire format: [nonce(12)] + [ciphertext] + [tag(16)]
    /// MUST match Python cryptography library format.
    func aesGCMEncrypt(key: SymmetricKey) throws -> Data {
        guard key.bitCount == 256 else { throw CryptoError.invalidKeySize }
        let nonce = try AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(self, using: key, nonce: nonce)
        var result = Data()
        result.append(contentsOf: nonce)
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)
        return result
    }

    /// Decrypt AES-256-GCM data.
    /// Expects wire format: [nonce(12)] + [ciphertext] + [tag(16)]
    func aesGCMDecrypt(key: SymmetricKey) throws -> Data {
        guard key.bitCount == 256 else { throw CryptoError.invalidKeySize }
        guard count >= AESGCMParams.nonceSize + AESGCMParams.tagSize else {
            throw CryptoError.invalidCiphertext
        }
        let nonceData = prefix(AESGCMParams.nonceSize)
        let tagOffset = count - AESGCMParams.tagSize
        let ciphertext = self[AESGCMParams.nonceSize..<tagOffset]
        let tag = suffix(AESGCMParams.tagSize)

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tag
        )
        return try AES.GCM.open(sealedBox, using: key)
    }
}

// MARK: - ZLIB Compression

public enum CompressionError: Error, CustomStringConvertible {
    case compressionFailed
    case decompressionFailed

    public var description: String {
        switch self {
        case .compressionFailed: return "Compression failed"
        case .decompressionFailed: return "Decompression failed"
        }
    }
}

public extension Data {
    /// Compress using ZLIB (RFC 1950 - compatible with Python's zlib.compress()).
    func zlibCompress() throws -> Data {
        guard !isEmpty else { return Data() }
        do {
            return try (self as NSData).compressed(using: .zlib) as Data
        } catch {
            throw CompressionError.compressionFailed
        }
    }

    /// Decompress ZLIB (RFC 1950 - compatible with Python's zlib.decompress()).
    func zlibDecompress() throws -> Data {
        guard !isEmpty else { return Data() }
        do {
            return try (self as NSData).decompressed(using: .zlib) as Data
        } catch {
            throw CompressionError.decompressionFailed
        }
    }
}
