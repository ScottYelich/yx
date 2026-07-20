"""Mesh key resolution mirroring Swift MeshKey (ADR D08 / key-management.md).

Order: explicit hex > YX_KEY env > Keychain(security) > dev key (warns).

Also a CLI mirroring the Swift `yxkey` signing commands (ADR D12):
  python yx_key.py sign-gen  --id AGENT   generate keypair, store private, print pubkey (base64)
  python yx_key.py sign-pub  --id AGENT   print the public key (base64)
  python yx_key.py sign-list              list signing agent-ids present
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


# --- Signing-key management CLI (ADR D12; mirrors Swift `yxkey sign-*`) ---

def _sign_main(argv):
    from yx.primitives import signer

    def id_arg():
        if "--id" in argv:
            i = argv.index("--id")
            if i + 1 < len(argv):
                return argv[i + 1]
        return None

    cmd = argv[0] if argv else None
    if cmd == "sign-gen":
        agent_id = id_arg()
        if not agent_id:
            print("sign-gen requires --id <agent-id>", file=sys.stderr); return 2
        pub = signer.generate(agent_id)
        if pub is None:
            print(f"failed to generate/store signing key for '{agent_id}'", file=sys.stderr); return 1
        print(pub)  # stdout: distributable pubkey for trusted-signers.sxp
        print(f"stored Ed25519 signing key for agent '{agent_id}'", file=sys.stderr)
        return 0
    if cmd == "sign-pub":
        agent_id = id_arg()
        if not agent_id:
            print("sign-pub requires --id <agent-id>", file=sys.stderr); return 2
        pub = signer.public_key(agent_id)
        if pub is None:
            print(f"no signing key stored for agent '{agent_id}'", file=sys.stderr); return 1
        print(pub)
        return 0
    if cmd == "sign-list":
        ids = signer.list_ids()
        if not ids:
            print("no yx signing keys stored", file=sys.stderr)
        else:
            for i in ids:
                print(i)
        return 0
    if cmd == "sign-remove":
        agent_id = id_arg()
        if not agent_id:
            print("sign-remove requires --id <agent-id>", file=sys.stderr); return 2
        ok = signer.remove(agent_id)
        print(("removed" if ok else "no") + f" signing key for agent '{agent_id}'", file=sys.stderr)
        return 0 if ok else 1
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.exit(_sign_main(sys.argv[1:]))
