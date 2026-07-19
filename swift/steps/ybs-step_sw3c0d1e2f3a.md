# YBS Step: KeyStore.swift

**Step ID:** `ybs-step_sw3c0d1e2f3a`
**Language:** Swift
**Prerequisites:** Step sw3b complete (RateLimiter.swift exists)

---

## What This Step Builds

Create `Sources/{{CONFIG:swift_module_name}}/Transport/KeyStore.swift` — per-peer key management.

---

## Implementation

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/KeyStore.swift`

```swift
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
```

---

## Tests

**File:** `Tests/{{CONFIG:swift_module_name}}Tests/KeyStoreTests.swift`

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class KeyStoreTests: XCTestCase {

    func testDefaultKey() async throws {
        let defaultKey = Data(repeating: 0x00, count: 32)
        let ks = try KeyStore(defaultKey: defaultKey)
        let key = await ks.getKey(peerID: "unknown")
        XCTAssertEqual(key, defaultKey)
    }

    func testPeerSpecific() async throws {
        let defaultKey = Data(repeating: 0x00, count: 32)
        let peerKey = Data(repeating: 0xFF, count: 32)
        let ks = try KeyStore(defaultKey: defaultKey)
        try await ks.setKey(peerKey, for: "peer1")
        let key = await ks.getKey(peerID: "peer1")
        XCTAssertEqual(key, peerKey)
    }

    func testInvalidSize() async throws {
        let ks = try KeyStore(defaultKey: Data(repeating: 0, count: 32))
        await XCTAssertThrowsError(try await ks.setKey(Data([1,2,3]), for: "peer1"))
    }

    func testRemoveKey() async throws {
        let defaultKey = Data(repeating: 0x00, count: 32)
        let ks = try KeyStore(defaultKey: defaultKey)
        try await ks.setKey(Data(repeating: 0xFF, count: 32), for: "peer1")
        XCTAssertTrue(await ks.hasPeerKey("peer1"))
        await ks.removeKey(for: "peer1")
        XCTAssertFalse(await ks.hasPeerKey("peer1"))
        let key = await ks.getKey(peerID: "peer1")
        XCTAssertEqual(key, defaultKey)
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter KeyStore
```

All 4 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw3c0d1e2f3a-DONE.txt`:

```
STEP: ybs-step_sw3c0d1e2f3a
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Transport/KeyStore.swift, Tests/KeyStoreTests.swift
VERIFICATION: PASSED
NEXT: ybs-step_sw3d0e1f2a3b
```

Update `BUILD_STATUS.md`: add `- [x] sw3c0d1e2f3a`.
