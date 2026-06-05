"""Tests for AES-256-GCM encryption (Protocol 1)."""

import os
import pytest
from yx.primitives.data_crypto import encrypt_aes_gcm, decrypt_aes_gcm


def test_aes_gcm_encrypt_decrypt_roundtrip():
    """Test AES-256-GCM encryption/decryption roundtrip."""
    key = os.urandom(32)
    plaintext = b"Secret message!"

    nonce, ciphertext_with_tag = encrypt_aes_gcm(plaintext, key)
    decrypted = decrypt_aes_gcm(nonce, ciphertext_with_tag, key)

    assert decrypted == plaintext
    assert len(nonce) == 12
    assert len(ciphertext_with_tag) == len(plaintext) + 16  # +16 for tag


def test_aes_gcm_different_nonces():
    """Test that same plaintext produces different ciphertexts."""
    key = os.urandom(32)
    plaintext = b"Secret message!"

    nonce1, ciphertext1 = encrypt_aes_gcm(plaintext, key)
    nonce2, ciphertext2 = encrypt_aes_gcm(plaintext, key)

    assert nonce1 != nonce2
    assert ciphertext1 != ciphertext2


def test_aes_gcm_invalid_key_size():
    """Test that invalid key size raises error."""
    with pytest.raises(ValueError):
        encrypt_aes_gcm(b"data", b"short_key")
