"""Tests for replay protection."""

import pytest
import time
from yx.transport.replay_protection import ReplayProtection


def test_allows_new_nonce():
    rp = ReplayProtection()
    assert rp.check_and_record(b"nonce" * 3 + b"x") is True


def test_blocks_duplicate():
    rp = ReplayProtection()
    nonce = b"nonce1234567890a"
    rp.check_and_record(nonce)
    assert rp.check_and_record(nonce) is False


def test_expires_old_nonces():
    rp = ReplayProtection(max_age=0.05)
    nonce = b"nonce1234567890a"
    rp.check_and_record(nonce)
    time.sleep(0.1)
    for i in range(100):
        rp.check_and_record(f"n{i:015d}".encode())
    assert rp.check_and_record(nonce) is True


def test_count():
    rp = ReplayProtection()
    assert rp.count == 0
    rp.check_and_record(b"nonce1234567890a")
    rp.check_and_record(b"nonce1234567890b")
    assert rp.count == 2


def test_clear():
    rp = ReplayProtection()
    rp.check_and_record(b"nonce1234567890a")
    rp.clear()
    assert rp.count == 0
