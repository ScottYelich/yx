# YBS Step: RateLimiter.swift

**Step ID:** `ybs-step_sw3b0c1d2e3f`
**Language:** Swift
**Prerequisites:** Step sw3a complete (ReplayProtection.swift exists)

---

## ⚠️ CRITICAL DEFAULT VALUE

`maxRequests` MUST be **10,000** (not 100).  
See SDTS Issue #2 (Swift had 100, Python had 10,000 — broke high-frequency trading).  
Reference: `protocol/specs/technical/default-values.md` (max_requests = 10,000)

---

## What This Step Builds

Create `Sources/{{CONFIG:swift_module_name}}/Transport/RateLimiter.swift` — sliding window rate limiter.

---

## Implementation

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/RateLimiter.swift`

```swift
import Foundation

/// Per-peer rate limiter using sliding window.
///
/// CRITICAL: maxRequests = 10,000 (NOT 100!)
/// See SDTS Issue #2: wrong default caused HFT failures.
///
/// Traceability:
/// - protocol/specs/architecture/security-architecture.md (Rate Limiting)
/// - protocol/specs/technical/default-values.md (max_requests = 10,000)
actor RateLimiter {

    private let maxRequests: Int
    private let windowSeconds: TimeInterval
    private var trustedGUIDs: Set<String>
    private var history: [String: [Date]] = [:]

    /// - Parameters:
    ///   - maxRequests: Max requests per window (MUST be 10,000)
    ///   - windowSeconds: Sliding window duration (default: 60s)
    init(maxRequests: Int = 10000, windowSeconds: TimeInterval = 60.0, trustedGUIDs: Set<String> = []) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
        self.trustedGUIDs = trustedGUIDs
    }

    /// Check if peer is within rate limit.
    /// - Returns: true = allowed, false = blocked
    func checkRateLimit(peerID: String) -> Bool {
        if trustedGUIDs.contains(peerID.uppercased()) { return true }
        let now = Date()
        let cutoff = now.addingTimeInterval(-windowSeconds)
        var timestamps = history[peerID, default: []].filter { $0 > cutoff }
        if timestamps.count >= maxRequests { return false }
        timestamps.append(now)
        history[peerID] = timestamps
        return true
    }

    func addTrustedGUID(_ guid: String) { trustedGUIDs.insert(guid.uppercased()) }
    func removeTrustedGUID(_ guid: String) { trustedGUIDs.remove(guid.uppercased()) }
    func isTrusted(_ guid: String) -> Bool { trustedGUIDs.contains(guid.uppercased()) }
    func resetPeer(_ peerID: String) { history.removeValue(forKey: peerID) }
    var configuredMaxRequests: Int { maxRequests }
}
```

---

## Tests

**File:** `Tests/{{CONFIG:swift_module_name}}Tests/RateLimiterTests.swift`

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class RateLimiterTests: XCTestCase {

    func testDefaultIs10000() async {
        let rl = RateLimiter()
        let max = await rl.configuredMaxRequests
        XCTAssertEqual(max, 10000, "CRITICAL: default must be 10,000 not 100")
    }

    func testAllowsUnderLimit() async {
        let rl = RateLimiter(maxRequests: 10)
        for _ in 0..<10 {
            let ok = await rl.checkRateLimit(peerID: "peer1")
            XCTAssertTrue(ok)
        }
    }

    func testBlocksOverLimit() async {
        let rl = RateLimiter(maxRequests: 10)
        for _ in 0..<10 { _ = await rl.checkRateLimit(peerID: "peer1") }
        let blocked = await rl.checkRateLimit(peerID: "peer1")
        XCTAssertFalse(blocked)
    }

    func testPerPeerIsolation() async {
        let rl = RateLimiter(maxRequests: 5)
        for _ in 0..<5 { _ = await rl.checkRateLimit(peerID: "peer1") }
        let peer1Blocked = await rl.checkRateLimit(peerID: "peer1")
        let peer2Ok = await rl.checkRateLimit(peerID: "peer2")
        XCTAssertFalse(peer1Blocked)
        XCTAssertTrue(peer2Ok)
    }

    func testTrustedBypass() async {
        let rl = RateLimiter(maxRequests: 5)
        await rl.addTrustedGUID("E32E3CA702DE")
        for _ in 0..<100 {
            let ok = await rl.checkRateLimit(peerID: "E32E3CA702DE")
            XCTAssertTrue(ok)
        }
    }
}
```

---

## Verification

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter RateLimiter
```

All 5 tests must pass. `testDefaultIs10000` is mandatory.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_sw3b0c1d2e3f-DONE.txt`:

```
STEP: ybs-step_sw3b0c1d2e3f
COMPLETED: [ISO 8601 timestamp]
FILES: Sources/YXProtocol/Transport/RateLimiter.swift, Tests/RateLimiterTests.swift
VERIFICATION: PASSED
NEXT: ybs-step_sw3c0d1e2f3a
```

Update `BUILD_STATUS.md`: add `- [x] sw3b0c1d2e3f`.
