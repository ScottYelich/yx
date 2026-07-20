"""Mesh key resolution mirroring Swift MeshKey (ADR D08 / key-management.md).

Order: explicit hex > YX_KEY env > Keychain(security) > dev key (warns).
"""
import hashlib, os, subprocess, sys

SERVICE = "org.spy.yx"
DEFAULT_MESH = "mesh"
_DEV = hashlib.sha256(b"shared-secret").digest()  # == D3046ECC...


def _decode(hexstr):
    s = (hexstr or "").strip()
    if len(s) != 64:
        return None
    try:
        return bytes.fromhex(s)
    except ValueError:
        return None


def keychain_get(mesh=DEFAULT_MESH):
    try:
        r = subprocess.run(["security", "find-generic-password", "-s", SERVICE,
                            "-a", mesh, "-w"], capture_output=True, text=True, timeout=3)
        return _decode(r.stdout) if r.returncode == 0 else None
    except Exception:
        return None


def resolve_key(explicit_hex=None, mesh=DEFAULT_MESH):
    """Return (key_bytes, source)."""
    d = _decode(explicit_hex)
    if d:
        return d, "explicit"
    d = _decode(os.environ.get("YX_KEY"))
    if d:
        return d, "environment"
    d = keychain_get(mesh)
    if d:
        return d, "keychain"
    print("⚠️  WARNING: using built-in development key — not for production. "
          "Set one with: yxkey generate", file=sys.stderr)
    return _DEV, "development"
