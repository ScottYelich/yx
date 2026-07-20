# YX Key Management Specification

**Status:** SPEC — v1 (2026-07-19)
**Implements:** ADR D08 (see ybs-decisions.md)
**Traceability:** security-architecture.md (HMAC key = mesh membership boundary)

## 1. Problem

The YX HMAC key IS mesh membership: any holder can join, read, and inject. The
historical "development key" is committed to (public) repos and hardcoded as a
CLI default. Keys MUST live outside git, in an OS-encrypted store, and tools
MUST resolve them at runtime.

## 2. Requirements

- R1: Keys are stored in the **macOS Keychain** (encrypted at rest, unlocked with
  the user session). No plaintext key files in any repo or dotfile.
- R2: A CLI (`yxkey`) manages keys: `set`, `get`, `list`, `remove`.
- R3: Key material never appears in argv or shell history — `set` reads from
  **stdin**; `get` prints to stdout only (for piping/subprocess use).
- R4: A key is 32 bytes, entered/displayed as 64 hex chars. `set` validates;
  `generate` creates a cryptographically random one.
- R5: Multiple meshes: keys are named. Keychain mapping:
  `service = "org.spy.yx"`, `account = <mesh-name>` (default mesh name: `mesh`).
- R6: All YX executables resolve keys in this order (first hit wins):
  1. explicit `--key <hex>` flag        (tests, overrides)
  2. `YX_KEY` environment variable      (CI, launchd plists w/ EnvironmentVariables)
  3. Keychain `org.spy.yx` / `--mesh <name>` account   (normal operation)
  4. built-in development key + a LOUD warning         (dev convenience only)
- R7: Python implementation reaches the Keychain via
  `security find-generic-password -s org.spy.yx -a <mesh> -w` (subprocess) —
  same resolution order, no new dependencies.

## 3. Non-goals (v1)

- Key rotation protocol over the mesh (manual: `yxkey set` on each node).
- Per-peer derived keys (KeyStore/KeyRotation already sketch this — unchanged).
- Non-macOS stores (future: file-based encrypted store or platform keyring).

## 4. API contract

```
yxkey generate [--mesh NAME]      create + store a random 32-byte key; prints hex
yxkey set      [--mesh NAME]      read 64-hex from stdin, validate, store (upsert)
yxkey get      [--mesh NAME]      print 64-hex to stdout (exit 1 if absent)
yxkey list                        list mesh names present in the Keychain
yxkey remove   [--mesh NAME]      delete the named key
```

Swift: `MeshKey.load(mesh:explicit:)` in Primitives implements R6 and is used by
yxCLI + yxnode. Python: `yx_key.resolve_key(args)` mirrors it for the python CLI.

## 5. Verification

- V1: `yxkey generate` → `yxkey get` round-trips 64 hex chars.
- V2: `set` rejects non-hex and wrong lengths.
- V3: yxCLI with no `--key` and Keychain populated uses the Keychain key
  (log shows `key source: keychain`), and interops with the python CLI resolving
  the same key via `security`.
- V4: with nothing configured, tools still run on the dev key but print the
  warning (grep-able: `WARNING: using built-in development key`).

## 6. Future (recorded, not built)

- Bonjour/mDNS discovery (ADR D10) does not change key handling: discovery ≠
  membership; the HMAC key remains the trust boundary.
- `yxkey rotate` — regenerate + optional mesh-wide announce once node daemons
  can coordinate.
