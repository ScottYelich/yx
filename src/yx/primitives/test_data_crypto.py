import os as _os
from yx.primitives.data_crypto import encrypt_aes_gcm, decrypt_aes_gcm


def test_aes_gcm_roundtrip():
    key = _os.urandom(32)
    plaintext = b"Secret message!"
    nonce, ciphertext = encrypt_aes_gcm(plaintext, key)
    assert decrypt_aes_gcm(nonce, ciphertext, key) == plaintext
    assert len(nonce) == 12
    assert len(ciphertext) == len(plaintext) + 16


def test_aes_gcm_different_nonces():
    key = _os.urandom(32)
    plaintext = b"Secret message!"
    nonce1, ct1 = encrypt_aes_gcm(plaintext, key)
    nonce2, ct2 = encrypt_aes_gcm(plaintext, key)
    assert nonce1 != nonce2
    assert ct1 != ct2


def test_aes_gcm_invalid_key():
    import pytest
    with pytest.raises(ValueError):
        encrypt_aes_gcm(b"data", b"short")
