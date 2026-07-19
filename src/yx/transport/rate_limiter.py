"""
Rate limiting using sliding window per peer.

Traceability:
- protocol/specs/architecture/security-architecture.md (Layer 3: Rate Limiting)
- protocol/specs/technical/default-values.md (max_requests = 10,000 NOT 100!)
- SDTS Issue #2: Rate limiter default mismatch (was 100, must be 10,000)
"""

import time
from dataclasses import dataclass, field
from typing import Dict, List, Set
import logging

logger = logging.getLogger(__name__)


@dataclass
class RateLimiter:
    """
    Per-peer rate limiter with sliding window.

    CRITICAL: max_requests = 10,000 (for high-frequency trading support).
    See SDTS Issue #2 for consequences of wrong default.

    Traceability:
    - protocol/specs/architecture/security-architecture.md (Rate Limiting)
    - protocol/specs/technical/default-values.md (max_requests, rate_limit_window)
    """
    max_requests: int = 10000  # CRITICAL: 10,000 NOT 100
    window_seconds: float = 60.0
    trusted_guids: Set[str] = field(default_factory=set)
    _history: Dict[str, List[float]] = field(default_factory=dict)

    def check_rate_limit(self, peer_id: str, source_addr: tuple) -> bool:
        """
        Check if peer is within rate limit.

        Returns:
            True = allowed
            False = blocked (exceeded limit)
        """
        if peer_id in self.trusted_guids:
            return True

        now = time.time()
        if peer_id not in self._history:
            self._history[peer_id] = []

        history = self._history[peer_id]
        cutoff = now - self.window_seconds
        history[:] = [t for t in history if t > cutoff]

        if len(history) >= self.max_requests:
            logger.warning(f"Rate limit exceeded for {peer_id} from {source_addr}")
            return False

        history.append(now)
        return True

    def add_trusted_guid(self, guid_hex: str):
        self.trusted_guids.add(guid_hex.upper())

    def remove_trusted_guid(self, guid_hex: str):
        self.trusted_guids.discard(guid_hex.upper())

    def is_trusted(self, guid_hex: str) -> bool:
        return guid_hex.upper() in self.trusted_guids

    def reset_peer(self, peer_id: str):
        self._history.pop(peer_id, None)
