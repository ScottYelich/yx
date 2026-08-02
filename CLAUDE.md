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

## Source Boundary — What Belongs HERE

- The canonical YX implementations: Swift (`Sources/`, SPM root) and Python (`src/python/yx`)
- Protocol specs and wire-format docs (`protocol/`, `docs/`)
- Interop and unit tests (`tests/`), the `yxCLI` entry points
- The YBS spec/step harness (top-level `python/`, `swift/` — specs and steps only, never implementation code)

## Source Boundary — What Does NOT Belong Here

| If you need to... | Go to |
|-------------------|-------|
| Change trading services built on YX (AlgoTrader, ib-bridge, simulators) | the `sdts` repo (consumes YX via its `deps/yx` submodule) |
| Build application-level tooling on top of YX | your own consumer repo — YX stays transport + RPC only |

## Consumers

- **sdts** (`~/workspace/sdts`) — AlgoTrader service mesh + ib-bridge (trading).
  BaseService pattern: heartbeat broadcast to 255.255.255.255:50000, JSON-RPC RPC.
