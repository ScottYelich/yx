# yx — executive summary

**One-liner:** A secure, payload-agnostic UDP messaging protocol with HMAC integrity and a byte-identical wire format across Swift and Python — the production code promoted from the `sdts` trading system, where it runs AlgoTrader's service mesh.

## What it provides
- A lightweight transport layer for distributed/LAN systems: UDP delivery with HMAC-SHA256 packet integrity (16-byte truncated), optional AES-256-GCM encryption, chunked delivery for large messages, and broadcast-based peer discovery. No TCP, no PKI.
- A defined wire format — `HMAC-SHA256(16B) + GUID(6-byte sender id) + payload` — with two payload protocols: **Protocol 0** (text / JSON-RPC) and **Protocol 1 v2.0** (binary with 65,535 channels, chunking, and per-channel sequences).
- **Swift-first** (ADR D09): Swift is the base implementation, consumed via SPM — this repo IS the Swift package (libraries `Primitives`, `Transport`, `RPC`, `YX`; executables `yxCLI` test/demo, `yxkey` key manager, `yxnode` mesh node daemon). The Python implementation (`src/python/`) is kept for wire-parity validation and the two Python-bound edges (ib_async, MLX). There is **no pip distribution**.
- **Keychain-backed key management** (ADR D08): mesh HMAC keys live in the macOS Keychain, managed by the `yxkey` CLI (`generate|set|get|list|remove`; `set` reads stdin, never argv) and resolved as `--key` flag > `YX_KEY` env > Keychain (service `org.spy.yx`) > built-in dev key with a loud warning. Python mirrors this via the `security` tool in `src/python/yx_key.py`. Spec: [`protocol/specs/architecture/key-management.md`](../protocol/specs/architecture/key-management.md).
- A base mesh node daemon, **`yxnode`** — also the canonical "how to build a service on yx" example. It heartbeats presence (`node.hello`), answers `node.info` RPC, and on inbound `msg.deliver` writes a Unified Node Format (UNF) markdown file (YAML frontmatter + body) to `~/ai/mail/YYYY/MM/<id>.md` when the message is addressed to a local agent. A Swift `yxnode` is production; a Python `yxnode` exists as spec-proof.

## Strengths
- **Production-proven lineage:** this is the code that runs AlgoTrader's service mesh inside `sdts`, re-homed here as the canonical source of truth; `sdts` now consumes yx as a git-submodule dependency.
- **Cross-language interop is proven** (2026-07-19): live Python↔Swift messaging over real UDP — two-node mutual discovery and cross-language message delivery (Swift node ↔ Python node), all keyed from the Keychain — backed by **94 Swift + 47 Python** unit tests.
- Strong guarantee model: Swift and Python must produce byte-identical packets for identical inputs; the Python implementation exists specifically to hold the Swift base honest at the wire level.
- Solid security primitives chosen sensibly (HMAC-SHA256 with constant-time compare, AES-256-GCM, CSPRNG-generated GUIDs), with keys kept out of repos entirely (Keychain, ADR D08).
- Clear, versioned protocol specification and architecture decision record ([`protocol/specs/architecture/ybs-decisions.md`](../protocol/specs/architecture/ybs-decisions.md): D08 Keychain keys, D09 Swift-first, D10 pluggable discovery) — spec discipline inherited from **ybs**.

## Weaknesses / limitations
- Best-effort UDP: the reliability/message-bus layer (ack/retry/dedup) is not built yet.
- Discovery is UDP broadcast only; Bonjour/mDNS is designed-for (ADR D10) but not implemented.
- Mesh-key distribution is manual — each node's Keychain is provisioned by hand.
- The older line's formal 48-test interop matrix has not been re-run against v2 framing; interop is instead proven via live cross-language node tests plus the unit suites.

## Why you'd use it
Use yx when you need a small, auditable, authenticated message protocol over UDP for trusted LAN/distributed systems — especially when the same protocol must be spoken from Swift and Python and you need a hard guarantee that their packets are bit-identical. It is a protocol/data-plane building block, not a general-purpose networking stack.

## How it relates to the other projects
yx is the transport/data-plane of the portfolio ecosystem. It underpins a cross-machine **agent message bus**: **laniakea** stands nodes up (its `svc` tool supervises them) and `yxnode` connects them, so sibling Swift agents (**murphy**, **agent**, **dagsmith**, **memory**, **mind**) can message over it. **sdts** consumes it directly for the AlgoTrader service mesh and the ib-bridge trading adapter. Its spec/ADR discipline comes from **ybs** (the earlier YBS clean-room rebuild is preserved on branch `archive/main-ybs-completed`, tag `pre-main-reconcile`).

See also: [`README.md`](../README.md) (layout + quick start), [`BUILD_STATUS.md`](../BUILD_STATUS.md) (current status), [key-management spec](../protocol/specs/architecture/key-management.md), [ADRs](../protocol/specs/architecture/ybs-decisions.md).

---
*Executive summary — condensed from this repo's own docs. Part of [ScottYelich · portfolio](https://scottyelich.github.io/portfolio/), the public starting point for these projects.*

*Author: Scott D. Yelich · Updated 2026-07-19 · yx v2.1.0*
