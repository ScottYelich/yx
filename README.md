> 🏠 Part of **[ScottYelich · portfolio](https://scottyelich.github.io/portfolio/)** — the public starting point for these projects. · 📄 **Web version:** open [`index.html`](index.html) in a browser.

# YX System

**YX** is a secure, payload-agnostic UDP-based networking protocol with HMAC integrity, optional encryption/compression, and chunked delivery for large messages.

## Overview

YX provides a lightweight, secure transport layer for distributed systems:
- UDP broadcast-based communication
- HMAC-SHA256 packet integrity
- Optional AES-256-GCM encryption
- Optional ZLIB compression
- Multi-packet chunking for large messages
- Channel-based message isolation (65K channels)
- Cross-platform wire format (Python/Swift parity)

## This is a YBS System

This directory follows the [YBS (Yelich Build System)](https://github.com/ScottYelich/ybs) structure:

- `specs/` - Specifications defining WHAT YX is and does
- `steps/` - Build steps defining HOW to implement YX (organized by language)
- `builds/` - Build workspaces for different YX implementations
- `canonical/` - Shared reference artifacts for cross-implementation validation
- `tests/` - System-level and interoperability tests
- `docs/` - Additional documentation

Learn more about YBS: https://github.com/ScottYelich/ybs

## Multi-Language Implementation

YX is designed to have implementations in multiple languages with guaranteed wire format compatibility:

### Primary Implementations
- **Python** (`canonical/python/`) - Reference implementation, generates canonical test vectors
- **Swift** (`canonical/swift/`) - High-performance implementation, validates against canonical test vectors

(The YBS build is authored under `builds/{python,swift}-impl/` and *promoted* into
`canonical/` — `canonical/` is the committed source of truth.)

### Build Order
1. **Python first** - Generates canonical artifacts in `canonical/`
2. **Swift second** - Validates against Python's canonical artifacts
3. **Interop tests** - Verifies Python ↔ Swift communication (`tests/interop/`)

All implementations must produce byte-identical packets for the same inputs.

## Getting Started

### Python implementation
```bash
cd canonical/python && PYTHONPATH=src python3 -m pytest src/ tests/ -q
```

### Swift implementation
```bash
cd canonical/swift && swift test
```

### Running interop tests (full 48-test matrix, real UDP)
```bash
python3 tests/interop/run_matrix.py
```

## Current Status

- ✅ Protocol specification complete (`specs/technical/yx-protocol-spec.md`)
- ✅ Testing strategy defined (`specs/testing/testing-strategy.md`)
- ✅ Build steps authored (Steps 0–15 for both Python and Swift under `steps/`)
- ✅ **Python implementation complete** (`canonical/python/`) — Transport, Protocol 0
  (Text/JSON-RPC), Protocol 1 (Binary: compression / AES-256-GCM / chunking +
  reassembly), security (replay protection + rate limiting); **148 unit tests pass**
- ✅ **Swift implementation complete** (`canonical/swift/`) — same feature set;
  **67 tests pass** (43 XCTest + 24 Swift Testing)
- ✅ **Cross-language interoperability: 48/48 tests pass** over real UDP sockets
  (Transport 20, Protocol 0 12, Protocol 1 16; Python↔Python, Python↔Swift,
  Swift↔Python, Swift↔Swift) — run via `tests/interop/run_matrix.py`

## Recommended Architecture (above YX)

YX is the transport **core** — secure, payload-agnostic wire. Orchestration belongs in
layers **above** it, not inside it. Recommended stack (reference design visualized in
[`docs/sdts-algotrader-topology.html`](docs/sdts-algotrader-topology.html)):

- **YX** (this repo) — HMAC transport + Protocol 0 (text/JSON-RPC) + Protocol 1
  (binary/chunked) + single-shot RPC dispatch. No orchestration here, by design.
- **Node mesh** (proposed `YXMesh`, **Swift** on the finished YX-Swift) — a typed,
  pluggable **A2A JSON-RPC** node layer: a `Node` base (register RPC handlers +
  lifecycle + `ping`/`discover`/`health`), an id-matched `RPCClient`, and an optional
  `NodeManager` (config-driven start/stop/health, dependency-ordered startup).
  **Reference implementation already exists and works:** SDTS/AlgoTrader
  (`sdts/scott/algotrader/`: `services/manager.py`, `services/base.py`, `lib/rpc/client.py`).
- **Workflow** (proposed `YXFlow`, optional) — generic multi-step orchestration with
  per-step status (`pending/running/done/failed`, retries, timeouts): the reusable form
  of AlgoTrader's `trade_tracker` state machine. Sits above the mesh.
- **Transport abstraction** — a `MessageTransport` with `in-process` and `YX-UDP`
  implementations, so the **same** node graph runs embedded in one binary **or**
  distributed across a LAN.

**Language strategy:** one framework language — **Swift** (on YX-Swift). Nodes are
heterogeneous and interoperate over the YX wire (proven by the 48/48 cross-language
suite), so keep `ib-bridge` in **Python** — where the mature `ib_async` library lives —
as a node on the bus, and write everything else in Swift. Do **not** reimplement
`ib_async` until a focused Swift subset clearly pays off.

## Reference Documentation

- `docs/ybs-overview.md` - Introduction to YBS framework
- `docs/ybs-framework-spec.md` - Complete YBS framework specification
- `specs/technical/yx-protocol-spec.md` - YX UDP protocol specification
