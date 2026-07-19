# YBS Step: Rate Limiter

**Step ID:** `ybs-step_i3b0c1d2e3f4`
**Language:** Python
**Prerequisites:** Step i3a complete (replay_protection.py exists)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. File exists at `{{CONFIG:impl_src}}/transport/rate_limiter.py`
2. Tests pass when running pytest

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/transport/rate_limiter.py` — sliding window rate limiter per peer.

---

## ⚠️ CRITICAL DEFAULT VALUE

`max_requests` MUST be **10,000** (not 100).  
See SDTS Issue #2: Python had 10,000, Swift had 100. High-frequency trading broke.  
Reference: `protocol/specs/technical/default-values.md` (max_requests = 10,000)

---

## Implementation

**File:** `{{CONFIG:impl_src}}/transport/rate_limiter.py`

```python
"""
Rate limiting using sliding window per peer.

Traceability:
- protocol/specs/architecture/security-architecture.md (Layer 3: Rate Limiting)
- protocol/specs/technical/default-values.md (max_requests = 10,000 NOT 100!)
- SDTS Issue #2: Rate limiter default mismatch (was 100, must be 10,000)
"""

import time
from dataclasses import dataclass, field
from typing import Dict, List, Set
import logging

logger = logging.getLogger(__name__)


@dataclass
class RateLimiter:
    """
    Per-peer rate limiter with sliding window.

    CRITICAL: max_requests = 10,000 (for high-frequency trading support).
    See SDTS Issue #2 for consequences of wrong default.

    Traceability:
    - protocol/specs/architecture/security-architecture.md (Rate Limiting)
    - protocol/specs/technical/default-values.md (max_requests, rate_limit_window)
    """
    max_requests: int = 10000  # CRITICAL: 10,000 NOT 100
    window_seconds: float = 60.0
    trusted_guids: Set[str] = field(default_factory=set)
    _history: Dict[str, List[float]] = field(default_factory=dict)

    def check_rate_limit(self, peer_id: str, source_addr: tuple) -> bool:
        """
        Check if peer is within rate limit.

        Returns:
            True = allowed
            False = blocked (exceeded limit)
        """
        if peer_id in self.trusted_guids:
            return True

        now = time.time()
        if peer_id not in self._history:
            self._history[peer_id] = []

        history = self._history[peer_id]
        cutoff = now - self.window_seconds
        history[:] = [t for t in history if t > cutoff]

        if len(history) >= self.max_requests:
            logger.warning(f"Rate limit exceeded for {peer_id} from {source_addr}")
            return False

        history.append(now)
        return True

    def add_trusted_guid(self, guid_hex: str):
        self.trusted_guids.add(guid_hex.upper())

    def remove_trusted_guid(self, guid_hex: str):
        self.trusted_guids.discard(guid_hex.upper())

    def is_trusted(self, guid_hex: str) -> bool:
        return guid_hex.upper() in self.trusted_guids

    def reset_peer(self, peer_id: str):
        self._history.pop(peer_id, None)
```

---

## Tests

**File:** `{{CONFIG:impl_src}}/transport/test_rate_limiter.py`

```python
"""Tests for rate limiter."""

import pytest
import time
from yx.transport.rate_limiter import RateLimiter


def test_default_is_10000():
    """CRITICAL: default must be 10,000 not 100."""
    rl = RateLimiter()
    assert rl.max_requests == 10000
    assert rl.window_seconds == 60.0


def test_allows_under_limit():
    rl = RateLimiter(max_requests=10)
    for _ in range(10):
        assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is True


def test_blocks_over_limit():
    rl = RateLimiter(max_requests=10)
    for _ in range(10):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False


def test_sliding_window():
    rl = RateLimiter(max_requests=5, window_seconds=0.2)
    for _ in range(5):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False
    time.sleep(0.25)
    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is True


def test_per_peer_isolation():
    rl = RateLimiter(max_requests=5)
    for _ in range(5):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False
    assert rl.check_rate_limit("peer2", ("127.0.0.1", 12346)) is True


def test_trusted_bypass():
    rl = RateLimiter(max_requests=5)
    rl.add_trusted_guid("E32E3CA702DE")
    for _ in range(100):
        assert rl.check_rate_limit("E32E3CA702DE", ("127.0.0.1", 12345)) is True
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/transport/test_rate_limiter.py -v
```

All 6 tests must pass. `test_default_is_10000` is mandatory — if it fails, fix `max_requests`.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_i3b0c1d2e3f4-DONE.txt`:

```
STEP: ybs-step_i3b0c1d2e3f4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/transport/rate_limiter.py, test_rate_limiter.py
VERIFICATION: PASSED
NEXT: ybs-step_i3c0d1e2f3a4
```

Update `BUILD_STATUS.md`: add `- [x] i3b0c1d2e3f4`.
