"""
Key store for managing per-peer symmetric keys
"""

from typing import Dict, Optional


class KeyStore:
    """Manage symmetric keys for peers"""

    def __init__(self, default_key: bytes):
        """
        Initialize key store with default key.

        Args:
            default_key: Default symmetric key (32 bytes for AES-256)
        """
        if len(default_key) != 32:
            raise ValueError("Default key must be 32 bytes")

        self.default_key = default_key
        self._peer_keys: Dict[str, bytes] = {}

    def get_key(self, peer_id: str) -> bytes:
        """
        Get key for peer, or default if not found.

        Args:
            peer_id: Peer identifier (usually GUID hex)

        Returns:
            bytes: Symmetric key
        """
        return self._peer_keys.get(peer_id, self.default_key)

    def set_key(self, peer_id: str, key: bytes):
        """
        Set key for specific peer.

        Args:
            peer_id: Peer identifier
            key: Symmetric key (32 bytes)
        """
        if len(key) != 32:
            raise ValueError("Key must be 32 bytes")
        self._peer_keys[peer_id] = key

    def remove_key(self, peer_id: str):
        """Remove peer-specific key"""
        if peer_id in self._peer_keys:
            del self._peer_keys[peer_id]

    def has_peer_key(self, peer_id: str) -> bool:
        """Check if peer has specific key"""
        return peer_id in self._peer_keys

    def peer_count(self) -> int:
        """Get number of peers with specific keys"""
        return len(self._peer_keys)
