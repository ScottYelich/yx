# YBS Step 13: Security Features (Replay Protection + Rate Limiting)

**Step ID:** `ybs-step_i3j4k5l6m7n8`
**Language:** Python
**Estimated Duration:** 2-3 hours
**Prerequisites:** Steps 11-12 complete (Protocol layers working)

---

## Overview

Implement security features that protect against replay attacks and DoS attacks. These are **mandatory security layers** that sit between HMAC validation and protocol dispatch.

**Security Criticality:** 🔴 **WITHOUT THESE, YOUR SYSTEM IS VULNERABLE**
- No replay protection = Attackers can replay valid packets
- No rate limiting = Single peer can DDoS the system

**Traceability:**
- `specs/architecture/security-architecture.md` - Complete security specification
- `specs/technical/default-values.md` - Security defaults (CRITICAL: 10,000 req/60s, NOT 100!)
- SDTS Issue #2: Rate limiter default mismatch
- SDTS Issue #3: Missing replay protection

---

## Context

**What You Have:**
- Transport layer (UDP + HMAC)
- Protocol layers (Text + Binary)
- Everything working but vulnerable

**What You're Adding:**
- Replay Protection (nonce cache with time-based expiry)
- Rate Limiting (sliding window per peer)
- KeyStore (per-peer key management)
- Integration into receive pipeline

**Critical Historical Lesson (SDTS Issue #2):**
Swift v1.0.2 had `max_requests=100`, Python had `max_requests=10000`. High-frequency trading was blocked by Swift. **YOU MUST USE 10,000** (not 100).

---

## Goals

1. ✅ Replay Protection class (nonce cache)
2. ✅ Rate Limiter class (sliding window)
3. ✅ KeyStore class (per-peer keys)
4. ✅ Integration with UDP transport receive path
5. ✅ Unit tests for all security features
6. ✅ Security validation tests
7. ✅ Traceability ≥80%

---

## File Structure

```
canonical/python/src/yx/
├── transport/
│   ├── replay_protection.py    # NEW: Replay protection
│   ├── rate_limiter.py          # NEW: Rate limiting
│   ├── key_store.py             # NEW: Per-peer keys
│   └── udp_socket.py            # MODIFY: Integrate security
└── primitives/
    └── guid_factory.py          # EXTEND: Add guid_to_hex()
```

---

## Implementation

### Part 1: Replay Protection

**File:** `canonical/python/src/yx/transport/replay_protection.py`

```python
"""
Replay protection using nonce cache.

Traceability:
- specs/architecture/security-architecture.md (Layer 2: Replay Protection)
- specs/technical/default-values.md (replay_expiry = 300.0)
- SDTS Issue #3: Missing replay protection in Python
"""

import time
from dataclasses import dataclass, field
from typing import Dict
import logging

logger = logging.getLogger(__name__)


@dataclass
class ReplayProtection:
    """
    Prevents replay attacks using nonce cache.

    Traceability:
    - specs/architecture/security-architecture.md (Replay Protection Algorithm)
    - specs/technical/default-values.md (replay_expiry, cleanup_threshold)

    Nonce: First 16 bytes of packet (HMAC value)
    Expiry: 300 seconds (5 minutes)
    Cleanup: Automatic after 100 records
    """
    max_age: float = 300.0  # 5 minutes
    _seen_nonces: Dict[bytes, float] = field(default_factory=dict)

    def check_and_record(self, nonce: bytes) -> bool:
        """
        Check if nonce seen before, record if new.

        Args:
            nonce: Nonce bytes (typically HMAC, 16 bytes)

        Returns:
            True: Allowed (new nonce)
            False: Blocked (replay detected)

        Traceability:
        - specs/architecture/security-architecture.md (check_and_record)
        """
        now = time.time()

        # Check if seen
        if nonce in self._seen_nonces:
            logger.warning(f"Replay detected: {nonce.hex()}")
            return False  # REPLAY DETECTED

        # Record new nonce
        self._seen_nonces[nonce] = now

        # Periodic cleanup (every 100 records)
        if len(self._seen_nonces) >= 100:
            self._cleanup(now)

        return True  # ALLOWED

    def has_seen(self, nonce: bytes) -> bool:
        """Check if nonce has been seen (without recording)."""
        return nonce in self._seen_nonces

    def record(self, nonce: bytes):
        """Record nonce without checking."""
        self._seen_nonces[nonce] = time.time()

    def clear(self):
        """Clear all cached nonces."""
        self._seen_nonces.clear()

    @property
    def count(self) -> int:
        """Get number of cached nonces."""
        return len(self._seen_nonces)

    def _cleanup(self, now: float):
        """
        Remove expired nonces.

        Traceability:
        - specs/architecture/security-architecture.md (Memory Management)
        """
        expired = [
            nonce for nonce, timestamp in self._seen_nonces.items()
            if now - timestamp > self.max_age
        ]

        for nonce in expired:
            del self._seen_nonces[nonce]

        if expired:
            logger.debug(f"Cleaned up {len(expired)} expired nonces")
```

**Tests:** `canonical/python/src/yx/transport/test_replay_protection.py`

```python
"""
Tests for replay protection.

Traceability:
- specs/architecture/security-architecture.md (Replay Protection Tests)
"""

import pytest
import time
from yx.transport.replay_protection import ReplayProtection


def test_replay_protection_allows_new_nonce():
    """Test replay protection allows new nonces."""
    rp = ReplayProtection()
    nonce = b"nonce1234567890a"

    result = rp.check_and_record(nonce)

    assert result is True  # Allowed


def test_replay_protection_blocks_duplicate():
    """Test replay protection blocks duplicate nonces."""
    rp = ReplayProtection()
    nonce = b"nonce1234567890a"

    rp.check_and_record(nonce)  # First time: allowed
    result = rp.check_and_record(nonce)  # Second time: blocked

    assert result is False  # BLOCKED (replay)


def test_replay_protection_expires_old_nonces():
    """Test replay protection expires old nonces."""
    rp = ReplayProtection(max_age=0.1)  # 100ms expiry
    nonce = b"nonce1234567890a"

    rp.check_and_record(nonce)
    time.sleep(0.15)  # Wait for expiry

    # Trigger cleanup by adding 100 nonces
    for i in range(100):
        rp.check_and_record(f"nonce{i:016d}".encode())

    # Original nonce should be expired now
    result = rp.check_and_record(nonce)
    assert result is True  # Allowed (expired)


def test_replay_protection_count():
    """Test replay protection nonce count."""
    rp = ReplayProtection()

    assert rp.count == 0

    rp.check_and_record(b"nonce1234567890a")
    rp.check_and_record(b"nonce1234567890b")

    assert rp.count == 2


def test_replay_protection_clear():
    """Test replay protection clear."""
    rp = ReplayProtection()

    rp.check_and_record(b"nonce1234567890a")
    assert rp.count == 1

    rp.clear()
    assert rp.count == 0
```

---

### Part 2: Rate Limiting

**File:** `canonical/python/src/yx/transport/rate_limiter.py`

```python
"""
Rate limiting using sliding window per peer.

Traceability:
- specs/architecture/security-architecture.md (Layer 3: Rate Limiting)
- specs/technical/default-values.md (max_requests = 10,000)
- SDTS Issue #2: Rate limiter default mismatch (100 vs 10,000)
"""

import time
from dataclasses import dataclass, field
from typing import Dict, List, Set
import logging

logger = logging.getLogger(__name__)


@dataclass
class RateLimiter:
    """
    Rate limiter using sliding window per peer.

    Traceability:
    - specs/architecture/security-architecture.md (Rate Limiting)
    - specs/technical/default-values.md (max_requests, rate_limit_window)

    CRITICAL: max_requests MUST be 10,000 (not 100!)
    This is for high-frequency trading support.
    See SDTS Issue #2 for consequences of wrong default.
    """
    max_requests: int = 10000  # CRITICAL: 10,000 for HFT, NOT 100!
    window_seconds: float = 60.0
    trusted_guids: Set[str] = field(default_factory=set)
    _request_history: Dict[str, List[float]] = field(default_factory=dict)

    def check_rate_limit(self, peer_id: str, source_addr: tuple) -> bool:
        """
        Check if peer is under rate limit.

        Args:
            peer_id: Peer identifier (typically GUID hex)
            source_addr: (ip, port) tuple for logging

        Returns:
            True: Allowed
            False: Blocked (rate limit exceeded)

        Traceability:
        - specs/architecture/security-architecture.md (check_rate_limit)
        """
        # Check trusted GUID whitelist first
        if peer_id in self.trusted_guids:
            return True  # BYPASS rate limiting

        now = time.time()

        # Get peer's request history
        if peer_id not in self._request_history:
            self._request_history[peer_id] = []

        history = self._request_history[peer_id]

        # Remove requests outside window (sliding window)
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

    def add_trusted_guid(self, guid_hex: str):
        """
        Add GUID to trusted whitelist (bypass rate limiting).

        Args:
            guid_hex: GUID as hex string (e.g., "E32E3CA702DE")

        Traceability:
        - specs/architecture/security-architecture.md (Trusted GUID Whitelist)
        """
        self.trusted_guids.add(guid_hex.upper())
        logger.info(f"Added trusted GUID: {guid_hex}")

    def remove_trusted_guid(self, guid_hex: str):
        """Remove GUID from trusted whitelist."""
        self.trusted_guids.discard(guid_hex.upper())

    def is_trusted(self, guid_hex: str) -> bool:
        """Check if GUID is trusted."""
        return guid_hex.upper() in self.trusted_guids

    def reset_peer(self, peer_id: str):
        """Reset rate limit history for peer."""
        if peer_id in self._request_history:
            del self._request_history[peer_id]
```

**Tests:** `canonical/python/src/yx/transport/test_rate_limiter.py`

```python
"""
Tests for rate limiter.

Traceability:
- specs/architecture/security-architecture.md (Rate Limiting Tests)
"""

import pytest
import time
from yx.transport.rate_limiter import RateLimiter


def test_rate_limiter_allows_under_limit():
    """Test rate limiter allows requests under limit."""
    rl = RateLimiter(max_requests=10, window_seconds=60.0)

    # Send 10 requests (at limit)
    for i in range(10):
        result = rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
        assert result is True


def test_rate_limiter_blocks_over_limit():
    """Test rate limiter blocks requests over limit."""
    rl = RateLimiter(max_requests=10, window_seconds=60.0)

    # Send 10 requests (fill limit)
    for i in range(10):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))

    # 11th request should be blocked
    result = rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
    assert result is False  # BLOCKED


def test_rate_limiter_sliding_window():
    """Test rate limiter uses sliding window."""
    rl = RateLimiter(max_requests=5, window_seconds=0.2)  # 5 req / 200ms

    # Fill limit
    for i in range(5):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))

    # Next request blocked
    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False

    # Wait for window to slide
    time.sleep(0.25)

    # Should be allowed now (old requests expired)
    result = rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
    assert result is True


def test_rate_limiter_per_peer_isolation():
    """Test rate limiter isolates peers."""
    rl = RateLimiter(max_requests=5, window_seconds=60.0)

    # Fill limit for peer1
    for i in range(5):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))

    # peer1 blocked
    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False

    # peer2 still allowed (different peer)
    assert rl.check_rate_limit("peer2", ("127.0.0.1", 12346)) is True


def test_rate_limiter_trusted_guid_bypass():
    """Test trusted GUIDs bypass rate limiting."""
    rl = RateLimiter(max_requests=5, window_seconds=60.0)
    rl.add_trusted_guid("E32E3CA702DE")

    # Send 100 requests (way over limit)
    for i in range(100):
        result = rl.check_rate_limit("E32E3CA702DE", ("127.0.0.1", 12345))
        assert result is True  # All allowed (trusted)


def test_rate_limiter_default_is_10000():
    """Test rate limiter default is 10,000 (not 100)."""
    rl = RateLimiter()

    # CRITICAL: Must be 10,000 for high-frequency trading
    # See SDTS Issue #2
    assert rl.max_requests == 10000
    assert rl.window_seconds == 60.0
```

---

### Part 3: Per-Peer Key Management

**File:** `canonical/python/src/yx/transport/key_store.py`

```python
"""
Per-peer key management.

Traceability:
- specs/architecture/security-architecture.md (Per-Peer Key Management)
"""

from dataclasses import dataclass, field
from typing import Dict
import logging

logger = logging.getLogger(__name__)


@dataclass
class KeyStore:
    """
    Manages per-peer symmetric keys.

    Traceability:
    - specs/architecture/security-architecture.md (KeyStore)
    """
    default_key: bytes  # 32 bytes, fallback key
    _peer_keys: Dict[str, bytes] = field(default_factory=dict)

    def __post_init__(self):
        """Validate default key."""
        if len(self.default_key) != 32:
            raise ValueError("Default key must be 32 bytes")

    def get_key(self, peer_id: str) -> bytes:
        """
        Get key for peer (or default).

        Args:
            peer_id: Peer identifier (typically GUID hex)

        Returns:
            32-byte symmetric key

        Traceability:
        - specs/architecture/security-architecture.md (Lookup Algorithm)
        """
        return self._peer_keys.get(peer_id, self.default_key)

    def set_key(self, peer_id: str, key: bytes):
        """
        Set peer-specific key.

        Args:
            peer_id: Peer identifier
            key: 32-byte symmetric key

        Traceability:
        - specs/architecture/security-architecture.md (set_key)
        """
        if len(key) != 32:
            raise ValueError("Key must be 32 bytes")

        self._peer_keys[peer_id] = key
        logger.info(f"Set key for peer: {peer_id}")

    def remove_key(self, peer_id: str):
        """Remove peer-specific key."""
        if peer_id in self._peer_keys:
            del self._peer_keys[peer_id]
            logger.info(f"Removed key for peer: {peer_id}")

    def has_peer_key(self, peer_id: str) -> bool:
        """Check if peer has specific key."""
        return peer_id in self._peer_keys

    def peer_count(self) -> int:
        """Get number of peers with specific keys."""
        return len(self._peer_keys)
```

**Tests:** `canonical/python/src/yx/transport/test_key_store.py`

```python
"""Tests for key store."""

import pytest
import os
from yx.transport.key_store import KeyStore


def test_key_store_get_default():
    """Test key store returns default key for unknown peer."""
    default_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    key = ks.get_key("unknown_peer")

    assert key == default_key


def test_key_store_get_peer_specific():
    """Test key store returns peer-specific key."""
    default_key = os.urandom(32)
    peer_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    ks.set_key("peer1", peer_key)
    key = ks.get_key("peer1")

    assert key == peer_key
    assert key != default_key


def test_key_store_invalid_key_size():
    """Test key store rejects invalid key sizes."""
    default_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    with pytest.raises(ValueError):
        ks.set_key("peer1", b"short_key")


def test_key_store_remove_key():
    """Test key store removes peer key."""
    default_key = os.urandom(32)
    peer_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    ks.set_key("peer1", peer_key)
    assert ks.has_peer_key("peer1")

    ks.remove_key("peer1")
    assert not ks.has_peer_key("peer1")

    # Should return default now
    assert ks.get_key("peer1") == default_key


def test_key_store_peer_count():
    """Test key store peer count."""
    default_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    assert ks.peer_count() == 0

    ks.set_key("peer1", os.urandom(32))
    ks.set_key("peer2", os.urandom(32))

    assert ks.peer_count() == 2
```

---

### Part 4: GUID Hex Utility

**File:** `canonical/python/src/yx/primitives/guid_factory.py` (EXTEND existing file)

Add this function to the existing file:

```python
def guid_to_hex(guid: bytes) -> str:
    """
    Convert GUID to hex string (uppercase).

    Args:
        guid: 6-byte GUID

    Returns:
        Hex string (e.g., "E32E3CA702DE")

    Traceability:
    - specs/architecture/api-contracts.md (Type Conversion Utilities)
    """
    return guid.hex().upper()
```

---

## Verification

```bash
cd canonical/python

# Run security tests
pytest src/yx/transport/test_replay_protection.py -v
pytest src/yx/transport/test_rate_limiter.py -v
pytest src/yx/transport/test_key_store.py -v

# Verify all tests pass
pytest src/yx/ -v --tb=short
```

Expected: All tests passing, including security tests.

---

## Success Criteria

✅ **Security features implemented:**
- [ ] Replay Protection with nonce cache
- [ ] Rate Limiter with sliding window
- [ ] KeyStore for per-peer keys
- [ ] GUID hex conversion utility

✅ **Tests passing:**
- [ ] 15+ security tests passing
- [ ] Replay protection tests pass
- [ ] Rate limiter tests pass (including default validation)
- [ ] KeyStore tests pass

✅ **Critical validation:**
- [ ] Rate limiter default is 10,000 (NOT 100!)
- [ ] Replay expiry is 300 seconds
- [ ] All defaults match specs/technical/default-values.md

✅ **Traceability:**
- [ ] ≥80% of code has traceability comments
- [ ] References security-architecture.md
- [ ] References SDTS Issue #2 and #3

---

## Common Issues

### Issue 1: Wrong Rate Limit Default

**Symptom:** Tests show `max_requests = 100`

**Cause:** Copy-paste from example with wrong value

**Fix:** MUST be 10,000 (see SDTS Issue #2):
```python
max_requests: int = 10000  # NOT 100!
```

### Issue 2: Replay Protection Not Cleaning Up

**Symptom:** Memory grows unbounded

**Fix:** Cleanup triggered after 100 records:
```python
if len(self._seen_nonces) >= 100:
    self._cleanup(now)
```

---

## Next Steps

After this step:

1. ✅ Commit changes:
   ```bash
   git add src/yx/transport/replay_protection.py
   git add src/yx/transport/rate_limiter.py
   git add src/yx/transport/key_store.py
   git commit -m "Add security features (replay protection + rate limiting)

   - Implement replay protection with nonce cache (300s expiry)
   - Implement rate limiter with sliding window (10,000 req/60s)
   - Add per-peer key management (KeyStore)
   - 15+ security tests passing

   CRITICAL: Rate limiter default is 10,000 (not 100) for HFT support
   See SDTS Issue #2 for historical context

   Traceability: specs/architecture/security-architecture.md

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
   ```

2. ✅ Proceed to **Step 14: SimplePacketBuilder (Test Helpers)**

---

## References

**Specifications:**
- `specs/architecture/security-architecture.md` - Complete security spec
- `specs/technical/default-values.md` - Security defaults
- `specs/architecture/api-contracts.md` - Security APIs

**SDTS Issues:**
- SDTS Issue #2: Rate limiter default mismatch (100 vs 10,000)
- SDTS Issue #3: Missing replay protection in Python

**SDTS Reference:**
- `sdts-comparison/python/yx/transport/replay_protection.py`
- `sdts-comparison/python/yx/transport/rate_limiter.py`
- `sdts-comparison/python/yx/transport/key_store.py`
