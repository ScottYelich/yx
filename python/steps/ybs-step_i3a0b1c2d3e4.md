# YBS Step: Replay Protection

**Step ID:** `ybs-step_i3a0b1c2d3e4`
**Language:** Python
**Prerequisites:** Step h2d complete (binary_protocol.py exists)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. File exists at `{{CONFIG:impl_src}}/transport/replay_protection.py`
2. Tests pass when running pytest

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/transport/replay_protection.py` — nonce cache that prevents replay attacks.

---

## Implementation

**File:** `{{CONFIG:impl_src}}/transport/replay_protection.py`

```python
"""
Replay protection using nonce cache.

Traceability:
- protocol/specs/architecture/security-architecture.md (Layer 2: Replay Protection)
- protocol/specs/technical/default-values.md (replay_expiry = 300.0, cleanup_threshold = 100)
- SDTS Issue #3: Missing replay protection
"""

import time
from dataclasses import dataclass, field
from typing import Dict
import logging

logger = logging.getLogger(__name__)


@dataclass
class ReplayProtection:
    """
    Prevents replay attacks using time-bounded nonce cache.

    Traceability:
    - protocol/specs/architecture/security-architecture.md (Replay Protection)
    - protocol/specs/technical/default-values.md (replay_expiry=300.0)
    """
    max_age: float = 300.0
    _seen: Dict[bytes, float] = field(default_factory=dict)

    def check_and_record(self, nonce: bytes) -> bool:
        """
        Check if nonce seen before; record if new.

        Returns:
            True = allowed (new nonce)
            False = blocked (replay)
        """
        if nonce in self._seen:
            logger.warning(f"Replay detected: {nonce.hex()[:8]}...")
            return False

        self._seen[nonce] = time.time()

        if len(self._seen) >= 100:
            self._cleanup()

        return True

    def has_seen(self, nonce: bytes) -> bool:
        return nonce in self._seen

    def clear(self):
        self._seen.clear()

    @property
    def count(self) -> int:
        return len(self._seen)

    def _cleanup(self):
        now = time.time()
        expired = [n for n, t in self._seen.items() if now - t > self.max_age]
        for n in expired:
            del self._seen[n]
```

---

## Tests

**File:** `{{CONFIG:impl_src}}/transport/test_replay_protection.py`

```python
"""Tests for replay protection."""

import pytest
import time
from yx.transport.replay_protection import ReplayProtection


def test_allows_new_nonce():
    rp = ReplayProtection()
    assert rp.check_and_record(b"nonce" * 3 + b"x") is True


def test_blocks_duplicate():
    rp = ReplayProtection()
    nonce = b"nonce1234567890a"
    rp.check_and_record(nonce)
    assert rp.check_and_record(nonce) is False


def test_expires_old_nonces():
    rp = ReplayProtection(max_age=0.05)
    nonce = b"nonce1234567890a"
    rp.check_and_record(nonce)
    time.sleep(0.1)
    for i in range(100):
        rp.check_and_record(f"n{i:015d}".encode())
    assert rp.check_and_record(nonce) is True


def test_count():
    rp = ReplayProtection()
    assert rp.count == 0
    rp.check_and_record(b"nonce1234567890a")
    rp.check_and_record(b"nonce1234567890b")
    assert rp.count == 2


def test_clear():
    rp = ReplayProtection()
    rp.check_and_record(b"nonce1234567890a")
    rp.clear()
    assert rp.count == 0
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/transport/test_replay_protection.py -v
```

All 5 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_i3a0b1c2d3e4-DONE.txt`:

```
STEP: ybs-step_i3a0b1c2d3e4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/transport/replay_protection.py, test_replay_protection.py
VERIFICATION: PASSED
NEXT: ybs-step_i3b0c1d2e3f4
```

Update `BUILD_STATUS.md`: add `- [x] i3a0b1c2d3e4`.
