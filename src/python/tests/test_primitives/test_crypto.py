"""Test cryptographic functions"""

from yx.primitives.data_crypto import generate_key, compute_hmac, encrypt_aes_gcm, decrypt_aes_gcm


def test_key_generation():
    """Test symmetric key generation"""
    key = generate_key(256)
    assert len(key) == 32  # 256 bits = 32 bytes


def test_hmac_computation():
    """Test HMAC-SHA256 computation"""
    data = b"test data"
    key = generate_key()
    hmac = compute_hmac(data, key, truncate_to=16)
    assert len(hmac) == 16


def test_hmac_deterministic():
    """Test HMAC is deterministic"""
    data = b"test data"
    key = generate_key()
    hmac1 = compute_hmac(data, key)
    hmac2 = compute_hmac(data, key)
    assert hmac1 == hmac2


def test_hmac_different_keys():
    """Test HMAC differs with different keys"""
    data = b"test data"
    key1 = generate_key()
    key2 = generate_key()
    hmac1 = compute_hmac(data, key1)
    hmac2 = compute_hmac(data, key2)
    assert hmac1 != hmac2


def test_aes_gcm_encryption():
    """Test AES-GCM encryption"""
    plaintext = b"secret message"
    key = generate_key()
    nonce, ciphertext = encrypt_aes_gcm(plaintext, key)

    assert len(nonce) == 12  # GCM nonce is 12 bytes
    assert len(ciphertext) > len(plaintext)  # Includes auth tag


def test_aes_gcm_decryption():
    """Test AES-GCM decryption"""
    plaintext = b"secret message"
    key = generate_key()

    nonce, ciphertext = encrypt_aes_gcm(plaintext, key)
    decrypted = decrypt_aes_gcm(nonce, ciphertext, key)

    assert decrypted == plaintext


def test_aes_gcm_round_trip():
    """Test AES-GCM encryption/decryption round trip"""
    original = b"This is a longer test message with more content"
    key = generate_key()

    nonce, ciphertext = encrypt_aes_gcm(original, key)
    decrypted = decrypt_aes_gcm(nonce, ciphertext, key)

    assert decrypted == original
