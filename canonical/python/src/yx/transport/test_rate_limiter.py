"""
Tests for rate limiter.

Traceability:
- specs/architecture/security-architecture.md (Rate Limiting Tests)
"""

import pytest
import time
from yx.transport.rate_limiter import RateLimiter


def test_rate_limiter_allows_under_limit():
    """Test rate limiter allows requests under limit."""
    rl = RateLimiter(max_requests=10, window_seconds=60.0)

    for i in range(10):
        result = rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
        assert result is True


def test_rate_limiter_blocks_over_limit():
    """Test rate limiter blocks requests over limit."""
    rl = RateLimiter(max_requests=10, window_seconds=60.0)

    for i in range(10):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))

    result = rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
    assert result is False  # BLOCKED


def test_rate_limiter_sliding_window():
    """Test rate limiter uses sliding window."""
    rl = RateLimiter(max_requests=5, window_seconds=0.2)  # 5 req / 200ms

    for i in range(5):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))

    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False

    time.sleep(0.25)

    result = rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
    assert result is True


def test_rate_limiter_per_peer_isolation():
    """Test rate limiter isolates peers."""
    rl = RateLimiter(max_requests=5, window_seconds=60.0)

    for i in range(5):
        rl.check_rate_limit("peer1", ("127.0.0.1", 12345))

    assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False
    assert rl.check_rate_limit("peer2", ("127.0.0.1", 12346)) is True


def test_rate_limiter_trusted_guid_bypass():
    """Test trusted GUIDs bypass rate limiting."""
    rl = RateLimiter(max_requests=5, window_seconds=60.0)
    rl.add_trusted_guid("E32E3CA702DE")

    for i in range(100):
        result = rl.check_rate_limit("E32E3CA702DE", ("127.0.0.1", 12345))
        assert result is True  # All allowed (trusted)


def test_rate_limiter_default_is_10000():
    """Test rate limiter default is 10,000 (not 100)."""
    rl = RateLimiter()

    # CRITICAL: Must be 10,000 for high-frequency trading (SDTS Issue #2)
    assert rl.max_requests == 10000
    assert rl.window_seconds == 60.0
