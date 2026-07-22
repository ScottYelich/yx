"""
Rate limiter for DoS protection

Implements sliding window rate limiting per peer.
"""

import time
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field


@dataclass
class RateLimiter:
    """Sliding window rate limiter matching Swift implementation"""

    max_requests: int = 10000  # Max requests per window (increased for high-frequency trading)
    window_seconds: float = 60.0  # Window size in seconds

    # Trusted service GUIDs that bypass rate limiting (for high-frequency trading services)
    # GUIDs are hex strings (e.g., "E32E3CA702DE" for ib-bridge)
    # Add known service GUIDs here to exempt them from rate limiting
    trusted_guids: set = field(default_factory=set)

    # Per-peer request timestamps
    _peer_requests: Dict[str, List[float]] = field(default_factory=dict)

    def check_rate_limit(self, peer_id: str, source_addr: Optional[Tuple[str, int]] = None) -> bool:
        """
        Check if peer is within rate limit.

        Args:
            peer_id: Peer identifier (GUID hex string, e.g., "E32E3CA702DE")
            source_addr: Optional source address tuple (host, port) - not used for trust, only for logging

        Returns:
            bool: True if request allowed, False if rate limited
        """
        # First priority: Check if this is a trusted service by GUID
        # This is the secure way to trust specific known services (ib-bridge, service-manager, etc.)
        # GUIDs cannot be spoofed without the shared key, making this cryptographically secure
        if peer_id in self.trusted_guids:
            return True  # Bypass rate limiting for trusted services

        now = time.time()

        # Get peer's request history
        if peer_id not in self._peer_requests:
            self._peer_requests[peer_id] = []

        requests = self._peer_requests[peer_id]

        # Remove requests outside the window
        cutoff = now - self.window_seconds
        requests = [ts for ts in requests if ts > cutoff]
        self._peer_requests[peer_id] = requests

        # Check if under limit
        if len(requests) >= self.max_requests:
            return False

        # Add current request
        requests.append(now)
        return True

    def reset_peer(self, peer_id: str):
        """Reset rate limit for a peer"""
        if peer_id in self._peer_requests:
            del self._peer_requests[peer_id]

    def cleanup_old_entries(self):
        """Remove expired entries from all peers"""
        now = time.time()
        cutoff = now - self.window_seconds

        for peer_id in list(self._peer_requests.keys()):
            requests = self._peer_requests[peer_id]
            requests = [ts for ts in requests if ts > cutoff]

            if not requests:
                del self._peer_requests[peer_id]
            else:
                self._peer_requests[peer_id] = requests

    def add_trusted_guid(self, guid_hex: str) -> None:
        """
        Add a GUID to the trusted services list.

        Trusted services bypass rate limiting. This is appropriate for known
        high-frequency trading services (ib-bridge, service-manager, etc.)
        that need to send hundreds of packets per second.

        Args:
            guid_hex: GUID as hex string (e.g., "E32E3CA702DE")
        """
        self.trusted_guids.add(guid_hex)

    def remove_trusted_guid(self, guid_hex: str) -> None:
        """
        Remove a GUID from the trusted services list.

        Args:
            guid_hex: GUID as hex string
        """
        self.trusted_guids.discard(guid_hex)

    def is_trusted(self, guid_hex: str) -> bool:
        """
        Check if a GUID is trusted.

        Args:
            guid_hex: GUID as hex string

        Returns:
            bool: True if trusted, False otherwise
        """
        return guid_hex in self.trusted_guids
