"""Ed25519 message signing — ADR D12 / signing.md §1.

Python mirror of Sources/Primitives/Signer.swift.

Private keys live in the macOS Keychain (generic password, service
`org.spy.yx.sig`, account = <agent-id>, value = base64 of the 32-byte seed).
Mirrors the MeshKey `security`-subprocess pattern so the Swift and Python
implementations share the exact same store/format. Public key = base64 of
the 32 raw bytes; signatures are "ed25519:<base64 64-byte sig>".

NOTE: `cryptography`'s Ed25519 signing is deterministic (RFC 8032); CryptoKit's
is randomized. Both verify each other — the cross-language contract is VERIFY,
not signature byte-equality (see tests/fixtures/sign-vector.sxp).
"""

from __future__ import annotations

import base64
import subprocess
from typing import List, Optional

from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from cryptography.exceptions import InvalidSignature

SERVICE = "org.spy.yx.sig"
SIG_PREFIX = "ed25519:"


# MARK: - Key management (Keychain-backed)

def generate(agent_id: str) -> Optional[str]:
    """Generate a keypair for `agent_id`, store the private seed in the
    Keychain, and return the public key (base64, 32 raw bytes)."""
    key = Ed25519PrivateKey.generate()
    seed_b64 = base64.b64encode(key.private_bytes_raw()).decode("ascii")
    if not keychain_set(agent_id, seed_b64):
        return None
    return base64.b64encode(key.public_key().public_bytes_raw()).decode("ascii")


def public_key(agent_id: str) -> Optional[str]:
    """The stored public key for `agent_id` (base64), or None if absent."""
    key = _private_key_for_agent(agent_id)
    if key is None:
        return None
    return base64.b64encode(key.public_key().public_bytes_raw()).decode("ascii")


def public_key_from_seed(seed_b64: str) -> Optional[str]:
    """Public key (base64) derived from an explicit seed — tests/fixtures."""
    key = _private_key_from_seed(seed_b64)
    if key is None:
        return None
    return base64.b64encode(key.public_key().public_bytes_raw()).decode("ascii")


def list_ids() -> List[str]:
    """Agent-ids with signing keys present in the Keychain (sorted)."""
    dump = _run_security(["dump-keychain"])
    if dump is None:
        return []

    # Attributes are alphabetical, so "acct" precedes "svce" within an item.
    def quoted(line: str) -> Optional[str]:
        idx = line.rfind('="')
        if idx < 0 or not line.endswith('"'):
            return None
        return line[idx + 2:-1]

    ids = set()
    pending_acct: Optional[str] = None
    for line in dump.split("\n"):
        if '"acct"<blob>=' in line:
            pending_acct = quoted(line)
        if f'"svce"<blob>="{SERVICE}"' in line and pending_acct is not None:
            ids.add(pending_acct)
    return sorted(ids)


def remove(agent_id: str) -> bool:
    """Delete the signing key for `agent_id`."""
    return _run_security(["delete-generic-password", "-s", SERVICE, "-a", agent_id]) is not None


# MARK: - Sign / verify

def sign(data: bytes, agent_id: Optional[str] = None,
         seed_b64: Optional[str] = None) -> Optional[str]:
    """Sign `data` -> "ed25519:<base64 64-byte sig>".

    Pass `agent_id` to use the Keychain key, or `seed_b64` for an explicit
    32-byte seed (tests/fixtures)."""
    if seed_b64 is not None:
        key = _private_key_from_seed(seed_b64)
    elif agent_id is not None:
        key = _private_key_for_agent(agent_id)
    else:
        key = None
    if key is None:
        return None
    return SIG_PREFIX + base64.b64encode(key.sign(data)).decode("ascii")


def verify(data: bytes, sig: str, pubkey_b64: str) -> bool:
    """Verify an "ed25519:<base64>" signature over `data` with a base64 pubkey."""
    if not sig.startswith(SIG_PREFIX):
        return False
    sig_data = _b64decode(sig[len(SIG_PREFIX):])
    if sig_data is None or len(sig_data) != 64:
        return False
    pub_data = _b64decode(pubkey_b64)
    if pub_data is None or len(pub_data) != 32:
        return False
    try:
        pub = Ed25519PublicKey.from_public_bytes(pub_data)
        pub.verify(sig_data, data)
        return True
    except (InvalidSignature, ValueError):
        return False


# MARK: - Internals

def _b64decode(s: str) -> Optional[bytes]:
    try:
        return base64.b64decode(s, validate=True)
    except Exception:
        return None


def _private_key_from_seed(seed_b64: str) -> Optional[Ed25519PrivateKey]:
    seed = _b64decode(seed_b64)
    if seed is None or len(seed) != 32:
        return None
    try:
        return Ed25519PrivateKey.from_private_bytes(seed)
    except Exception:
        return None


def _private_key_for_agent(agent_id: str) -> Optional[Ed25519PrivateKey]:
    b64 = keychain_get(agent_id)
    if b64 is None:
        return None
    return _private_key_from_seed(b64)


# MARK: - Keychain (generic password via `security`, mirroring MeshKey)

def keychain_get(agent_id: str) -> Optional[str]:
    out = _run_security(["find-generic-password", "-s", SERVICE, "-a", agent_id, "-w"])
    if out is None:
        return None
    b64 = out.strip()
    return b64 if b64 else None


def keychain_set(agent_id: str, seed_b64: str) -> bool:
    # -U upserts (update if present)
    return _run_security(["add-generic-password", "-s", SERVICE, "-a", agent_id,
                          "-w", seed_b64, "-U", "-l", f"yx-sig-{agent_id}"]) is not None


def _run_security(args: List[str]) -> Optional[str]:
    try:
        r = subprocess.run(["/usr/bin/security"] + args,
                           capture_output=True, text=True, timeout=10)
    except Exception:
        return None
    if r.returncode != 0:
        return None
    return r.stdout
