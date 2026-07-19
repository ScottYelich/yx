"""
Cryptographic utilities for HMAC and AES-GCM encryption

Implements HMAC-SHA256 and AES-GCM matching the Swift implementation.
"""

import os
from typing import Tuple
from cryptography.hazmat.primitives import hashes, hmac
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def generate_key(size_bits: int = 256) -> bytes:
    """
    Generate a random symmetric key.

    Args:
        size_bits: Key size in bits (default: 256)

    Returns:
        bytes: Random key of specified size
    """
    return os.urandom(size_bits // 8)


def compute_hmac(data: bytes, key: bytes, truncate_to: int = 16) -> bytes:
    """
    Compute HMAC-SHA256 of data.

    Args:
        data: Data to HMAC
        key: Symmetric key for HMAC
        truncate_to: Number of bytes to return (default: 16, matching Swift)

    Returns:
        bytes: HMAC truncated to specified length
    """
    h = hmac.HMAC(key, hashes.SHA256())
    h.update(data)
    mac = h.finalize()
    return mac[:truncate_to]


def encrypt_aes_gcm(plaintext: bytes, key: bytes) -> Tuple[bytes, bytes]:
    """
    Encrypt data using AES-GCM.

    Args:
        plaintext: Data to encrypt
        key: 32-byte symmetric key

    Returns:
        Tuple[bytes, bytes]: (nonce, ciphertext_with_tag)
            - nonce: 12-byte random nonce
            - ciphertext_with_tag: Encrypted data + 16-byte authentication tag
    """
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)  # 96-bit nonce for GCM
    ciphertext = aesgcm.encrypt(nonce, plaintext, None)
    return nonce, ciphertext


def decrypt_aes_gcm(nonce: bytes, ciphertext_with_tag: bytes, key: bytes) -> bytes:
    """
    Decrypt AES-GCM encrypted data.

    Args:
        nonce: 12-byte nonce used during encryption
        ciphertext_with_tag: Encrypted data with authentication tag
        key: 32-byte symmetric key

    Returns:
        bytes: Decrypted plaintext

    Raises:
        cryptography.exceptions.InvalidTag: If authentication fails
    """
    aesgcm = AESGCM(key)
    plaintext = aesgcm.decrypt(nonce, ciphertext_with_tag, None)
    return plaintext
