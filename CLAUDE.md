# CLAUDE.md — yx repo (agent guide)

**This repo is the canonical YX implementation (see VERSION — currently v2.2.1)** — the production v2.0.0 code
promoted from sdts on 2026-07-19, NOT the YBS rebuild (that lives on branch
`archive/ybs-rebuild-v1`, tag `pre-v2-import`). Read `README.md` for layout.

## What YX is

Secure UDP messaging: `HMAC(16) + GUID(6) + payload`; Protocol 0 text/JSON-RPC,
Protocol 1 v2.0 binary (channels/chunking); broadcast peer discovery. Dual
implementations with verified live Python↔Swift interop.

## Working rules

- **Implementation lives in** `Sources/` (Swift, SPM root) and `src/python/yx` (Python).
  The `python/` and `swift/` top-level dirs are the YBS spec/step harness — do NOT put
  implementation code there.
- Python venv: `python3.12` (NOT 3.14 — its ensurepip is broken on this box).
  `.venv/bin/pip install -e 'src/python[dev]'`; run tests from `src/python/`.
- Tests must stay green: 88 Python + 115 Swift. Run both before committing.
- Live smoke test: see README quick start. Use explicit IPv4 addresses — `localhost`
  can resolve to ::1 and the sockets are IPv4-only.
- **Concurrency landmines (both bitten 2026-07-19, see 8f87db1):**
  1. Never run blocking syscalls (recvfrom etc.) actor-isolated — starves the actor.
     `UDPTransport.receiveLoop` is deliberately `nonisolated` + `Task.detached`.
  2. Never fire-and-forget the keep-alive/shutdown path in a CLI main — the process
     exits and kills all tasks.
- **Wire landmines (both proved live laptop↔colossus 2026-07-27, first cross-machine
  exchange on the v2.2 wire). Both fail SILENTLY — they look identical to "the other
  machine is down", so you debug the wrong thing:**
  1. **Discovery must BROADCAST, never unicast.** Peers bind `*:50000` with
     `SO_REUSEPORT`, so a unicast datagram is load-balanced by the kernel to exactly
     ONE socket — with 3 services up you get 1 reply and conclude the other 2 are dead.
     Broadcast to `255.255.255.255:50000` reaches all of them. Replies come back as
     broadcast regardless: `_handle_discover` (sdts `lib/rpc/server.py`) broadcasts a
     `system.heartbeat` rather than responding to the sender's address — so a listener
     must be bound to `:50000`, not just reading the send socket's replies.
  2. **The HMAC key is the 32 DECODED bytes, not the 64-char ASCII.** `etc/shared_key.txt`
     holds 64 hex chars; `YX.py` does `bytes.fromhex(key)`. Passing the file's text
     straight through builds a well-formed packet that every peer drops on HMAC
     mismatch — no error, no log, just silence. Verify both ends' key files hash
     identically before blaming the network.
- `UDPNetworking.send` is fire-and-forget (`Task { await actor.send }`) — sends are
  async with no backpressure; don't assume synchronous delivery.
- sdts consumes this repo as a dependency (`deps/yx` submodule). API changes here can
  break sdts services — check `sdts/scott/algotrader` usage before renaming public API.
- Version: bump `VERSION` + `src/python/pyproject.toml` together; tag `vX.Y.Z`.

## Consumers

- **sdts** (`~/workspace/sdts`) — AlgoTrader service mesh + ib-bridge (trading).
  BaseService pattern: heartbeat broadcast to 255.255.255.255:50000, JSON-RPC RPC.

---

## 🔧 Tool installation — everything on PATH via `~/ai/bin`

**All command-line tools from every project are reachable from `~/ai/bin`,** which
is on PATH. One location, no per-project PATH juggling, no `cd` to run a CLI.

### Symlink, do not copy

```sh
ln -sfn "$REPO/bin/mytool" ~/ai/bin/mytool     # correct
cp "$REPO/bin/mytool" ~/ai/bin/mytool          # goes stale silently
```

A copy is a snapshot: edit the source and the deployed tool keeps running the
old code, which is invisible until it produces a wrong answer. A symlink cannot
drift.

**Exception — compiled Swift binaries must be copied, then re-signed:**
```sh
cp .build/release/mytool ~/ai/bin/mytool
codesign -s - --force ~/ai/bin/mytool          # REQUIRED, or macOS kills it
```
Without the re-sign the binary dies at launch with `zsh: killed` and no useful
error.

### Entry points must be location-independent

A tool reached through a symlink sees the SYMLINK in `__file__`, so anything
deriving its project root from `__file__` computes the wrong path and fails on
import. Resolve first:

```python
_real = os.path.realpath(__file__)          # not abspath -- realpath
```

### Python tools must pin their own interpreter

`#!/usr/bin/env python3` resolves to whatever is first on PATH — on this machine
Homebrew's, which has none of any project's dependencies. Every Python entry
point re-execs into its own project venv:

```python
_real = os.path.realpath(__file__)
_venv = os.path.join(os.path.dirname(os.path.dirname(_real)), ".venv", "bin", "python3")
if os.path.exists(_venv) and (
        os.path.realpath(sys.executable) != os.path.realpath(_venv)
        or os.path.abspath(__file__) != _real):
    os.execv(_venv, [_venv, _real] + sys.argv[1:])
```

Idempotent, self-healing, and harmless if the venv is already active.

**Interpreters are project venvs (`<repo>/.venv`), never pyenv.** The old
`~/.pyenv/versions/yx-dev` convention is retired and that environment no longer
exists; entry points relying on it failed with `ModuleNotFoundError:
cryptography` before they could report anything useful. Each repo pins its
dependencies in `requirements.txt`.

### Checklist for a new tool

- [ ] symlinked into `~/ai/bin` (or copied + `codesign` if a Swift binary)
- [ ] runs from any working directory
- [ ] runs with a clean PATH (`env -i`)
- [ ] resolves `__file__` through symlinks
- [ ] re-execs into its project venv, if Python
