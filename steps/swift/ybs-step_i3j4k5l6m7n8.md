# YBS Step 13 (Swift): Security (Replay Protection + Rate Limiting)

**Step ID:** `ybs-step_i3j4k5l6m7n8`
**Language:** Swift
**System:** YX Protocol
**Focus:** Replay Protection and Rate Limiting security features

## Prerequisites

- ✅ Step 12 completed (Protocol 1 - Binary/Chunked)
- ✅ Python Step 13 completed (reference implementation)
- ✅ Specifications: `specs/architecture/security-architecture.md`
- ✅ Specifications: `specs/technical/default-values.md`

## Overview

Implement **critical security features** to protect against attacks:

1. **Replay Protection:** Prevent replay attacks using nonce cache with expiry
2. **Rate Limiting:** Prevent DoS attacks using per-peer rate limits
3. **Key Store:** Manage per-peer encryption keys

**Security Layers:**
```
Application Layer
        ↓
  Rate Limiter (10,000 req/60s per peer)
        ↓
Replay Protection (nonce cache, 300s expiry)
        ↓
   HMAC Verification
        ↓
    UDP Socket
```

## Traceability

**Specifications:**
- `specs/architecture/security-architecture.md` § Replay Protection
- `specs/architecture/security-architecture.md` § Rate Limiting
- `specs/architecture/security-architecture.md` § Per-Peer Keys
- `specs/technical/default-values.md` § Security Defaults

**Gaps Addressed:**
- Gap 2.1: Replay protection implementation
- Gap 2.2: Rate limiting implementation
- Gap 8.7: Default values (max_requests = 10,000)
- Gap 3.4: Per-peer key management

**SDTS Lessons:**
- **SDTS Issue #2 (CRITICAL):** Rate limiter default MUST be 10,000 (not 100)
  - Swift v1.0.2 had 100, Python had 10,000
  - Caused high-frequency trading blocking
  - Extensive testing required to validate default
- **SDTS Issue #3:** Missing replay protection in Python (security vulnerability)

## Build Instructions

### 1. Create Replay Protection

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/ReplayProtection.swift`

```swift
import Foundation

/// Replay attack protection using nonce cache
///
/// Tracks seen nonces and rejects duplicates within max_age window.
/// Implements automatic cleanup to prevent memory exhaustion.
actor ReplayProtection {

    /// Maximum age for nonces (seconds)
    private let maxAge: TimeInterval

    /// Cleanup interval (perform cleanup every N checks)
    private let cleanupInterval: Int

    /// Seen nonces with timestamps
    private var seenNonces: [Data: Date] = [:]

    /// Check counter for periodic cleanup
    private var checkCounter: Int = 0

    /// Initialize replay protection
    /// - Parameters:
    ///   - maxAge: Maximum age for nonces in seconds (default 300.0)
    ///   - cleanupInterval: Cleanup every N checks (default 100)
    init(maxAge: TimeInterval = 300.0, cleanupInterval: Int = 100) {
        self.maxAge = maxAge
        self.cleanupInterval = cleanupInterval
    }

    /// Check if nonce is valid and record it
    /// - Parameter nonce: Nonce to check (typically GUID from packet)
    /// - Returns: true if allowed (first time), false if replay detected
    func checkAndRecord(nonce: Data) -> Bool {
        let now = Date()

        // Check if already seen
        if seenNonces[nonce] != nil {
            // REPLAY DETECTED
            return false
        }

        // Record nonce
        seenNonces[nonce] = now

        // Periodic cleanup
        checkCounter += 1
        if checkCounter >= cleanupInterval {
            cleanup()
            checkCounter = 0
        }

        return true
    }

    /// Check if nonce has been seen (without recording)
    /// - Parameter nonce: Nonce to check
    /// - Returns: true if seen before, false otherwise
    func hasSeen(nonce: Data) -> Bool {
        return seenNonces[nonce] != nil
    }

    /// Remove expired nonces
    private func cleanup() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        seenNonces = seenNonces.filter { _, timestamp in
            timestamp > cutoff
        }
    }

    /// Get count of tracked nonces
    func count() -> Int {
        return seenNonces.count
    }

    /// Clear all tracked nonces (for testing)
    func clear() {
        seenNonces.removeAll()
        checkCounter = 0
    }
}
```

**Key Design:**
- Actor for thread-safe nonce tracking
- Dictionary-based lookup (O(1) performance)
- Automatic cleanup every N checks
- Configurable expiry window (default 300s)

**Security Note:**
- Nonce = GUID from packet (6 bytes)
- Must be unique per message
- Protects against replay attacks within expiry window

### 2. Create Rate Limiter

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/RateLimiter.swift`

```swift
import Foundation

/// Rate limiting using sliding window per peer
///
/// ⚠️ CRITICAL DEFAULT: max_requests = 10,000 (SDTS Issue #2)
///
/// SDTS Issue #2 History:
/// - Swift v1.0.2 used 100 req/60s (too restrictive)
/// - Python used 10,000 req/60s (correct for HFT)
/// - Mismatch caused HFT systems to be blocked by Swift
/// - Default MUST be 10,000 for high-frequency trading compatibility
actor RateLimiter {

    /// Maximum requests per window per peer
    ///
    /// ⚠️ CRITICAL: Default is 10,000 (NOT 100)
    /// See SDTS Issue #2 in specs/technical/default-values.md
    private let maxRequests: Int

    /// Time window in seconds
    private let windowSeconds: TimeInterval

    /// Request timestamps per peer
    private var peerRequests: [String: [Date]] = [:]

    /// Initialize rate limiter
    /// - Parameters:
    ///   - maxRequests: Maximum requests per window (default 10,000) ⚠️ CRITICAL
    ///   - windowSeconds: Time window in seconds (default 60.0)
    init(maxRequests: Int = 10_000, windowSeconds: TimeInterval = 60.0) {
        // CRITICAL VALIDATION: Ensure default is 10,000
        // This protects against SDTS Issue #2 regression
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds

        // Log warning if default is overridden to low value
        if maxRequests < 10_000 {
            print("⚠️  WARNING: RateLimiter maxRequests (\(maxRequests)) is below recommended 10,000")
            print("   This may block high-frequency trading systems (see SDTS Issue #2)")
        }
    }

    /// Check if request is allowed for peer
    /// - Parameters:
    ///   - peerID: Peer identifier (e.g., GUID hex)
    ///   - sourceAddr: Source address (host:port) as fallback identifier
    /// - Returns: true if allowed, false if rate limit exceeded
    func checkRateLimit(peerID: String, sourceAddr: String) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-windowSeconds)

        // Use peerID as primary key
        let key = peerID.isEmpty ? sourceAddr : peerID

        // Get existing requests for this peer
        var requests = peerRequests[key, default: []]

        // Remove expired requests (sliding window)
        requests = requests.filter { $0 > cutoff }

        // Check if limit exceeded
        if requests.count >= maxRequests {
            // RATE LIMIT EXCEEDED
            peerRequests[key] = requests
            return false
        }

        // Record this request
        requests.append(now)
        peerRequests[key] = requests

        return true
    }

    /// Get current request count for peer
    /// - Parameter peerID: Peer identifier
    /// - Returns: Number of requests in current window
    func getCurrentCount(peerID: String) -> Int {
        let now = Date()
        let cutoff = now.addingTimeInterval(-windowSeconds)

        guard let requests = peerRequests[peerID] else {
            return 0
        }

        return requests.filter { $0 > cutoff }.count
    }

    /// Clear all rate limit data (for testing)
    func clear() {
        peerRequests.removeAll()
    }

    /// Get rate limiter configuration
    func getConfig() -> (maxRequests: Int, windowSeconds: TimeInterval) {
        return (maxRequests, windowSeconds)
    }
}
```

**CRITICAL - SDTS Issue #2:**

The default value of `maxRequests` MUST be **10,000** (not 100).

**History:**
- Swift v1.0.2: Used 100 req/60s
- Python: Used 10,000 req/60s
- **Impact:** High-frequency trading systems were blocked by Swift implementation
- **Root cause:** Different defaults between implementations
- **Fix:** Standardize on 10,000 across all implementations

**Validation:**
- Unit tests MUST verify default is 10,000
- Warning logged if overridden to value < 10,000

### 3. Create Key Store

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/KeyStore.swift`

```swift
import Foundation
import CryptoKit

/// Per-peer key management
///
/// Stores HMAC keys and optional encryption keys per peer.
actor KeyStore {

    /// Key entry for a peer
    struct KeyEntry {
        /// HMAC key (required)
        let hmacKey: Data

        /// Encryption key (optional, 32 bytes for AES-256)
        let encryptionKey: Data?

        /// Timestamp when key was added
        let timestamp: Date
    }

    /// Stored keys per peer ID
    private var keys: [String: KeyEntry] = [:]

    /// Add or update peer keys
    /// - Parameters:
    ///   - peerID: Peer identifier (e.g., GUID hex)
    ///   - hmacKey: HMAC key
    ///   - encryptionKey: Optional encryption key (32 bytes for AES-256)
    func setKeys(peerID: String, hmacKey: Data, encryptionKey: Data? = nil) {
        let entry = KeyEntry(
            hmacKey: hmacKey,
            encryptionKey: encryptionKey,
            timestamp: Date()
        )
        keys[peerID] = entry
    }

    /// Get HMAC key for peer
    /// - Parameter peerID: Peer identifier
    /// - Returns: HMAC key or nil if not found
    func getHMACKey(peerID: String) -> Data? {
        return keys[peerID]?.hmacKey
    }

    /// Get encryption key for peer
    /// - Parameter peerID: Peer identifier
    /// - Returns: Encryption key or nil if not found
    func getEncryptionKey(peerID: String) -> Data? {
        return keys[peerID]?.encryptionKey
    }

    /// Get both keys for peer
    /// - Parameter peerID: Peer identifier
    /// - Returns: Tuple of (hmacKey, encryptionKey) or nil if not found
    func getKeys(peerID: String) -> (hmacKey: Data, encryptionKey: Data?)? {
        guard let entry = keys[peerID] else {
            return nil
        }
        return (entry.hmacKey, entry.encryptionKey)
    }

    /// Remove peer keys
    /// - Parameter peerID: Peer identifier
    func removeKeys(peerID: String) {
        keys.removeValue(forKey: peerID)
    }

    /// Check if peer has keys
    /// - Parameter peerID: Peer identifier
    /// - Returns: true if keys exist for peer
    func hasKeys(peerID: String) -> Bool {
        return keys[peerID] != nil
    }

    /// Get all peer IDs
    func getAllPeerIDs() -> [String] {
        return Array(keys.keys)
    }

    /// Clear all keys (for testing)
    func clear() {
        keys.removeAll()
    }

    /// Get key count
    func count() -> Int {
        return keys.count
    }
}
```

**Key Design:**
- Actor for thread-safe key management
- Supports per-peer HMAC and encryption keys
- Optional encryption key (for Protocol 1 encrypted mode)
- Timestamp tracking for key rotation

## Verification

### Unit Tests

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Transport/ReplayProtectionTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class ReplayProtectionTests: XCTestCase {

    func testFirstRequestAllowed() async {
        let rp = ReplayProtection()
        let nonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])

        let allowed = await rp.checkAndRecord(nonce: nonce)
        XCTAssertTrue(allowed)
    }

    func testDuplicateRequestBlocked() async {
        let rp = ReplayProtection()
        let nonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])

        // First request - allowed
        _ = await rp.checkAndRecord(nonce: nonce)

        // Second request - blocked
        let allowed = await rp.checkAndRecord(nonce: nonce)
        XCTAssertFalse(allowed)
    }

    func testDifferentNoncesAllowed() async {
        let rp = ReplayProtection()
        let nonce1 = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        let nonce2 = Data([0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C])

        let allowed1 = await rp.checkAndRecord(nonce: nonce1)
        let allowed2 = await rp.checkAndRecord(nonce: nonce2)

        XCTAssertTrue(allowed1)
        XCTAssertTrue(allowed2)
    }

    func testHasSeen() async {
        let rp = ReplayProtection()
        let nonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])

        // Not seen yet
        XCTAssertFalse(await rp.hasSeen(nonce: nonce))

        // Record it
        _ = await rp.checkAndRecord(nonce: nonce)

        // Now seen
        XCTAssertTrue(await rp.hasSeen(nonce: nonce))
    }

    func testCleanup() async {
        let rp = ReplayProtection(maxAge: 1.0, cleanupInterval: 5)

        // Add 10 nonces
        for i in 0..<10 {
            let nonce = Data([UInt8(i)])
            _ = await rp.checkAndRecord(nonce: nonce)
        }

        XCTAssertEqual(await rp.count(), 10)

        // Wait for expiry
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Trigger cleanup by adding new nonce
        for i in 10..<15 {
            let nonce = Data([UInt8(i)])
            _ = await rp.checkAndRecord(nonce: nonce)
        }

        // Old nonces should be cleaned up
        let count = await rp.count()
        XCTAssertLessThan(count, 15)
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Transport/RateLimiterTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class RateLimiterTests: XCTestCase {

    /// ⚠️ CRITICAL TEST: Verify default is 10,000 (SDTS Issue #2)
    func testDefaultIs10000() async {
        let rl = RateLimiter()
        let config = await rl.getConfig()

        // CRITICAL: Default MUST be 10,000 (not 100)
        XCTAssertEqual(config.maxRequests, 10_000,
                      "CRITICAL: Default maxRequests must be 10,000 (SDTS Issue #2)")
        XCTAssertEqual(config.windowSeconds, 60.0)
    }

    func testRequestsAllowedUnderLimit() async {
        let rl = RateLimiter(maxRequests: 5, windowSeconds: 60.0)

        for i in 0..<5 {
            let allowed = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
            XCTAssertTrue(allowed, "Request \(i) should be allowed")
        }
    }

    func testRequestBlockedOverLimit() async {
        let rl = RateLimiter(maxRequests: 5, windowSeconds: 60.0)

        // Send 5 requests (all allowed)
        for _ in 0..<5 {
            _ = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        }

        // 6th request should be blocked
        let allowed = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        XCTAssertFalse(allowed, "6th request should be blocked")
    }

    func testSlidingWindow() async {
        let rl = RateLimiter(maxRequests: 3, windowSeconds: 1.0)

        // Send 3 requests
        for _ in 0..<3 {
            _ = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        }

        // 4th request blocked
        XCTAssertFalse(await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000"))

        // Wait for window to expire
        try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds

        // New request should be allowed (old requests expired)
        XCTAssertTrue(await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000"))
    }

    func testPerPeerLimits() async {
        let rl = RateLimiter(maxRequests: 2, windowSeconds: 60.0)

        // Peer 1: 2 requests (all allowed)
        XCTAssertTrue(await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000"))
        XCTAssertTrue(await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000"))

        // Peer 2: 2 requests (all allowed - separate limit)
        XCTAssertTrue(await rl.checkRateLimit(peerID: "peer2", sourceAddr: "127.0.0.1:5001"))
        XCTAssertTrue(await rl.checkRateLimit(peerID: "peer2", sourceAddr: "127.0.0.1:5001"))

        // Peer 1: 3rd request (blocked)
        XCTAssertFalse(await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000"))

        // Peer 2: 3rd request (blocked)
        XCTAssertFalse(await rl.checkRateLimit(peerID: "peer2", sourceAddr: "127.0.0.1:5001"))
    }

    func testGetCurrentCount() async {
        let rl = RateLimiter(maxRequests: 10, windowSeconds: 60.0)

        XCTAssertEqual(await rl.getCurrentCount(peerID: "peer1"), 0)

        // Send 3 requests
        for _ in 0..<3 {
            _ = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        }

        XCTAssertEqual(await rl.getCurrentCount(peerID: "peer1"), 3)
    }

    /// Test high-frequency scenario (10,000 requests in 60s)
    func testHighFrequencyTrading() async {
        let rl = RateLimiter(maxRequests: 10_000, windowSeconds: 60.0)

        // Simulate HFT: 10,000 requests should all be allowed
        var blockedCount = 0
        for _ in 0..<10_000 {
            let allowed = await rl.checkRateLimit(peerID: "hft-peer", sourceAddr: "127.0.0.1:6000")
            if !allowed {
                blockedCount += 1
            }
        }

        XCTAssertEqual(blockedCount, 0, "No requests should be blocked with 10,000 limit")

        // 10,001st request should be blocked
        let allowed = await rl.checkRateLimit(peerID: "hft-peer", sourceAddr: "127.0.0.1:6000")
        XCTAssertFalse(allowed, "10,001st request should be blocked")
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Transport/KeyStoreTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class KeyStoreTests: XCTestCase {

    func testSetAndGetHMACKey() async {
        let ks = KeyStore()
        let hmacKey = Data(repeating: 0x42, count: 32)

        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey)

        let retrieved = await ks.getHMACKey(peerID: "peer1")
        XCTAssertEqual(retrieved, hmacKey)
    }

    func testSetAndGetEncryptionKey() async {
        let ks = KeyStore()
        let hmacKey = Data(repeating: 0x42, count: 32)
        let encKey = Data(repeating: 0x99, count: 32)

        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey, encryptionKey: encKey)

        let retrieved = await ks.getEncryptionKey(peerID: "peer1")
        XCTAssertEqual(retrieved, encKey)
    }

    func testGetBothKeys() async {
        let ks = KeyStore()
        let hmacKey = Data(repeating: 0x42, count: 32)
        let encKey = Data(repeating: 0x99, count: 32)

        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey, encryptionKey: encKey)

        let keys = await ks.getKeys(peerID: "peer1")
        XCTAssertNotNil(keys)
        XCTAssertEqual(keys?.hmacKey, hmacKey)
        XCTAssertEqual(keys?.encryptionKey, encKey)
    }

    func testMissingKeys() async {
        let ks = KeyStore()

        XCTAssertNil(await ks.getHMACKey(peerID: "unknown"))
        XCTAssertNil(await ks.getEncryptionKey(peerID: "unknown"))
        XCTAssertNil(await ks.getKeys(peerID: "unknown"))
    }

    func testRemoveKeys() async {
        let ks = KeyStore()
        let hmacKey = Data(repeating: 0x42, count: 32)

        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey)
        XCTAssertTrue(await ks.hasKeys(peerID: "peer1"))

        await ks.removeKeys(peerID: "peer1")
        XCTAssertFalse(await ks.hasKeys(peerID: "peer1"))
    }

    func testGetAllPeerIDs() async {
        let ks = KeyStore()
        let hmacKey = Data(repeating: 0x42, count: 32)

        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey)
        await ks.setKeys(peerID: "peer2", hmacKey: hmacKey)
        await ks.setKeys(peerID: "peer3", hmacKey: hmacKey)

        let peerIDs = await ks.getAllPeerIDs()
        XCTAssertEqual(peerIDs.count, 3)
        XCTAssertTrue(peerIDs.contains("peer1"))
        XCTAssertTrue(peerIDs.contains("peer2"))
        XCTAssertTrue(peerIDs.contains("peer3"))
    }
}
```

### Integration Test

Create `Tests/{{CONFIG:swift_module_name}}Tests/Integration/SecurityIntegrationTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class SecurityIntegrationTests: XCTestCase {

    /// Test complete security stack: Rate Limiter → Replay Protection → HMAC
    func testSecurityStack() async throws {
        let rl = RateLimiter(maxRequests: 3, windowSeconds: 60.0)
        let rp = ReplayProtection()
        let ks = KeyStore()

        let hmacKey = Data(repeating: 0x42, count: 32)
        await ks.setKeys(peerID: "peer1", hmacKey: hmacKey)

        // Simulate 3 valid requests
        for i in 0..<3 {
            let nonce = Data([UInt8(i)])

            // Check rate limit
            let rateLimitOK = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
            XCTAssertTrue(rateLimitOK, "Request \(i) should pass rate limit")

            // Check replay
            let replayOK = await rp.checkAndRecord(nonce: nonce)
            XCTAssertTrue(replayOK, "Request \(i) should pass replay check")
        }

        // 4th request - rate limited
        let nonce4 = Data([0x04])
        let rateLimitOK = await rl.checkRateLimit(peerID: "peer1", sourceAddr: "127.0.0.1:5000")
        XCTAssertFalse(rateLimitOK, "4th request should be rate limited")

        // Replay attack - blocked
        let nonce0 = Data([0x00])
        let replayOK = await rp.checkAndRecord(nonce: nonce0)
        XCTAssertFalse(replayOK, "Replay should be blocked")
    }
}
```

### Success Criteria

- [ ] All 15+ tests pass
- [ ] **CRITICAL:** Default maxRequests is 10,000 (testDefaultIs10000 passes)
- [ ] Replay protection blocks duplicate nonces
- [ ] Rate limiter enforces per-peer limits
- [ ] Sliding window works correctly
- [ ] KeyStore manages per-peer keys
- [ ] High-frequency trading test (10,000 req) passes
- [ ] Integration test demonstrates full security stack
- [ ] Code coverage ≥ 80%

### Run Tests

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter ReplayProtection
swift test --filter RateLimiter
swift test --filter KeyStore
swift test --filter SecurityIntegration
```

## Implementation Notes

### SDTS Issue #2: Rate Limiter Default (CRITICAL)

**Problem:** Swift v1.0.2 used 100 req/60s, Python used 10,000 req/60s

**Impact:** High-frequency trading systems were blocked by Swift

**Solution:**
1. Default MUST be 10,000 in initializer
2. Warning logged if overridden to value < 10,000
3. Unit test validates default is 10,000
4. Documentation explains rationale

**Code validation:**
```swift
init(maxRequests: Int = 10_000, windowSeconds: TimeInterval = 60.0) {
    // CRITICAL: Default is 10,000 for HFT compatibility
```

**Test validation:**
```swift
func testDefaultIs10000() async {
    let rl = RateLimiter()
    let config = await rl.getConfig()
    XCTAssertEqual(config.maxRequests, 10_000)
}
```

### SDTS Issue #3: Replay Protection

**Problem:** Python implementation lacked replay protection

**Impact:** Security vulnerability - replay attacks possible

**Solution:**
- Implement nonce cache with expiry
- Check all incoming packets for duplicate nonces
- Automatic cleanup to prevent memory exhaustion

### Actor Safety

All three classes are actors:
- **ReplayProtection:** Thread-safe nonce tracking
- **RateLimiter:** Thread-safe per-peer counters
- **KeyStore:** Thread-safe key management

This prevents race conditions in concurrent environments.

### Performance Considerations

**Replay Protection:**
- O(1) lookup using dictionary
- Periodic cleanup (every 100 checks)
- Memory bounded by (rate × expiry time)

**Rate Limiter:**
- O(1) lookup per peer
- O(n) cleanup per check (n = requests in window)
- Memory: ~10,000 timestamps × 8 bytes = 80 KB per peer max

**KeyStore:**
- O(1) lookup per peer
- Minimal memory overhead

## Traceability Matrix

| Gap ID | Specification | Implementation | Tests |
|--------|---------------|----------------|-------|
| 2.1 | security-architecture.md § Replay | ReplayProtection.swift | ReplayProtectionTests.swift |
| 2.2 | security-architecture.md § Rate Limit | RateLimiter.swift | RateLimiterTests.swift |
| 8.7 | default-values.md § max_requests | RateLimiter.swift line 18 | testDefaultIs10000 |
| 3.4 | security-architecture.md § Per-Peer Keys | KeyStore.swift | KeyStoreTests.swift |

## Next Steps

After completing this step:

1. ✅ Protocol 0 (Text/JSON-RPC) working
2. ✅ Protocol 1 (Binary/Chunked) working
3. ✅ Security (Replay Protection + Rate Limiting) working
4. ⏭️ **Next:** Step 14 - SimplePacketBuilder (Test Helpers)
5. Then: Step 15 - Interoperability Test Suite

## References

- `specs/architecture/security-architecture.md` - Security architecture
- `specs/technical/default-values.md` - Default values and SDTS Issue #2
- Python Step 13: `steps/python/ybs-step_i3j4k5l6m7n8.md`
- SDTS Issue #2: Rate limiter mismatch (100 vs 10,000)
- SDTS Issue #3: Missing replay protection
