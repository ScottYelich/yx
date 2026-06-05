# yx — executive summary

**One-liner:** A secure, payload-agnostic UDP packet protocol with HMAC integrity and byte-identical wire format across Python and Swift implementations.

## What it provides
- A lightweight transport layer for distributed/LAN systems: UDP broadcast delivery with HMAC-SHA256 packet integrity (16-byte truncated), optional AES-256-GCM encryption, optional ZLIB compression, and chunked delivery for large messages.
- A defined 3-layer wire format (HMAC + 6-byte sender GUID + variable payload) with both a text protocol and a binary protocol, channel-based message isolation (up to ~65K channels), and a default port of 50000.
- Cross-language parity by construction: the Python build is the reference implementation and emits canonical test vectors and reference packets; the Swift build validates byte-for-byte against those canonical artifacts.
- A full YBS-managed spec/step/build structure (specs define WHAT, steps define HOW per language, builds are workspaces, canonical holds shared validation artifacts) plus a working Python and Swift implementation under `canonical/`.

## Strengths
- Clear, versioned protocol specification (v1.0.3 / Binary Protocol v2.0) with an exact wire-format layout, making third-party implementations feasible.
- Strong guarantee model: implementations must produce byte-identical packets for identical inputs, enforced via canonical test vectors rather than prose.
- Solid security primitives chosen sensibly (HMAC-SHA256 with constant-time compare, AES-256-GCM, CSPRNG-generated GUIDs).
- Reproducible, AI-agent-driven build methodology via YBS, with crash-recovery session handling and per-step status tracking.
- Independent test coverage is real: ~100 Python unit tests plus integration tests, and Swift canonical validation passing 3/3 vectors.

## Weaknesses / limitations
- Cross-language UDP interoperability is unproven. Only wire-format compatibility is verified; actual Python↔Swift, Swift→Python, and Swift→Swift network communication is untested due to Swift API mismatches (SymmetricKey vs raw bytes, parameter naming) and a broken `test_all_combinations.py` harness.
- Documentation is internally inconsistent: the top-level README and CLAUDE.md still claim "no builds exist yet" and "steps need to be created," while build steps, working Python/Swift code, and an INTEROP_STATUS report already exist. The README understates current maturity.
- The mandated "48/48 interop tests" completion bar is not met, so by the project's own definition the system is not formally "complete."
- UDP broadcast transport implies no built-in delivery guarantees, ordering, or retransmission beyond the chunking layer; replay protection and key distribution are out of scope.
- Production-readiness is currently scoped to same-language use only.

## Why you'd use it
Use yx when you need a small, auditable, authenticated message protocol over UDP for trusted LAN/distributed systems — especially when the same protocol must be spoken from multiple languages (e.g., a Python tool and a Swift agent) and you need a hard guarantee that their packets are bit-identical. It is a protocol/data-plane building block, not a general-purpose networking stack.

## How it relates to the other projects
yx is the data/protocol layer of the portfolio and is itself built with **ybs** (the S-expression spec/step build methodology), sharing that family's spec→step→build discipline and canonical-artifact validation philosophy with siblings like **gws** and **yobro**. Its Python-reference / Swift-validates split mirrors the Swift-heavy execution tier of the ecosystem (**murphy**, **agent**), and it is a natural transport for LAN-oriented AI workflows such as **laniakea** and for message passing between agentic components (**mind**, **memory**, **dagsmith**). Where those projects orchestrate work and reason over content, yx provides the secure wire format that could carry messages between their distributed nodes.

---
*Executive summary — condensed from this repo's own docs. Part of [ScottYelich · portfolio](https://scottyelich.github.io/portfolio/), the public starting point for these projects.*
