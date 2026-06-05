"""
Rate limiting using sliding window per peer.

Traceability:
- specs/architecture/security-architecture.md (Layer 3: Rate Limiting)
- specs/technical/default-values.md (max_requests = 10,000)
- SDTS Issue #2: Rate limiter default mismatch (100 vs 10,000)
"""

import time
from dataclasses import dataclass, field
from typing import Dict, List, Set
import logging

logger = logging.getLogger(__name__)


@dataclass
class RateLimiter:
    """
    Rate limiter using sliding window per peer.

    Traceability:
    - specs/architecture/security-architecture.md (Rate Limiting)
    - specs/technical/default-values.md (max_requests, rate_limit_window)

    CRITICAL: max_requests MUST be 10,000 (not 100!)
    This is for high-frequency trading support.
    See SDTS Issue #2 for consequences of wrong default.
    """
    max_requests: int = 10000  # CRITICAL: 10,000 for HFT, NOT 100!
    window_seconds: float = 60.0
    trusted_guids: Set[str] = field(default_factory=set)
    _request_history: Dict[str, List[float]] = field(default_factory=dict)

    def check_rate_limit(self, peer_id: str, source_addr: tuple) -> bool:
        """
        Check if peer is under rate limit.

        Returns:
            True: Allowed
            False: Blocked (rate limit exceeded)
        """
        # Check trusted GUID whitelist first
        if peer_id in self.trusted_guids:
            return True  # BYPASS rate limiting

        now = time.time()

        if peer_id not in self._request_history:
            self._request_history[peer_id] = []

        history = self._request_history[peer_id]

        # Remove requests outside window (sliding window)
        cutoff = now - self.window_seconds
        history[:] = [t for t in history if t > cutoff]

        # Check if over limit
        if len(history) >= self.max_requests:
            logger.warning(
                f"Rate limit exceeded for {peer_id} from {source_addr}: "
                f"{len(history)} requests in {self.window_seconds}s"
            )
            return False  # REJECT

        history.append(now)
        return True  # ALLOW

    def add_trusted_guid(self, guid_hex: str):
        """Add GUID to trusted whitelist (bypass rate limiting)."""
        self.trusted_guids.add(guid_hex.upper())
        logger.info(f"Added trusted GUID: {guid_hex}")

    def remove_trusted_guid(self, guid_hex: str):
        """Remove GUID from trusted whitelist."""
        self.trusted_guids.discard(guid_hex.upper())

    def is_trusted(self, guid_hex: str) -> bool:
        """Check if GUID is trusted."""
        return guid_hex.upper() in self.trusted_guids

    def reset_peer(self, peer_id: str):
        """Reset rate limit history for peer."""
        if peer_id in self._request_history:
            del self._request_history[peer_id]
