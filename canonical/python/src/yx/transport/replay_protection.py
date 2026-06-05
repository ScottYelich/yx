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

        Returns:
            True: Allowed (new nonce)
            False: Blocked (replay detected)
        """
        now = time.time()

        if nonce in self._seen_nonces:
            logger.warning(f"Replay detected: {nonce.hex()}")
            return False  # REPLAY DETECTED

        self._seen_nonces[nonce] = now

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
        """Remove expired nonces."""
        expired = [
            nonce for nonce, timestamp in self._seen_nonces.items()
            if now - timestamp > self.max_age
        ]

        for nonce in expired:
            del self._seen_nonces[nonce]

        if expired:
            logger.debug(f"Cleaned up {len(expired)} expired nonces")
