# YBS Step: AES-256-GCM (extend DataCrypto.swift)

**Step ID:** `ybs-step_sw2a0b1c2d3e`
**Language:** Swift
**Prerequisites:** Swift Step g1 complete (Protocol 0 working, Package.swift exists)

---

## What This Step Builds

**Extend** `Sources/{{CONFIG:swift_module_name}}/Primitives/DataCrypto.swift` — add AES-256-GCM encryption/decryption.

The file already exists with HMAC functions. **ADD** the new types and extensions.

---

## ⚠️ CRITICAL: Wire Format Must Match Python

Wire format MUST be: `[nonce(12 bytes)] + [ciphertext] + [tag(16 bytes)]`

This matches Python's `cryptography` library exactly for interoperability.

---

## Add to `Sources/{{CONFIG:swift_module_name}}/Primitives/DataCrypto.swift`

```swift
import CryptoKit
import Foundation

// MARK: - AES-256-GCM

/// AES-GCM encryption parameters
enum AESGCMParams {
    static let keySize = 32   // 256 bits
    static let nonceSize = 12 // 96 bits
    static let tagSize = 16   // 128 bits
}

enum CryptoError: Error, CustomStringConvertible {
    case invalidKeySize
    case invalidCiphertext
    case encryptionFailed
    case decryptionFailed

    var description: String {
        switch self {
        case .invalidKeySize: return "Key must be 32 bytes for AES-256"
        case .invalidCiphertext: return "Invalid ciphertext format"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed"
        }
    }
}

extension Data {

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
        let rest = suffix(from: AESGCMParams.nonceSize)
        let ciphertext = rest.prefix(rest.count - AESGCMParams.tagSize)
        let tag = rest.suffix(AESGCMParams.tagSize)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(box, using: key)
    }

    /// Create SymmetricKey from 32-byte Data.
    static func symmetricKey(from keyData: Data) throws -> SymmetricKey {
        guard keyData.count == AESGCMParams.keySize else { throw CryptoError.invalidKeySize }
        return SymmetricKey(data: keyData)
    }
}
```

---

## Tests

Add to `Tests/{{CONFIG:swift_module_name}}Tests/DataCryptoTests.swift`:

```swift
import XCTest
import CryptoKit
@testable import {{CONFIG:swift_module_name}}

extension DataCryptoTests {

    func testAESGCMRoundtrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Secret message".data(using: .utf8)!
        let ciphertext = try plaintext.aesGCMEncrypt(key: key)
        let decrypted = try ciphertext.aesGCMDecrypt(key: key)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testAESGCMWireFormat() throws {
        let key = SymmetricKey(size: .bits256)
        let plaintext = "Test".data(using: .utf8)!
        let ciphertext = try plaintext.aesGCMEncrypt(key: key)
        // Format: [nonce(12)] + [ciphertext(4)] + [tag(16)] = 32 bytes
        XCTAssertEqual(ciphertext.count, 12 + 4 + 16)
    }

    func testAESGCMInvalidKey() {
        let key = SymmetricKey(size: .bits128) // Wrong size
        let plaintext = "Test".data(using: .utf8)!
        XCTAssertThrowsError(try plaintext.aesGCMEncrypt(key: key))
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter DataCrypto
```

All AES-GCM tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw2a0b1c2d3e-DONE.txt`:

```
STEP: ybs-step_sw2a0b1c2d3e
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Primitives/DataCrypto.swift (extended)
VERIFICATION: PASSED
NEXT: ybs-step_sw2b0c1d2e3f
```

Update `BUILD_STATUS.md`: add `- [x] sw2a0b1c2d3e`.
