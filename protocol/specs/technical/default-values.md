# YX Protocol: Default Values Specification

**Version:** 1.0.0
**Date:** 2026-01-18
**Status:** Normative Specification
**Traceability:** Gap 8.7, SDTS Issue #2

---

## Overview

This specification defines all default values for the YX protocol. **Cross-language consistency is CRITICAL.** Mismatched defaults between implementations cause production failures.

**Golden Rule:** ALL implementations (Python, Swift, Rust, Go, etc.) MUST use identical default values unless explicitly overridden by user configuration.

---

## Critical Historical Issue (SDTS Issue #2)

**Problem:** Swift v1.0.2 had `max_requests = 100`, Python had `max_requests = 10000`.

**Impact:** High-frequency trading systems blocked by Swift implementation. False positives in production.

**Time Lost:** 2 days debugging "broken" rate limiting.

**Root Cause:** Developer assumed "100 requests/minute seems reasonable" without checking Python implementation.

**Lesson:** Default values MUST be explicitly coordinated across implementations.

**Fix:** Changed Swift default to 10,000 to match Python. Documented requirement.

**Requirement:** ALL future implementations MUST use values in this specification.

---

## Default Values Table

### Transport Layer

| Parameter | Default Value | Type | Unit | Rationale |
|-----------|--------------|------|------|-----------|
| `udp_port` | 50000 | int | port | Application-layer default, avoid privileged ports |
| `broadcast_address` | "255.255.255.255" | string | IP | Universal broadcast address |
| `max_packet_size` | 4096 | int | bytes | Safe UDP maximum, well above typical MTU |
| `process_own_packets` | true | bool | - | Enable loopback testing by default |
| `bind_address` | "0.0.0.0" | string | IP | Listen on all interfaces |

**Socket Options (if supported):**
- `SO_REUSEADDR`: Enabled
- `SO_REUSEPORT`: Enabled (if OS supports)
- `SO_BROADCAST`: Enabled

---

### Protocol 1 (Binary Protocol)

| Parameter | Default Value | Type | Unit | Rationale |
|-----------|--------------|------|------|-----------|
| `chunk_size` | 1024 | int | bytes | Optimal balance: MTU-safe + overhead |
| `buffer_timeout` | 60.0 | float | seconds | Incomplete message expiry (trade-off: memory vs reliability) |
| `compression_threshold` | 65536 | int | bytes | Auto-compress messages >64KB |
| `deduplication_window` | 5.0 | float | seconds | Prevent duplicate delivery (short window for memory) |
| `default_channel_id` | 0 | int | - | Default channel for simple use cases |

**Chunk Size Calculation:**
```
UDP MTU: 1500 bytes
YX Header: 22 bytes (HMAC 16 + GUID 6)
Protocol 1 Header: 16 bytes
Overhead: 22 + 16 = 38 bytes
Safe Chunk Data: 1500 - 38 - margin = 1024 bytes
```

---

### Security Configuration

| Parameter | Default Value | Type | Unit | Rationale |
|-----------|--------------|------|------|-----------|
| **HMAC** |
| `hmac_truncation` | 16 | int | bytes | 128-bit security (adequate for integrity) |
| `hmac_algorithm` | "SHA256" | string | - | Industry standard, widely supported |
| **Rate Limiting** |
| `max_requests` | **10000** | int | count | **CRITICAL: High-frequency trading requirement** |
| `rate_limit_window` | 60.0 | float | seconds | Standard 1-minute window |
| `trusted_guids` | [] | list | - | Empty by default (no whitelisting) |
| **Replay Protection** |
| `replay_expiry` | 300.0 | float | seconds | 5-minute window (balance: security vs memory) |
| `replay_cleanup_threshold` | 100 | int | count | Trigger cleanup after N entries |
| **Encryption (Protocol 1)** |
| `aes_key_size` | 32 | int | bytes | 256-bit AES (strong security) |
| `aes_nonce_size` | 12 | int | bytes | 96-bit GCM nonce (standard) |
| `aes_tag_size` | 16 | int | bytes | 128-bit authentication tag |
| **Compression (Protocol 1)** |
| `compression_level` | 6 | int | 0-9 | Balanced speed/ratio (zlib default) |
| `compression_format` | "deflate" | string | - | Raw DEFLATE for Apple compatibility |

---

### Test Configuration

| Parameter | Default Value | Type | Unit | Rationale |
|-----------|--------------|------|------|-----------|
| `test_port` | 49999 | int | port | Avoid conflict with default port (50000) |
| `test_timeout` | 5.0 | float | seconds | Test receiver timeout |
| `test_key` | 32 bytes of 0x00 | bytes | - | Fixed key for reproducible tests |
| `test_guid` | 6 bytes of 0x01 | bytes | - | Fixed GUID for reproducible tests |

---

### Logging Configuration

| Parameter | Default Value | Type | Unit | Rationale |
|-----------|--------------|------|------|-----------|
| `log_level` | "INFO" | string | - | Production default (not DEBUG) |
| `log_format` | "emoji" | string | - | Human-readable with icons |
| `enable_forensics` | true | bool | - | Log failed HMACs to /tmp |
| `forensics_log_path` | "/tmp/hmac_failures.log" | string | path | Standard temp location |

---

## Cross-Language Validation Requirements

### Validation Procedure

Before ANY implementation can be marked "production ready," it MUST:

1. **Document Defaults:**
   - List all default values in README or documentation
   - Reference this specification
   - Highlight any intentional deviations

2. **Validate Against Spec:**
   - Create test that reads default values from code
   - Compare against this specification
   - Fail if any mismatch detected

3. **Cross-Language Test:**
   - Run interop tests with default configurations
   - No explicit configuration overrides
   - Must pass 48/48 tests

### Validation Test Template

**Python:**
```python
def test_default_values_match_spec():
    """Validate all defaults match specification."""
    assert Configuration.default().network.udp_port == 50000
    assert Configuration.default().security.max_requests == 10000  # CRITICAL!
    assert Configuration.default().security.rate_limit_window == 60.0
    assert Configuration.default().security.replay_expiry == 300.0
    assert Configuration.default().protocol.chunk_size == 1024
    # ... all other defaults
```

**Swift:**
```swift
func testDefaultValuesMatchSpec() throws {
    let config = Configuration.default()
    XCTAssertEqual(config.network.udpPort, 50000)
    XCTAssertEqual(config.security.maxRequests, 10000)  // CRITICAL!
    XCTAssertEqual(config.security.rateLimitWindow, 60.0)
    XCTAssertEqual(config.security.replayExpiry, 300.0)
    XCTAssertEqual(config.protocol.chunkSize, 1024)
    // ... all other defaults
}
```

---

## Configuration Override Patterns

### Environment Variables (Recommended)

Allow users to override defaults via environment variables:

| Environment Variable | Overrides | Example |
|---------------------|-----------|---------|
| `YX_UDP_PORT` | udp_port | `YX_UDP_PORT=9999` |
| `YX_MAX_REQUESTS` | max_requests | `YX_MAX_REQUESTS=50000` |
| `YX_RATE_WINDOW` | rate_limit_window | `YX_RATE_WINDOW=120` |
| `YX_REPLAY_EXPIRY` | replay_expiry | `YX_REPLAY_EXPIRY=600` |
| `YX_CHUNK_SIZE` | chunk_size | `YX_CHUNK_SIZE=2048` |
| `YX_LOG_LEVEL` | log_level | `YX_LOG_LEVEL=DEBUG` |
| `TEST_YX_PORT` | test_port | `TEST_YX_PORT=49998` |

### Configuration Files

**Python (YAML example):**
```yaml
network:
  udp_port: 50000
  broadcast_address: "255.255.255.255"

security:
  max_requests: 10000
  rate_limit_window: 60.0
  replay_expiry: 300.0

protocol:
  chunk_size: 1024
  buffer_timeout: 60.0
```

**Swift (Plist example):**
```xml
<dict>
    <key>network</key>
    <dict>
        <key>udpPort</key>
        <integer>50000</integer>
    </dict>
    <key>security</key>
    <dict>
        <key>maxRequests</key>
        <integer>10000</integer>
    </dict>
</dict>
```

### Programmatic Configuration

**Python:**
```python
from yx import YXConfiguration, NetworkConfig, SecurityConfig

config = YXConfiguration(
    network=NetworkConfig(udp_port=9999),
    security=SecurityConfig(max_requests=50000)
)

yx = YX(config=config)
```

**Swift:**
```swift
var config = Configuration.default()
config.network.udpPort = 9999
config.security.maxRequests = 50000

let yx = YX(configuration: config)
```

---

## Common Pitfalls and Anti-Patterns

### ❌ Anti-Pattern 1: Different Defaults

**WRONG:**
```python
# Python
rate_limiter = RateLimiter(max_requests=10000)

# Swift
let rateLimiter = RateLimiter(maxRequests: 100)  // ❌ MISMATCH!
```

**Impact:** Python → Swift communication blocked by rate limiter false positives.

**Fix:** Use identical defaults from this specification.

---

### ❌ Anti-Pattern 2: Hardcoded Values

**WRONG:**
```python
# Hardcoded in multiple places
socket.bind(("0.0.0.0", 50000))
rate_limiter = RateLimiter(max_requests=10000)
replay = ReplayProtection(max_age=300)
```

**Problem:** Changes require updating multiple locations. Risk of inconsistency.

**FIX:**
```python
# Centralized configuration
config = YXConfiguration.default()
socket.bind((config.network.bind_address, config.network.udp_port))
rate_limiter = RateLimiter(max_requests=config.security.max_requests)
replay = ReplayProtection(max_age=config.security.replay_expiry)
```

---

### ❌ Anti-Pattern 3: No Default Validation

**WRONG:**
```python
# No validation that defaults match spec
# Risk of drift over time
```

**FIX:**
```python
# Test that validates defaults
def test_defaults_match_spec():
    """Ensure defaults haven't drifted from specification."""
    # ... validation code
```

---

### ❌ Anti-Pattern 4: Assuming "Reasonable" Defaults

**WRONG:**
```swift
// Developer thinks: "100 requests/minute sounds reasonable"
let rateLimiter = RateLimiter(maxRequests: 100)
```

**Problem:** Assumption doesn't match other implementations or requirements.

**FIX:** Always check specification, never assume.

---

## Default Value Rationale

### Why `max_requests = 10000` (not 100)?

**Context:** High-frequency trading systems.

**Requirement:** Market data updates can arrive at 1000+ updates/second during volatile periods.

**Calculation:**
- Peak rate: 1000 packets/second
- Window: 60 seconds
- Required capacity: 60,000 req/60s

**Conservative Default:** 10,000 req/60s allows:
- 166 req/second sustained
- Handles normal operation comfortably
- Not too permissive (still provides DDoS protection)

**Why NOT 100:** Would allow only 1.6 req/second (insufficient for real-time data).

---

### Why `replay_expiry = 300` seconds (not 60)?

**Context:** Network delays, clock skew, retransmissions.

**Calculation:**
- Typical retransmission delay: 1-5 seconds
- Clock skew between systems: up to 10 seconds
- Safety margin: 5x = 50 seconds
- Round up: 300 seconds (5 minutes)

**Trade-off:**
- Shorter window (e.g., 60s): Better security, higher memory, more false positives
- Longer window (e.g., 600s): Worse security, lower memory, fewer false positives

**Conservative Default:** 300 seconds balances security and reliability.

---

### Why `chunk_size = 1024` bytes (not 1400)?

**Context:** UDP MTU is typically 1500 bytes.

**Calculation:**
- UDP MTU: 1500 bytes
- IP header: ~20 bytes
- UDP header: 8 bytes
- YX header: 22 bytes (HMAC + GUID)
- Protocol 1 header: 16 bytes
- Total overhead: ~66 bytes
- Safe payload: 1500 - 66 = 1434 bytes

**Why NOT 1400:** Closer to MTU, but:
- Some networks have lower MTU (1400, 1280)
- VPN/tunnel overhead
- IP fragmentation issues

**Conservative Default:** 1024 bytes provides margin for all scenarios.

---

## Verification Checklist

### Implementation Checklist

- [ ] All defaults documented in code comments
- [ ] Configuration class/struct with default() method
- [ ] Environment variable override support
- [ ] Test validates defaults against spec
- [ ] README lists all configurable parameters
- [ ] No hardcoded values (use config object)

### Cross-Language Checklist

- [ ] Python defaults validated
- [ ] Swift defaults validated
- [ ] Interop tests pass with default config (no overrides)
- [ ] Test output shows matching defaults
- [ ] No rate limiter false positives
- [ ] No replay protection false positives

---

## Version History

- **1.0.0** (2026-01-18): Initial specification

---

## References

**Related Specifications:**
- `specs/technical/yx-protocol-spec.md` - Protocol details
- `specs/architecture/security-architecture.md` - Security configuration
- `specs/architecture/protocol-layers.md` - Protocol configuration
- `specs/testing/interoperability-requirements.md` - Test requirements

**SDTS Issues:**
- SDTS Issue #2: Rate limiter default mismatch (documented in detail)
