"""Tests for key store."""

import pytest
import os
from yx.transport.key_store import KeyStore


def test_default_key():
    default = os.urandom(32)
    ks = KeyStore(default_key=default)
    assert ks.get_key("unknown") == default


def test_peer_specific_key():
    default = os.urandom(32)
    peer_key = os.urandom(32)
    ks = KeyStore(default_key=default)
    ks.set_key("peer1", peer_key)
    assert ks.get_key("peer1") == peer_key
    assert ks.get_key("peer1") != default


def test_invalid_key_size():
    ks = KeyStore(default_key=os.urandom(32))
    with pytest.raises(ValueError):
        ks.set_key("peer1", b"short")


def test_remove_key():
    default = os.urandom(32)
    ks = KeyStore(default_key=default)
    ks.set_key("peer1", os.urandom(32))
    assert ks.has_peer_key("peer1")
    ks.remove_key("peer1")
    assert not ks.has_peer_key("peer1")
    assert ks.get_key("peer1") == default


def test_peer_count():
    ks = KeyStore(default_key=os.urandom(32))
    assert ks.peer_count() == 0
    ks.set_key("p1", os.urandom(32))
    ks.set_key("p2", os.urandom(32))
    assert ks.peer_count() == 2
