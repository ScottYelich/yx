# Architecture Decision Records — YX Protocol

**System**: YX Protocol
**Version**: 0.1.0
**Last Updated**: 2026-04-11

This document records all significant architectural decisions made for the YX
protocol. Each ADR captures the context, the decision, and the rationale.

---

## D01 — UDP as Transport Layer

**Status**: Accepted
**Date**: 2026-01-18

### Context
YX needs a transport layer for distributed system communication. Options
considered: TCP, UDP, Unix sockets, named pipes.

### Decision
Use UDP exclusively. The protocol does not use TCP.

### Rationale
- UDP provides connectionless, low-latency delivery suitable for real-time
  distributed systems
- The YX packet format (HMAC + GUID + payload) is self-contained; no
  connection state is needed
- Broadcast support is native to UDP — required for peer discovery
- Applications requiring reliability build it above the transport layer

### Consequences
Implementations must handle packet loss at the application layer.
No TCP fallback is defined.

---

## D02 — HMAC-SHA256 Truncated to 16 Bytes

**Status**: Accepted
**Date**: 2026-01-18

### Context
Every packet requires authentication to prevent tampering. Full HMAC-SHA256
output is 32 bytes. Choices: 32 bytes, 16 bytes, shorter.

### Decision
Compute HMAC-SHA256 over (GUID || PAYLOAD) and take the first 16 bytes.

### Rationale
- 16 bytes (128 bits) provides 2^64 security against forgery (birthday bound)
- Reduces packet overhead vs 32-byte HMAC
- SHA-256 remains the strongest widely-deployed hash function; truncation is
  the standard approach (used in TLS, NIST SP 800-107)
- All implementations must use the same truncation; no configurable length

### Consequences
The HMAC field is always exactly 16 bytes. Implementations must not use the
full 32-byte output for comparison.

---

## D03 — Payload-Agnostic Transport Layer

**Status**: Accepted
**Date**: 2026-01-18

### Context
Should the transport layer understand or validate payload content?

### Decision
The transport layer treats payload as opaque bytes. It does not parse, validate,
or interpret payload content.

### Rationale
- Enables multiplexing any protocol over the transport layer
- Simplifies the transport implementation
- Protocol 0 and Protocol 1 are defined at a layer above transport
- A compromised key allows forged payloads — transport-layer payload validation
  provides no additional security

### Consequences
Applications that use the transport directly must implement their own
payload validation. The Protocol 0/1 layers provide structured payload handling.

---

## D04 — 6-Byte GUID (Not UUID)

**Status**: Accepted
**Date**: 2026-01-18

### Context
Packets need unique identifiers for replay detection and correlation. Standard
UUID (RFC 4122) is 16 bytes. Options: 4, 6, 8, 16 bytes.

### Decision
Use 6-byte (48-bit) cryptographically-random GUIDs.

### Rationale
- 6 bytes provides 2^48 ≈ 281 trillion unique values
- Collision probability negligible for any realistic deployment
- 10 bytes smaller than UUID — significant savings at high packet rates
- Cryptographic randomness ensures unpredictability for replay window matching
- Simpler than UUID: no version bits, no variant bits, no timestamp encoding

### Consequences
GUIDs are not globally unique across all time and space (unlike UUID v4) but
are practically unique for YX's use case. Do not use GUIDs as globally-unique
identifiers outside of a YX session.

---

## D05 — Python as Reference Implementation / Canonical Artifact Generator

**Status**: Accepted
**Date**: 2026-01-18

### Context
Multiple language implementations must be wire-format compatible. A common
test vector format is needed. Which language generates the canonical artifacts?

### Decision
Python is the reference implementation. It generates canonical test vectors
and reference packets in `canonical/` that all other implementations validate
against.

### Rationale
- Python implementation was first; it defines the correct wire format by
  construction
- Python is widely readable and auditable
- Canonical artifacts are language-agnostic JSON/binary — not Python-specific
- Future implementations (Rust, Go, etc.) can validate without a Python runtime
  by loading pre-generated JSON

### Consequences
The Python implementation must be built and its canonical artifacts generated
before any other implementation begins. Python implementation bugs that affect
canonical artifacts require regenerating all artifacts and re-validating all
implementations.

---

## D06 — Three-Layer Architecture (Transport / Protocol 0 / Protocol 1)

**Status**: Accepted
**Date**: 2026-01-18

### Context
Applications need different payload semantics: some want JSON/RPC-style text
messages, others want binary efficiency with compression and encryption.

### Decision
Define three layers: Transport (mandatory), Protocol 0 Text (optional),
Protocol 1 Binary (optional). A 1-byte protocol identifier in the payload
routes packets to the correct handler.

### Rationale
- Clean separation: raw transport for applications that want full control,
  structured layers for common patterns
- The protocol byte in the payload is part of the payload spec, not the packet
  spec — transport layer remains truly agnostic
- Extensible: Protocol 2+ can be added without changing the wire format

### Consequences
Implementations must implement the transport layer. Protocol 0 and Protocol 1
are defined as separate, optional handlers. All three are required for full
feature parity per D04 (P4 — Multi-Language Parity).

---

## D07 — Replay Protection via TTL-Bounded Seen-GUID Store

**Status**: Accepted
**Date**: 2026-01-18

### Context
Attackers can replay captured valid packets. Detection mechanism needed.

### Decision
Maintain an in-memory set of recently-seen GUIDs with a 300-second TTL.
Packets with a GUID seen within the TTL window are rejected.

### Rationale
- Simple and effective against replay attacks
- 300-second window is long enough to handle clock skew and network delays
- In-memory store is sufficient; persistence across restarts is not required
  (replays across restarts require a fresh HMAC key anyway)
- TTL cleanup prevents unbounded memory growth

### Consequences
GUIDs must be cryptographically random (D04) to prevent GUID prediction attacks.
The TTL is normative (300 seconds) — implementations must not use a shorter window.
