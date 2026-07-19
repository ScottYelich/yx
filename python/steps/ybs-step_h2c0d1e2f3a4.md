# YBS Step: AES-256-GCM Encryption (extend data_crypto.py)

**Step ID:** `ybs-step_h2c0d1e2f3a4`
**Language:** Python
**Prerequisites:** Step h2b complete (data_chunking.py exists)

---

## ⚠️ CRITICAL: Do NOT use canonical/ as proof of completion

The `canonical/` directory contains reference files. **DO NOT** look at `canonical/` to confirm work is done.
Verify ONLY by:
1. The functions `encrypt_aes_gcm` and `decrypt_aes_gcm` exist in `{{CONFIG:impl_src}}/primitives/data_crypto.py`
2. Tests pass when running pytest

Your target directory is `{{CONFIG:impl_src}}` (resolves to `src/yx`).

---

## What This Step Builds

**Extend** `{{CONFIG:impl_src}}/primitives/data_crypto.py` — add AES-256-GCM encrypt/decrypt functions.

The file already exists with HMAC functions. **ADD** these new functions to the bottom of the existing file. Do NOT replace the existing content.

---

## Add to bottom of `{{CONFIG:impl_src}}/primitives/data_crypto.py`

```python
import os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from typing import Tuple


def encrypt_aes_gcm(plaintext: bytes, key: bytes) -> Tuple[bytes, bytes]:
    """
    Encrypt data using AES-256-GCM.

    Args:
        plaintext: Data to encrypt
        key: 32-byte symmetric key

    Returns:
        (nonce, ciphertext_with_tag)
        - nonce: 12 bytes random
        - ciphertext_with_tag: encrypted data + 16-byte auth tag

    Wire format: [nonce(12)] + [ciphertext] + [tag(16)]

    Traceability:
    - protocol/specs/architecture/security-architecture.md (AES-256-GCM)
    - protocol/specs/technical/yx-protocol-spec.md (Encryption Wire Format)
    """
    if len(key) != 32:
        raise ValueError(f"Key must be 32 bytes, got {len(key)}")

    aesgcm = AESGCM(key)
    nonce = os.urandom(12)
    ciphertext_with_tag = aesgcm.encrypt(nonce, plaintext, None)
    return nonce, ciphertext_with_tag


def decrypt_aes_gcm(nonce: bytes, ciphertext_with_tag: bytes, key: bytes) -> bytes:
    """
    Decrypt AES-256-GCM data.

    Args:
        nonce: 12-byte nonce
        ciphertext_with_tag: Ciphertext + 16-byte auth tag
        key: 32-byte symmetric key

    Returns:
        Decrypted plaintext

    Raises:
        cryptography.exceptions.InvalidTag: If authentication fails

    Traceability:
    - protocol/specs/architecture/security-architecture.md (Decryption)
    """
    if len(key) != 32:
        raise ValueError(f"Key must be 32 bytes, got {len(key)}")
    if len(nonce) != 12:
        raise ValueError(f"Nonce must be 12 bytes, got {len(nonce)}")

    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext_with_tag, None)
```

---

## Tests

**Add** these tests to `{{CONFIG:impl_src}}/primitives/test_data_crypto.py` (existing file — APPEND, do not replace):

```python
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
```

---

## Verification

```bash
pytest {{CONFIG:impl_src}}/primitives/test_data_crypto.py -v -k "aes_gcm"
```

All 3 AES-GCM tests must pass.

---

## Documentation

Create `docs/build-history/{{CONFIG:build_name}}-step_h2c0d1e2f3a4-DONE.txt`:

```
STEP: ybs-step_h2c0d1e2f3a4
COMPLETED: [ISO 8601 timestamp]
FILES: src/yx/primitives/data_crypto.py (extended), test_data_crypto.py (extended)
VERIFICATION: PASSED
NEXT: ybs-step_h2d0e1f2a3b4
```

Update `BUILD_STATUS.md`: add `- [x] h2c0d1e2f3a4`.
