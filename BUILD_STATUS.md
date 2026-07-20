# YX — Build Status

**Author:** Scott D. Yelich · **Updated:** 2026-07-19 · **Version:** 2.1.0

## Done

- **Production implementation re-homed from sdts** — the v2.0.0 code that runs
  AlgoTrader's service mesh is now the canonical source of truth in this repo;
  sdts consumes yx back as a git-submodule dependency (AlgoTrader mesh +
  ib-bridge trading adapter).
- **Swift + Python wire parity** — byte-identical wire format
  (`HMAC-SHA256(16B) + GUID(6B) + payload`; Protocol 0 text/JSON-RPC,
  Protocol 1 v2.0 binary with 65,535 channels, chunking, per-channel sequences;
  optional AES-256-GCM). Swift is the base (ADR D09, SPM); Python is
  wire-parity validation + the Python-bound edges (ib_async, MLX). No pip
  distribution.
- **Live cross-language interop proven** (2026-07-19) — real Python↔Swift UDP
  messaging: two-node mutual discovery + cross-language message delivery
  (Swift node ↔ Python node), keyed from the Keychain. Two Swift transport bugs
  fixed to get there (fire-and-forget CLI keep-alive Task; actor-isolated
  blocking `recvfrom` starving the receive loop).
- **`yxkey` + Keychain key management** (ADR D08) — mesh HMAC keys in the macOS
  Keychain (service `org.spy.yx`); `generate|set|get|list|remove`, `set` reads
  stdin; resolution `--key` > `YX_KEY` > Keychain > dev key (loud warning).
  Python mirror in `src/python/yx_key.py`.
  Spec: `protocol/specs/architecture/key-management.md`.
- **`yxnode` mesh node daemon** — presence heartbeat (`node.hello`), `node.info`
  RPC, and `msg.deliver` → Unified Node Format (UNF) markdown to
  `~/ai/mail/YYYY/MM/<id>.md` for locally-addressed agents. Swift = production,
  Python = spec-proof.

## Tests

| Suite | Count | Status |
|-------|-------|--------|
| Swift (`swift test`) | 94 | passing |
| Python (`pytest`, `src/python/tests/`) | 47 | passing |

Interop: proven via live cross-language node tests + the unit suites. The
older line's formal 48-test interop matrix has **not** been re-run against v2
framing (`tests/interop-v1-legacy/`).

## Next / not done

- **Message-bus reliability layer** — ack/retry/dedup on top of best-effort UDP.
- **Re-run the formal 48-test interop matrix** adapted to v2 framing.
- **Bonjour/mDNS discovery** (ADR D10) — designed-for; broadcast only today.
- **`msg` client CLI** — send messages into the mesh without running a node.
- **laniakea launchd deploy** — stand yxnode up as a supervised service
  (laniakea `svc`).
- Mesh-key distribution is manual (per-node Keychain) — no automated rollout.

See `README.md` (layout + quick start), `docs/yx.md` (executive summary), and
`protocol/specs/architecture/ybs-decisions.md` (ADRs D08/D09/D10).
