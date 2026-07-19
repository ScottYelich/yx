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

    def __post_init__(self) -> None:
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

    def set_key(self, peer_id: str, key: bytes) -> None:
        """Set peer-specific key."""
        if len(key) != 32:
            raise ValueError("key must be 32 bytes")
        self._peer_keys[peer_id] = key

    def remove_key(self, peer_id: str) -> None:
        """Remove peer-specific key (falls back to default)."""
        self._peer_keys.pop(peer_id, None)

    def has_peer_key(self, peer_id: str) -> bool:
        """Check if peer has a specific key."""
        return peer_id in self._peer_keys

    def peer_count(self) -> int:
        """Return number of peer-specific keys."""
        return len(self._peer_keys)
