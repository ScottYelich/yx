"""
Rate limiter for DoS protection

Implements sliding window rate limiting per peer.
"""

import time
from typing import Dict, List
from dataclasses import dataclass, field


@dataclass
class RateLimiter:
    """Sliding window rate limiter matching Swift implementation"""

    max_requests: int = 10000  # Max requests per window (increased for high-frequency trading)
    window_seconds: float = 60.0  # Window size in seconds

    # Per-peer request timestamps
    _peer_requests: Dict[str, List[float]] = field(default_factory=dict)

    def check_rate_limit(self, peer_id: str) -> bool:
        """
        Check if peer is within rate limit.

        Args:
            peer_id: Peer identifier (usually GUID hex)

        Returns:
            bool: True if request allowed, False if rate limited
        """
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
