"""Tests for data chunking."""

import pytest
from yx.primitives.data_chunking import chunk_data, unchunk_data


def test_chunk_unchunk_roundtrip():
    """Test chunking/unchunking roundtrip."""
    original = b"A" * 5000
    chunks = chunk_data(original, chunk_size=1024)
    reassembled = unchunk_data(chunks)

    assert reassembled == original
    assert len(chunks) == 5  # 5000 bytes / 1024 = 5 chunks


def test_chunk_small_data():
    """Test chunking data smaller than chunk size."""
    data = b"Small"
    chunks = chunk_data(data, chunk_size=1024)

    assert len(chunks) == 1
    assert chunks[0] == data


def test_chunk_empty_data():
    """Test chunking empty data."""
    chunks = chunk_data(b"", chunk_size=1024)

    assert len(chunks) == 1
    assert chunks[0] == b""


def test_chunk_exact_multiple():
    """Test chunking data that's exact multiple of chunk size."""
    data = b"X" * 2048
    chunks = chunk_data(data, chunk_size=1024)

    assert len(chunks) == 2
    assert len(chunks[0]) == 1024
    assert len(chunks[1]) == 1024
