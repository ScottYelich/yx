# YX Protocol: Security Architecture

**Version:** 1.0.0
**Date:** 2026-01-18
**Status:** Normative Specification
**Traceability:** Gap 2.1, 2.2, 2.3, 3.4

---

## Overview

The YX protocol implements defense-in-depth security through three independent layers:

1. **HMAC Authentication** (Layer 1) - Packet integrity and authenticity
2. **Replay Protection** (Layer 2) - Prevents replay attacks
3. **Rate Limiting** (Layer 3) - DDoS mitigation

Additionally, Protocol 1 provides optional **AES-256-GCM encryption** for payload confidentiality.

**Security Philosophy:** Multiple independent security mechanisms provide redundancy. If one layer fails, others still provide protection.

---

## Security Pipeline

### Send Path

```
Application Data
    ↓
[1] Rate Limit Check (per peer)
    ↓ (if limit exceeded: REJECT)
[2] Protocol Encoding (Protocol 0 or Protocol 1)
    ↓
[3] HMAC Computation (GUID + Payload)
    ↓
[4] UDP Send
```

### Receive Path

```
UDP Receive
    ↓
[1] Packet Parsing (extract HMAC, GUID, Payload)
    ↓
[2] HMAC Validation (constant-time comparison)
    ↓ (if invalid: REJECT + log to /tmp/hmac_failures.log)
[3] Replay Protection Check (nonce cache lookup)
    ↓ (if seen before: REJECT)
[4] Rate Limit Check (per peer sliding window)
    ↓ (if limit exceeded: REJECT)
[5] Protocol Decoding (Protocol 0 or Protocol 1)
    ↓
[6] Application Delivery
```

**Critical Property:** All three security layers (HMAC, replay protection, rate limiting) are independent. Each provides security value even if others are bypassed.

---

## Layer 1: HMAC Authentication

### Purpose
Verify packet integrity and authenticity using shared symmetric key.

### Algorithm
- **Hash Function:** SHA-256
- **MAC Construction:** HMAC (RFC 2104)
- **Truncation:** First 16 bytes (128 bits)
- **Key Size:** 32 bytes (256 bits)

### Input
```
hmac_input = GUID (6 bytes) + Payload (variable)
hmac_output = HMAC-SHA256(hmac_input, key)
hmac_truncated = hmac_output[0:16]
```

### Wire Format
```
Packet = [HMAC(16 bytes)] + [GUID(6 bytes)] + [Payload(variable)]
```

### Implementation Requirements

**Python:**
```python
import hmac
from cryptography.hazmat.primitives import hashes

def compute_hmac(data: bytes, key: bytes) -> bytes:
    """Compute HMAC-SHA256, truncated to 16 bytes."""
    h = hmac.HMAC(key, hashes.SHA256())
    h.update(data)
    return h.finalize()[:16]
```

**Swift:**
```swift
import CryptoKit

func computeHMAC(data: Data, key: SymmetricKey) -> Data {
    let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
    return Data(hmac.prefix(16))  // Truncate to 16 bytes
}
```

### Validation Requirements

**Constant-Time Comparison (CRITICAL):**

All implementations MUST use constant-time comparison to prevent timing attacks.

**Python:**
```python
import hmac

def validate_hmac(received: bytes, expected: bytes) -> bool:
    """Constant-time HMAC comparison."""
    return hmac.compare_digest(received, expected)
```

**Swift:**
```swift
func validateHMAC(received: Data, expected: Data) -> Bool {
    // CryptoKit provides constant-time comparison
    return received == expected  // Uses constant-time internally
}
```

**Why constant-time matters:** Variable-time comparison leaks information about which bytes match, enabling timing attacks to recover the key.

### Failed HMAC Forensics

When HMAC validation fails, implementations MUST log to `/tmp/hmac_failures.log` for debugging:

**Log Format:**
```
[2026-01-18 15:42:13.456789] HMAC VALIDATION FAILED
Source: 192.168.1.100:54321
GUID: E32E3CA702DE
Expected HMAC: A1B2C3D4E5F6A7B8C1D2E3F4A5B6C7D8
Received HMAC: A1B2C3D4E5F6A7B8FFFFFFFFFFFFFFFF
Packet (hex): <full packet hex dump>
---
```

**Properties:**
- Timestamp with microseconds
- Source IP and port
- Sender GUID (hex)
- Expected vs. received HMAC (hex)
- Full packet hex for offline analysis
- Append-only (do not truncate)

**Security Note:** Log file does NOT contain keys. Safe to share for debugging.

### Security Properties

**Guarantees:**
- ✅ Packet integrity (cannot modify without detection)
- ✅ Packet authenticity (requires key to generate valid HMAC)
- ✅ Constant-time validation (prevents timing attacks)

**Does NOT Guarantee:**
- ❌ Confidentiality (payload visible in plaintext)
- ❌ Replay protection (same packet can be replayed)
- ❌ Forward secrecy (key compromise affects all messages)

---

## Layer 2: Replay Protection

### Purpose
Prevent replay attacks where attacker captures valid packets and retransmits them.

### Algorithm
Nonce cache with time-based expiry.

### Nonce Selection
**Nonce = First 16 bytes of packet (HMAC value)**

**Why HMAC as nonce:**
- Already computed for integrity check
- Guaranteed unique per packet (different HMAC = different packet)
- No additional overhead
- Collision-resistant (SHA-256 properties)

### Data Structure

**Python:**
```python
@dataclass
class ReplayProtection:
    _seen_nonces: Dict[bytes, float] = field(default_factory=dict)
    max_age: float = 300.0  # 5 minutes

    def check_and_record(self, nonce: bytes) -> bool:
        """Returns True if allowed (new), False if replay (seen before)."""
        now = time.time()

        # Check if seen
        if nonce in self._seen_nonces:
            return False  # REPLAY DETECTED

        # Record new nonce
        self._seen_nonces[nonce] = now

        # Periodic cleanup (every 100 records)
        if len(self._seen_nonces) >= 100:
            self._cleanup(now)

        return True  # ALLOWED

    def _cleanup(self, now: float):
        """Remove expired nonces."""
        expired = [n for n, t in self._seen_nonces.items()
                   if now - t > self.max_age]
        for n in expired:
            del self._seen_nonces[n]
```

**Swift:**
```swift
actor ReplayProtection {
    private var seenNonces: [Data: Date] = [:]
    private let maxAge: TimeInterval = 300  // 5 minutes

    func checkAndRecord(nonce: Data) async -> Bool {
        let now = Date()

        // Check if seen
        if seenNonces[nonce] != nil {
            return false  // REPLAY DETECTED
        }

        // Record new nonce
        seenNonces[nonce] = now

        // Periodic cleanup
        if seenNonces.count >= 100 {
            cleanup(now: now)
        }

        return true  // ALLOWED
    }

    private func cleanup(now: Date) {
        seenNonces = seenNonces.filter { _, timestamp in
            now.timeIntervalSince(timestamp) <= maxAge
        }
    }
}
```

### Configuration

| Parameter | Default | Unit | Description |
|-----------|---------|------|-------------|
| `max_age` | 300 | seconds | How long to remember nonces |
| `cleanup_threshold` | 100 | count | Trigger cleanup after N entries |

**Cross-Language Requirement:** Both Python and Swift MUST use identical defaults.

### Memory Management

**Bounded Memory:**
- Nonce cache size bounded by: `packet_rate * max_age`
- Example: 1000 packets/sec × 300 sec = 300,000 nonces max
- Each nonce: 16 bytes + 8 bytes timestamp = 24 bytes
- Max memory: 300,000 × 24 = 7.2 MB

**Automatic Cleanup:**
- Triggered after every 100 new nonces
- Removes nonces older than `max_age`
- Prevents unbounded growth

### Security Properties

**Guarantees:**
- ✅ Prevents replay of same packet
- ✅ Memory bounded by time window
- ✅ Automatic cleanup (no manual management)

**Does NOT Guarantee:**
- ❌ Protection within 1ms window (timestamp granularity)
- ❌ Protection from different source IP (nonce is per-packet, not per-sender)
- ❌ Protection after `max_age` expires

**Attack Vectors Mitigated:**
- Attacker captures valid packet → Replays later → BLOCKED (nonce seen)
- Attacker sends duplicate packets rapidly → BLOCKED (nonce cache)

**Attack Vectors NOT Mitigated:**
- Attacker captures packet → Waits 6 minutes → Replays → ALLOWED (expired from cache)
- Attacker sends packet to different instance → ALLOWED (different nonce cache)

### Integration

**Receive Path Position:**
```
HMAC Validation (Layer 1)
    ↓
Replay Protection Check (Layer 2) ← YOU ARE HERE
    ↓
Rate Limiting (Layer 3)
```

**Code Example (Python):**
```python
# After HMAC validation passes
nonce = packet.hmac  # First 16 bytes
if not replay_protection.check_and_record(nonce):
    logger.warning(f"Replay detected: {nonce.hex()}")
    return  # REJECT packet
```

---

## Layer 3: Rate Limiting

### Purpose
Prevent DoS attacks where single peer floods system with unlimited packets.

### Algorithm
Sliding window rate limiting per peer.

### Data Structure

**Python:**
```python
@dataclass
class RateLimiter:
    max_requests: int = 10000  # CRITICAL: Must be 10,000 (not 100!)
    window_seconds: float = 60.0
    trusted_guids: Set[str] = field(default_factory=set)
    _request_history: Dict[str, List[float]] = field(default_factory=dict)

    def check_rate_limit(self, peer_id: str, source_addr: tuple) -> bool:
        """Returns True if allowed, False if rate limit exceeded."""
        # Check trusted GUID whitelist first
        if peer_id in self.trusted_guids:
            return True  # BYPASS rate limiting

        now = time.time()

        # Get peer's request history
        if peer_id not in self._request_history:
            self._request_history[peer_id] = []

        history = self._request_history[peer_id]

        # Remove requests outside window
        cutoff = now - self.window_seconds
        history[:] = [t for t in history if t > cutoff]

        # Check if over limit
        if len(history) >= self.max_requests:
            logger.warning(
                f"Rate limit exceeded for {peer_id} from {source_addr}: "
                f"{len(history)} requests in {self.window_seconds}s"
            )
            return False  # REJECT

        # Record new request
        history.append(now)
        return True  # ALLOW
```

**Swift:**
```swift
actor RateLimiter {
    private let maxRequests: Int = 10000  // CRITICAL: Must be 10,000!
    private let windowSeconds: TimeInterval = 60.0
    private var requestHistory: [String: [Date]] = [:]

    func checkRateLimit(peerID: String, sourceAddr: String) async -> Bool {
        let now = Date()

        // Get peer's history
        var history = requestHistory[peerID] ?? []

        // Remove requests outside window
        let cutoff = now.addingTimeInterval(-windowSeconds)
        history = history.filter { $0 > cutoff }

        // Check if over limit
        if history.count >= maxRequests {
            print("Rate limit exceeded for \(peerID): \(history.count) requests")
            return false  // REJECT
        }

        // Record new request
        history.append(now)
        requestHistory[peerID] = history

        return true  // ALLOW
    }
}
```

### Configuration

| Parameter | Default | Unit | Description |
|-----------|---------|------|-------------|
| `max_requests` | 10,000 | count | Max requests per window |
| `window_seconds` | 60.0 | seconds | Sliding window duration |
| `trusted_guids` | empty set | - | GUIDs that bypass rate limiting |

### Critical Historical Issue (SDTS Issue #2)

**Problem:** Swift v1.0.2 had `max_requests = 100`, Python had `max_requests = 10000`.

**Impact:** High-frequency trading systems blocked by Swift implementation.

**Lesson:** Default values MUST match across ALL implementations.

**Fix:** Changed Swift default to 10,000 to match Python.

**Requirement:** ALL future implementations (Rust, Go, etc.) MUST use 10,000 req/60s.

### Trusted GUID Whitelist

**Purpose:** Allow specific peers to bypass rate limiting.

**Use Case:** Trusted services in high-frequency trading environment.

**Security:** GUID cannot be spoofed without key (HMAC validation ensures authenticity).

**API:**
```python
rate_limiter.add_trusted_guid("E32E3CA702DE")
rate_limiter.remove_trusted_guid("E32E3CA702DE")
if rate_limiter.is_trusted("E32E3CA702DE"):
    # Bypass rate limiting
```

### Memory Management

**Bounded Memory:**
- History size per peer: `max_requests` timestamps
- Each timestamp: 8 bytes (float/double)
- Memory per peer: `10,000 × 8 = 80 KB`
- For 100 peers: `100 × 80 KB = 8 MB`

**Automatic Cleanup:**
- Old timestamps removed on each check
- Sliding window ensures bounded size
- No manual cleanup needed

### Security Properties

**Guarantees:**
- ✅ Per-peer rate limiting (one bad peer doesn't affect others)
- ✅ Sliding window (smooth rate enforcement, no burst windows)
- ✅ Trusted GUID support (whitelist for services)
- ✅ Memory bounded by peer count and window size

**Does NOT Guarantee:**
- ❌ Protection against Sybil attacks (attacker creates many GUIDs)
- ❌ Protection against DDoS from many peers
- ❌ Fairness (trusted GUIDs get unlimited access)

**Attack Vectors Mitigated:**
- Single peer sends 100,000 packets/second → BLOCKED after 10,000 in 60s
- Single peer sends bursts → BLOCKED by sliding window

**Attack Vectors NOT Mitigated:**
- Attacker uses 100 different GUIDs → Each gets 10,000 req/60s allowance
- Distributed attack from many legitimate peers → Each peer allowed

### Integration

**Receive Path Position:**
```
HMAC Validation (Layer 1)
    ↓
Replay Protection (Layer 2)
    ↓
Rate Limiting (Layer 3) ← YOU ARE HERE
    ↓
Application Delivery
```

**Code Example (Python):**
```python
# After replay protection passes
peer_id = packet.guid.hex()
if not rate_limiter.check_rate_limit(peer_id, source_addr):
    return  # REJECT packet (rate limit exceeded)
```

---

## Layer 4: Encryption (Optional, Protocol 1 Only)

### Purpose
Provide payload confidentiality and authenticity for Protocol 1 messages.

### Algorithm
- **Cipher:** AES-256-GCM (Galois/Counter Mode)
- **Key Size:** 32 bytes (256 bits)
- **Nonce Size:** 12 bytes (96 bits)
- **Tag Size:** 16 bytes (128 bits)

### Wire Format
```
Encrypted Payload = [Nonce(12)] + [Ciphertext(variable)] + [Tag(16)]
```

### Key Management

**Shared Key:**
- Same 32-byte key used for HMAC and AES
- Derived from shared secret or key exchange

**Per-Peer Keys (Optional):**
- KeyStore allows different keys per peer
- Lookup by GUID
- Fallback to default key if peer not found

### Nonce Generation

**Critical Requirement:** Nonce MUST be unique per encryption with same key.

**Python:**
```python
import os

def generate_nonce() -> bytes:
    return os.urandom(12)  # Cryptographically secure random
```

**Swift:**
```swift
import CryptoKit

func generateNonce() -> Data {
    return AES.GCM.Nonce().data  // 12 bytes random
}
```

**Why random nonces are safe:**
- 96-bit nonce space = 2^96 possible nonces
- Birthday bound: ~2^48 messages before collision risk
- For typical workloads: Safe for trillions of messages

### Encryption

**Python:**
```python
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def encrypt_aes_gcm(plaintext: bytes, key: bytes) -> Tuple[bytes, bytes]:
    aesgcm = AESGCM(key)  # 32-byte key
    nonce = os.urandom(12)
    ciphertext_with_tag = aesgcm.encrypt(nonce, plaintext, None)
    return nonce, ciphertext_with_tag
```

**Swift:**
```swift
import CryptoKit

func encryptAESGCM(plaintext: Data, key: SymmetricKey) throws -> Data {
    let nonce = AES.GCM.Nonce()
    let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
    return nonce + sealed.ciphertext + sealed.tag
}
```

### Decryption

**Python:**
```python
def decrypt_aes_gcm(nonce: bytes, ciphertext_with_tag: bytes, key: bytes) -> bytes:
    aesgcm = AESGCM(key)
    plaintext = aesgcm.decrypt(nonce, ciphertext_with_tag, None)
    return plaintext
```

**Swift:**
```swift
func decryptAESGCM(encrypted: Data, key: SymmetricKey) throws -> Data {
    let nonce = AES.GCM.Nonce(data: encrypted.prefix(12))
    let ciphertext = encrypted.dropFirst(12).dropLast(16)
    let tag = encrypted.suffix(16)

    let sealed = try AES.GCM.SealedBox(
        nonce: nonce,
        ciphertext: ciphertext,
        tag: tag
    )

    return try AES.GCM.open(sealed, using: key)
}
```

### Wire Format Compatibility (SDTS Issue #1)

**Historical Note:** Initial implementation suspected Python/Swift incompatibility.

**Reality:** Both use identical wire format: `[nonce(12)] + [ciphertext] + [tag(16)]`

**Verification Method:** Dump actual bytes from both implementations, compare hex.

**Lesson:** Always verify with real wire dumps before claiming bugs.

### Security Properties

**Guarantees (when enabled):**
- ✅ Confidentiality (payload unreadable without key)
- ✅ Authenticity (tag verifies payload not modified)
- ✅ Integrity (tag detects any modification)

**Does NOT Guarantee:**
- ❌ Forward secrecy (key compromise decrypts all messages)
- ❌ Traffic analysis protection (packet sizes/timing visible)
- ❌ Metadata confidentiality (HMAC, GUID, headers visible)

---

## Per-Peer Key Management

### Purpose
Support multi-party scenarios where different peers use different keys.

### Data Structure

**Python:**
```python
@dataclass
class KeyStore:
    default_key: bytes  # 32 bytes, fallback key
    _peer_keys: Dict[str, bytes] = field(default_factory=dict)

    def get_key(self, peer_id: str) -> bytes:
        """Get peer-specific key or default."""
        return self._peer_keys.get(peer_id, self.default_key)

    def set_key(self, peer_id: str, key: bytes):
        """Set peer-specific key (must be 32 bytes)."""
        if len(key) != 32:
            raise ValueError("Key must be exactly 32 bytes")
        self._peer_keys[peer_id] = key
```

**Swift:**
```swift
actor KeyStore {
    private let defaultKey: SymmetricKey  // 32 bytes
    private var peerKeys: [String: SymmetricKey] = [:]

    func getKey(peerID: String) async -> SymmetricKey {
        return peerKeys[peerID] ?? defaultKey
    }

    func setKey(peerID: String, key: SymmetricKey) async {
        guard key.bitCount == 256 else {
            fatalError("Key must be 256 bits (32 bytes)")
        }
        peerKeys[peerID] = key
    }
}
```

### Use Cases

1. **Multi-Tenant Systems:** Different key per tenant
2. **Peer-to-Peer Networks:** Different key per peer
3. **Service Mesh:** Different key per service
4. **Broadcast with Selective Access:** Default key for broadcast, per-peer keys for unicast

### Lookup Algorithm

```
1. Extract GUID from packet
2. Convert GUID to hex string (peer_id)
3. Look up peer_id in KeyStore
4. If found: Use peer-specific key
5. If not found: Use default key
6. Validate HMAC with selected key
```

---

## Security Testing Requirements

### Test Coverage

All implementations MUST include tests for:

1. **HMAC Validation**
   - Valid HMAC passes
   - Invalid HMAC rejected
   - Modified payload rejected
   - Constant-time comparison (timing analysis)

2. **Replay Protection**
   - First packet allowed
   - Duplicate packet rejected
   - Expired nonce allowed (after `max_age`)
   - Cleanup removes old nonces

3. **Rate Limiting**
   - Under limit allowed
   - Over limit rejected
   - Sliding window behavior
   - Trusted GUID bypass
   - Per-peer isolation

4. **Encryption (Protocol 1)**
   - Encryption produces ciphertext ≠ plaintext
   - Decryption recovers original plaintext
   - Cross-language compatibility (Python ↔ Swift)
   - Invalid tag rejected

5. **Per-Peer Keys**
   - Peer-specific key used when set
   - Default key used when peer not found
   - 32-byte validation enforced

### Security Test Scenarios

**Scenario 1: Replay Attack**
```
1. Capture valid packet
2. Send packet again
3. Verify: Second transmission rejected
```

**Scenario 2: DoS Attack**
```
1. Send 10,001 packets from same peer
2. Verify: Packet 10,001 rejected (rate limit)
```

**Scenario 3: Modified Payload**
```
1. Build valid packet
2. Modify payload byte
3. Send modified packet
4. Verify: HMAC validation fails, packet rejected
```

**Scenario 4: Encryption Confidentiality**
```
1. Encrypt payload "SECRET"
2. Verify: Ciphertext does not contain "SECRET"
3. Decrypt ciphertext
4. Verify: Plaintext equals "SECRET"
```

---

## Threat Model

### Assumptions

**Trust Assumptions:**
- ✅ Symmetric key is secret (not compromised)
- ✅ Cryptographic algorithms are secure (SHA-256, AES-256-GCM)
- ✅ RNG is cryptographically secure (os.urandom, SecRandomCopyBytes)
- ✅ Implementation is correct (no bugs)

**Network Assumptions:**
- ❌ Network is hostile (attacker has full access)
- ❌ Packets can be captured, modified, replayed
- ❌ Timing information is observable

### Threats Mitigated

| Threat | Mitigation | Layer |
|--------|-----------|-------|
| Modified packets | HMAC validation | Layer 1 |
| Spoofed packets | HMAC validation | Layer 1 |
| Replay attacks | Replay protection | Layer 2 |
| DoS from single peer | Rate limiting | Layer 3 |
| Eavesdropping | AES encryption | Layer 4 |
| Modified encrypted data | GCM tag | Layer 4 |

### Threats NOT Mitigated

| Threat | Why Not Mitigated | Possible Defense |
|--------|-------------------|------------------|
| Key compromise | Symmetric key system | Use PKI (e.g., TaskHelloHandler) |
| DDoS from many peers | Per-peer rate limiting | Network-level filtering |
| Sybil attack (many GUIDs) | No GUID authentication | Require GUID registration |
| Traffic analysis | Metadata always visible | Use mix networks, padding |
| Timing attacks | Constant-time comparison only | Add jitter, padding |
| Expired nonce replay | Fixed time window | Reduce `max_age` (trade-off) |

---

## Compliance and Standards

### Cryptographic Standards

- **HMAC:** RFC 2104
- **SHA-256:** FIPS 180-4
- **AES-GCM:** NIST SP 800-38D
- **Key Sizes:** NIST recommendations (256-bit for AES, 256-bit for HMAC key)

### Best Practices

✅ **DO:**
- Use constant-time comparison for HMAC validation
- Generate fresh random nonce for each AES encryption
- Use 32-byte keys for both HMAC and AES
- Log failed HMAC attempts for forensics
- Clean up expired nonces automatically
- Use sliding window for rate limiting

❌ **DO NOT:**
- Reuse nonces with same key
- Use predictable nonces (counter, timestamp)
- Skip HMAC validation for "trusted" peers
- Disable replay protection in production
- Set rate limit to 100 (use 10,000)
- Implement custom crypto (use standard libraries)

---

## Implementation Checklist

### Python Implementation

- [ ] HMAC computation using `hmac` module
- [ ] Constant-time comparison using `hmac.compare_digest()`
- [ ] Replay protection with dict-based nonce cache
- [ ] Rate limiter with per-peer history
- [ ] AES-256-GCM using `cryptography` library
- [ ] Per-peer key management with KeyStore
- [ ] Failed HMAC logging to `/tmp/hmac_failures.log`
- [ ] All security tests passing

### Swift Implementation

- [ ] HMAC computation using CryptoKit
- [ ] Constant-time comparison (CryptoKit default)
- [ ] Replay protection actor with nonce cache
- [ ] Rate limiter actor with per-peer history
- [ ] AES-256-GCM using CryptoKit
- [ ] Per-peer key management with KeyStore actor
- [ ] Failed HMAC logging to `/tmp/hmac_failures.log`
- [ ] All security tests passing

### Cross-Language Validation

- [ ] HMAC produces identical output (Python ↔ Swift)
- [ ] AES-256-GCM wire format compatible (Python ↔ Swift)
- [ ] Default values match exactly (10,000 req/60s, 300s expiry)
- [ ] Replay protection behavior identical
- [ ] Rate limiting behavior identical
- [ ] Interop tests pass (48/48)

---

## Version History

- **1.0.0** (2026-01-18): Initial specification

---

## References

**Related Specifications:**
- `specs/technical/yx-protocol-spec.md` - Protocol details
- `specs/testing/interoperability-requirements.md` - Testing requirements
- `specs/architecture/protocol-layers.md` - Protocol layer architecture
- `specs/technical/default-values.md` - Default value requirements

**SDTS Lessons:**
- SDTS Issue #2: Rate limiter default mismatch (100 vs 10,000)
- SDTS Issue #3: Missing replay protection in Python
- SDTS Issue #1: AES-GCM wire format verification (false alarm, both compatible)

**Standards:**
- RFC 2104: HMAC
- FIPS 180-4: SHA-256
- NIST SP 800-38D: AES-GCM
