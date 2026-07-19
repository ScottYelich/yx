"""Tests for data chunking."""

import pytest
from yx.primitives.data_chunking import chunk_data, unchunk_data


def test_chunk_unchunk_roundtrip():
    original = b"A" * 5000
    chunks = chunk_data(original, chunk_size=1024)
    assert unchunk_data(chunks) == original
    assert len(chunks) == 5


def test_chunk_small_data():
    data = b"Small"
    chunks = chunk_data(data, chunk_size=1024)
    assert len(chunks) == 1
    assert chunks[0] == data


def test_chunk_empty_data():
    chunks = chunk_data(b"", chunk_size=1024)
    assert len(chunks) == 1
    assert chunks[0] == b""


def test_chunk_exact_multiple():
    data = b"X" * 2048
    chunks = chunk_data(data, chunk_size=1024)
    assert len(chunks) == 2
