"""
Tests for the sdts-ported transport hardening:
- ReplayProtection (nonce cache, ported from sdts scott branch)
- RateLimiter GUID trust (high-frequency trading services bypass, sdts 644b643/8692705)
"""

import time

from yx.transport.replay_protection import ReplayProtection
from yx.transport.rate_limiter import RateLimiter


class TestReplayProtection:
    def test_new_nonce_allowed(self):
        rp = ReplayProtection()
        assert rp.check_and_record(b"\x01" * 16) is True

    def test_repeat_nonce_rejected(self):
        rp = ReplayProtection()
        nonce = b"\x02" * 16
        assert rp.check_and_record(nonce) is True
        assert rp.check_and_record(nonce) is False  # replay

    def test_distinct_nonces_independent(self):
        rp = ReplayProtection()
        assert rp.check_and_record(b"\x03" * 16) is True
        assert rp.check_and_record(b"\x04" * 16) is True

    def test_expiry_allows_old_nonce_again(self):
        rp = ReplayProtection(max_age=0.05)
        nonce = b"\x05" * 16
        assert rp.check_and_record(nonce) is True
        time.sleep(0.06)
        assert rp.check_and_record(nonce) is True  # expired, treated as new

    def test_count_and_clear(self):
        rp = ReplayProtection()
        rp.record(b"\x06" * 16)
        rp.record(b"\x07" * 16)
        assert rp.count == 2
        rp.clear()
        assert rp.count == 0


class TestRateLimiterTrust:
    def test_trusted_guid_bypasses_limit(self):
        rl = RateLimiter(max_requests=3, window_seconds=60.0)
        rl.add_trusted_guid("E32E3CA702DE")
        for _ in range(50):
            assert rl.check_rate_limit("E32E3CA702DE") is True

    def test_untrusted_guid_is_limited(self):
        rl = RateLimiter(max_requests=3, window_seconds=60.0)
        for _ in range(3):
            assert rl.check_rate_limit("AAAAAAAAAAAA") is True
        assert rl.check_rate_limit("AAAAAAAAAAAA") is False

    def test_remove_trusted_guid(self):
        rl = RateLimiter(max_requests=1, window_seconds=60.0)
        rl.add_trusted_guid("BBBBBBBBBBBB")
        assert rl.is_trusted("BBBBBBBBBBBB") is True
        rl.remove_trusted_guid("BBBBBBBBBBBB")
        assert rl.is_trusted("BBBBBBBBBBBB") is False
        assert rl.check_rate_limit("BBBBBBBBBBBB") is True
        assert rl.check_rate_limit("BBBBBBBBBBBB") is False  # limited again

    def test_source_addr_param_accepted(self):
        rl = RateLimiter(max_requests=5, window_seconds=60.0)
        assert rl.check_rate_limit("CCCCCCCCCCCC", source_addr=("127.0.0.1", 50000)) is True
