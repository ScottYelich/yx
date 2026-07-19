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
