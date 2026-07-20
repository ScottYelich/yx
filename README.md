# YX — secure UDP messaging protocol (Python + Swift)

**Author:** Scott D. Yelich · **Updated:** 2026-07-19 · **Version:** 2.1.0

**v2.1.0** — the production YX v2.0.0 implementation (promoted from sdts, where it runs
AlgoTrader's service mesh) re-homed here as the canonical source of truth, plus two
transport fixes and **live cross-language UDP interop verified** (2026-07-19).

Packet: `HMAC-SHA256(16B) + GUID(6B) + payload` over UDP. Protocol 0 = text/JSON-RPC,
Protocol 1 v2.0 = binary with 65,535 channels, chunking, per-channel sequences.
Optional AES-256-GCM. Broadcast-based peer discovery. No TCP, no PKI.

## Layout

```
Package.swift, Sources/, Tests/   Swift implementation — SPM package at repo root
                                  (libraries: Primitives, Transport, RPC, YX;
                                  executables: yxkey, yxnode)
yxCLI/                            Swift test/demo CLI (path-dep on ../)
src/python/                       Python implementation — used in-tree / via submodule
                                  path for wire-parity validation (NO pip/PyPI distribution)
    yx/           the package     yxCLI/  python CLI (python -m yxCLI)
    tests/        47 tests
protocol/specs/                   language-agnostic specs; v2 spec + v1->v2 migration
                                  in technical/
python/, swift/                   YBS build-steps harness (spec-driven rebuild track)
canonical/test-vectors/           v1-era wire vectors (Protocol 0 still valid)
tests/interop-v1-legacy/          v1 48-test matrix (needs v2 framing adaptation)
```

## Quick start

```sh
# Python
python3.12 -m venv .venv && .venv/bin/pip install -e 'src/python[dev]'
(cd src/python && ../../.venv/bin/python -m pytest tests/)   # 47 tests

# Swift
swift build && swift test                                    # 94 tests
(cd yxCLI && swift build)

# Live cross-language smoke test (two terminals or backgrounded):
yxCLI/.build/debug/yxCLI --port 50100 --peers 127.0.0.1:50200 --shutdown-after 12 &
(cd src/python && ../../.venv/bin/python -m yxCLI --port 50200 --peers 127.0.0.1:50100 --shutdown-after 8)
# expect each side to log the other's task.hello
```

Note: use explicit IPs or broadcast; sockets are IPv4 (`localhost` may resolve to ::1).

## Executables & the mesh/key model

Swift is the base implementation (ADR D09); consume it via SPM — this repo is the
package. Three executables ship with it:

- **`yxCLI`** (`yxCLI/`, separate package with a path-dep on this repo) — test/demo
  CLI; drives the live cross-language smoke test above.
- **`yxkey`** — mesh key manager (`generate|set|get|list|remove`; `set` reads stdin,
  never argv). Mesh HMAC keys live in the **macOS Keychain** (ADR D08), service
  `org.spy.yx`, account = mesh name. Key resolution order (`MeshKey`): `--key` flag >
  `YX_KEY` env > Keychain > built-in dev key (with a loud warning). Python mirrors
  this via `security` in `src/python/yx_key.py`.
  Spec: `protocol/specs/architecture/key-management.sxp`.
- **`yxnode`** — base mesh node daemon and the canonical "how to build a service on
  yx" example: heartbeats presence (`node.hello`), answers `node.info` RPC, and on
  inbound `msg.deliver` writes a Unified Node Format (UNF) markdown file (YAML
  frontmatter + body) to `~/ai/mail/YYYY/MM/<id>.md` for locally-addressed agents.
  Swift `yxnode` is production; the Python `yxnode` (`src/python/yxnode`) is
  spec-proof only. Proven: two-node mutual discovery + cross-language delivery
  (Swift node ↔ Python node), keyed from the Keychain.

ADRs live in `protocol/specs/architecture/ybs-decisions.sxp`: D08 Keychain keys ·
D09 Swift-first · D10 pluggable discovery (UDP broadcast now, Bonjour/mDNS later).
See `docs/yx.sxp` for the executive summary and `BUILD_STATUS.sxp` for current status.

## History / branches

- `archive/ybs-rebuild-v1` (tag `pre-v2-import`) — the YBS spec-driven v1 rebuild this
  main line replaced. Its specs/steps live on in `python/`, `swift/`, `protocol/`.
- Production lineage: developed inside sdts (`ScottYelich/sdts`) through Oct 2025;
  extracted to this repo 2026-07-19. sdts now consumes yx as a dependency.

## Known follow-ups

- Message-bus reliability layer (ack/retry/dedup) — not built yet; UDP is best-effort.
- Adapt the 48-test interop matrix to v2 framing (`tests/interop-v1-legacy/`) —
  until then, interop is proven via live cross-language node tests + the unit suites.
- Bonjour/mDNS discovery (ADR D10) — designed-for, not implemented; broadcast only.
- Mesh-key distribution is manual (per-node Keychain via `yxkey`).
- `yxcli` console-script entry point calls async main without asyncio.run (use
  `python -m yxCLI` instead until fixed).
- Dev HMAC key in tests/docs is a LAN development default — set a real mesh key via
  `yxkey` (or override with `--key` / `YX_KEY`).
