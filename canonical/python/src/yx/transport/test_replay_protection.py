"""
Tests for replay protection.

Traceability:
- specs/architecture/security-architecture.md (Replay Protection Tests)
"""

import pytest
import time
from yx.transport.replay_protection import ReplayProtection


def test_replay_protection_allows_new_nonce():
    """Test replay protection allows new nonces."""
    rp = ReplayProtection()
    nonce = b"nonce1234567890a"

    result = rp.check_and_record(nonce)

    assert result is True  # Allowed


def test_replay_protection_blocks_duplicate():
    """Test replay protection blocks duplicate nonces."""
    rp = ReplayProtection()
    nonce = b"nonce1234567890a"

    rp.check_and_record(nonce)  # First time: allowed
    result = rp.check_and_record(nonce)  # Second time: blocked

    assert result is False  # BLOCKED (replay)


def test_replay_protection_expires_old_nonces():
    """Test replay protection expires old nonces."""
    rp = ReplayProtection(max_age=0.1)  # 100ms expiry
    nonce = b"nonce1234567890a"

    rp.check_and_record(nonce)
    time.sleep(0.15)  # Wait for expiry

    # Trigger cleanup by adding 100 nonces
    for i in range(100):
        rp.check_and_record(f"nonce{i:016d}".encode())

    # Original nonce should be expired now
    result = rp.check_and_record(nonce)
    assert result is True  # Allowed (expired)


def test_replay_protection_count():
    """Test replay protection nonce count."""
    rp = ReplayProtection()

    assert rp.count == 0

    rp.check_and_record(b"nonce1234567890a")
    rp.check_and_record(b"nonce1234567890b")

    assert rp.count == 2


def test_replay_protection_clear():
    """Test replay protection clear."""
    rp = ReplayProtection()

    rp.check_and_record(b"nonce1234567890a")
    assert rp.count == 1

    rp.clear()
    assert rp.count == 0
