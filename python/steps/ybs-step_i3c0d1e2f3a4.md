# YBS Step: Key Store

**Step ID:** `ybs-step_i3c0d1e2f3a4`
**Language:** Python
**Prerequisites:** Step i3b complete (rate_limiter.py exists)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. File exists at `{{CONFIG:impl_src}}/transport/key_store.py`
2. Tests pass when running pytest

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

Create `{{CONFIG:impl_src}}/transport/key_store.py` — per-peer symmetric key management.

---

## Implementation

**File:** `{{CONFIG:impl_src}}/transport/key_store.py`

```python
"""
Per-peer key management.

Traceability:
- protocol/specs/architecture/security-architecture.md (Per-Peer Key Management)
"""

from dataclasses import dataclass, field
from typing import Dict
import logging

logger = logging.getLogger(__name__)


@dataclass
class KeyStore:
    """
    Manages per-peer 32-byte symmetric keys.

    Falls back to default_key when no peer-specific key is configured.

    Traceability:
    - protocol/specs/architecture/security-architecture.md (KeyStore)
    """
    default_key: bytes
    _peer_keys: Dict[str, bytes] = field(default_factory=dict)

    def __post_init__(self):
        if len(self.default_key) != 32:
            raise ValueError("default_key must be 32 bytes")

    def get_key(self, peer_id: str) -> bytes:
        """
        Get key for peer; falls back to default_key.

        Args:
            peer_id: Peer identifier (typically GUID hex)

        Returns:
            32-byte key
        """
        return self._peer_keys.get(peer_id, self.default_key)

    def set_key(self, peer_id: str, key: bytes):
        """Set peer-specific key."""
        if len(key) != 32:
            raise ValueError("key must be 32 bytes")
        self._peer_keys[peer_id] = key

    def remove_key(self, peer_id: str):
        """Remove peer-specific key (falls back to default)."""
        self._peer_keys.pop(peer_id, None)

    def has_peer_key(self, peer_id: str) -> bool:
        return peer_id in self._peer_keys

    def peer_count(self) -> int:
        return len(self._peer_keys)
```

---

## Tests

**File:** `{{CONFIG:impl_src}}/transport/test_key_store.py`

```python
"""Tests for key store."""

import pytest
import os
from yx.transport.key_store import KeyStore


def test_default_key():
    default = os.urandom(32)
    ks = KeyStore(default_key=default)
    assert ks.get_key("unknown") == default


def test_peer_specific_key():
    default = os.urandom(32)
    peer_key = os.urandom(32)
    ks = KeyStore(default_key=default)
    ks.set_key("peer1", peer_key)
    assert ks.get_key("peer1") == peer_key
    assert ks.get_key("peer1") != default


def test_invalid_key_size():
    ks = KeyStore(default_key=os.urandom(32))
    with pytest.raises(ValueError):
        ks.set_key("peer1", b"short")


def test_remove_key():
    default = os.urandom(32)
    ks = KeyStore(default_key=default)
    ks.set_key("peer1", os.urandom(32))
    assert ks.has_peer_key("peer1")
    ks.remove_key("peer1")
    assert not ks.has_peer_key("peer1")
    assert ks.get_key("peer1") == default


def test_peer_count():
    ks = KeyStore(default_key=os.urandom(32))
    assert ks.peer_count() == 0
    ks.set_key("p1", os.urandom(32))
    ks.set_key("p2", os.urandom(32))
    assert ks.peer_count() == 2
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/transport/test_key_store.py -v
```

All 5 tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_i3c0d1e2f3a4-DONE.txt`:

```
STEP: ybs-step_i3c0d1e2f3a4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/transport/key_store.py, test_key_store.py
VERIFICATION: PASSED
NEXT: ybs-step_i3d0e1f2a3b4
```

Update `BUILD_STATUS.md`: add `- [x] i3c0d1e2f3a4`.
