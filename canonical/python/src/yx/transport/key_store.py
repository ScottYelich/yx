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
        """Get key for peer (or default)."""
        return self._peer_keys.get(peer_id, self.default_key)

    def set_key(self, peer_id: str, key: bytes):
        """Set peer-specific key."""
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
