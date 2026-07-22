"""
Replay protection for YX protocol.

Prevents replay attacks by tracking nonces (HMACs) with timestamps.
Automatically expires old nonces to prevent memory growth.

Implementation matches Swift ReplayProtection actor.
"""

import time
from typing import Dict


class ReplayProtection:
    """Cache for tracking nonces to prevent replay attacks"""

    def __init__(self, max_age: float = 300.0):
        """
        Creates a nonce cache with specified max age.

        Args:
            max_age: How long nonces are remembered (default: 300 seconds / 5 minutes)
        """
        self._seen_nonces: Dict[bytes, float] = {}
        self._max_age = max_age

    def has_seen(self, nonce: bytes) -> bool:
        """Check if nonce has been seen before"""
        self._cleanup()
        return nonce in self._seen_nonces

    def record(self, nonce: bytes) -> None:
        """Record a nonce as seen"""
        self._seen_nonces[nonce] = time.time()

        # Cleanup after every 100 records
        if len(self._seen_nonces) % 100 == 0:
            self._cleanup()

    def check_and_record(self, nonce: bytes) -> bool:
        """
        Check and record nonce in one operation.

        Returns:
            True if new nonce (allowed), False if already seen (replay)
        """
        if self.has_seen(nonce):
            return False  # Replay detected
        self.record(nonce)
        return True  # New nonce, allowed

    @property
    def count(self) -> int:
        """Returns number of nonces currently cached"""
        return len(self._seen_nonces)

    def clear(self) -> None:
        """Clear all cached nonces"""
        self._seen_nonces.clear()

    def _cleanup(self) -> None:
        """Remove nonces older than max_age"""
        now = time.time()
        self._seen_nonces = {
            nonce: timestamp
            for nonce, timestamp in self._seen_nonces.items()
            if now - timestamp < self._max_age
        }
