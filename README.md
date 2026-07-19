# YX — secure UDP messaging protocol (Python + Swift)

**v2.1.0** — the production YX v2.0.0 implementation (promoted from sdts, where it runs
AlgoTrader's service mesh) re-homed here as the canonical source of truth, plus two
transport fixes and **live cross-language UDP interop verified** (2026-07-19).

Packet: `HMAC-SHA256(16B) + GUID(6B) + payload` over UDP. Protocol 0 = text/JSON-RPC,
Protocol 1 v2.0 = binary with 65,535 channels, chunking, per-channel sequences.
Optional AES-256-GCM. Broadcast-based peer discovery. No TCP, no PKI.

## Layout

```
Package.swift, Sources/, Tests/   Swift implementation (4 targets: Primitives,
                                  Transport, RPC, YX) — SPM package at repo root
yxCLI/                            Swift test/demo CLI (path-dep on ../)
src/python/                       Python implementation (pip: yx-networking)
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

## History / branches

- `archive/ybs-rebuild-v1` (tag `pre-v2-import`) — the YBS spec-driven v1 rebuild this
  main line replaced. Its specs/steps live on in `python/`, `swift/`, `protocol/`.
- Production lineage: developed inside sdts (`ScottYelich/sdts`) through Oct 2025;
  extracted to this repo 2026-07-19. sdts now consumes yx as a dependency.

## Known follow-ups

- Adapt the 48-test interop matrix to v2 framing (`tests/interop-v1-legacy/`).
- `yxcli` console-script entry point calls async main without asyncio.run (use
  `python -m yxCLI` instead until fixed).
- Dev HMAC key in tests/docs is a LAN development default — override via `--key`.
