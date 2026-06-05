"""Tests for key store."""

import pytest
import os
from yx.transport.key_store import KeyStore


def test_key_store_get_default():
    """Test key store returns default key for unknown peer."""
    default_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    key = ks.get_key("unknown_peer")

    assert key == default_key


def test_key_store_get_peer_specific():
    """Test key store returns peer-specific key."""
    default_key = os.urandom(32)
    peer_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    ks.set_key("peer1", peer_key)
    key = ks.get_key("peer1")

    assert key == peer_key
    assert key != default_key


def test_key_store_invalid_key_size():
    """Test key store rejects invalid key sizes."""
    default_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    with pytest.raises(ValueError):
        ks.set_key("peer1", b"short_key")


def test_key_store_remove_key():
    """Test key store removes peer key."""
    default_key = os.urandom(32)
    peer_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    ks.set_key("peer1", peer_key)
    assert ks.has_peer_key("peer1")

    ks.remove_key("peer1")
    assert not ks.has_peer_key("peer1")

    assert ks.get_key("peer1") == default_key


def test_key_store_peer_count():
    """Test key store peer count."""
    default_key = os.urandom(32)
    ks = KeyStore(default_key=default_key)

    assert ks.peer_count() == 0

    ks.set_key("peer1", os.urandom(32))
    ks.set_key("peer2", os.urandom(32))

    assert ks.peer_count() == 2
