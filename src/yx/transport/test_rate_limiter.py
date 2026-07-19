"""Tests for rate limiter."""

import pytest
import time
from yx.transport.rate_limiter import RateLimiter


def test_default_is_10000():
   """CRITICAL: default must be 10,000 not 100."""
   rl = RateLimiter()
   assert rl.max_requests == 10000
   assert rl.window_seconds == 60.0


def test_allows_under_limit():
   rl = RateLimiter(max_requests=10)
   for _ in range(10):
     assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is True


def test_blocks_over_limit():
   rl = RateLimiter(max_requests=10)
   for _ in range(10):
     rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
   assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False


def test_sliding_window():
   rl = RateLimiter(max_requests=5, window_seconds=0.2)
   for _ in range(5):
     rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
   assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False
   time.sleep(0.25)
   assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is True


def test_per_peer_isolation():
   rl = RateLimiter(max_requests=5)
   for _ in range(5):
     rl.check_rate_limit("peer1", ("127.0.0.1", 12345))
   assert rl.check_rate_limit("peer1", ("127.0.0.1", 12345)) is False
   assert rl.check_rate_limit("peer2", ("127.0.0.1", 12346)) is True


def test_trusted_bypass():
   rl = RateLimiter(max_requests=5)
   rl.add_trusted_guid("E32E3CA702DE")
   for _ in range(100):
     assert rl.check_rate_limit("E32E3CA702DE", ("127.0.0.1", 12345)) is True
