# YBS Step: ReplayProtection.swift

**Step ID:** `ybs-step_sw3a0b1c2d3e`
**Language:** Swift
**Prerequisites:** Step sw2d complete (BinaryProtocol.swift exists)

---

## What This Step Builds

Create `Sources/{{CONFIG:swift_module_name}}/Transport/ReplayProtection.swift` — nonce cache that prevents replay attacks.

---

## Implementation

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/ReplayProtection.swift`

```swift
import Foundation

/// Replay attack protection using nonce cache.
///
/// Traceability:
/// - protocol/specs/architecture/security-architecture.md (Replay Protection)
/// - protocol/specs/technical/default-values.md (replay_expiry = 300.0)
actor ReplayProtection {

    private let maxAge: TimeInterval
    private var seen: [Data: Date] = [:]
    private var checkCount = 0
    private let cleanupInterval: Int

    /// - Parameters:
    ///   - maxAge: Nonce expiry (default: 300s)
    ///   - cleanupInterval: Cleanup every N checks (default: 100)
    init(maxAge: TimeInterval = 300.0, cleanupInterval: Int = 100) {
        self.maxAge = maxAge
        self.cleanupInterval = cleanupInterval
    }

    /// Check nonce and record if new.
    /// - Returns: true = allowed (first time), false = replay detected
    func checkAndRecord(nonce: Data) -> Bool {
        if seen[nonce] != nil { return false }
        seen[nonce] = Date()
        checkCount += 1
        if checkCount >= cleanupInterval {
            cleanup()
            checkCount = 0
        }
        return true
    }

    var count: Int { seen.count }

    func clear() { seen.removeAll() }

    private func cleanup() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        seen = seen.filter { $0.value > cutoff }
    }
}
```

---

## Tests

**File:** `Tests/{{CONFIG:swift_module_name}}Tests/ReplayProtectionTests.swift`

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class ReplayProtectionTests: XCTestCase {

    func testAllowsNew() async {
        let rp = ReplayProtection()
        let result = await rp.checkAndRecord(nonce: Data([1,2,3,4,5,6]))
        XCTAssertTrue(result)
    }

    func testBlocksDuplicate() async {
        let rp = ReplayProtection()
        let nonce = Data([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])
        _ = await rp.checkAndRecord(nonce: nonce)
        let result = await rp.checkAndRecord(nonce: nonce)
        XCTAssertFalse(result)
    }

    func testCount() async {
        let rp = ReplayProtection()
        let c0 = await rp.count
        XCTAssertEqual(c0, 0)
        _ = await rp.checkAndRecord(nonce: Data([1]))
        _ = await rp.checkAndRecord(nonce: Data([2]))
        let c2 = await rp.count
        XCTAssertEqual(c2, 2)
    }

    func testClear() async {
        let rp = ReplayProtection()
        _ = await rp.checkAndRecord(nonce: Data([1]))
        await rp.clear()
        let c = await rp.count
        XCTAssertEqual(c, 0)
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter ReplayProtection
```

All 4 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw3a0b1c2d3e-DONE.txt`:

```
STEP: ybs-step_sw3a0b1c2d3e
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Transport/ReplayProtection.swift, Tests/ReplayProtectionTests.swift
VERIFICATION: PASSED
NEXT: ybs-step_sw3b0c1d2e3f
```

Update `BUILD_STATUS.md`: add `- [x] sw3a0b1c2d3e`.
