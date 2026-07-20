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

---

## D08: Mesh keys live in the macOS Keychain, never in repos (2026-07-19)

**Decision:** HMAC mesh keys are stored in the login Keychain
(`service org.spy.yx`, one account per mesh). Tools resolve:
`--key` flag → `YX_KEY` env → Keychain → built-in dev key WITH loud warning.
**Why:** the key IS mesh membership; the dev key is in public git history.
**Consequence:** `yxkey` CLI (Swift) + `MeshKey` resolver in Primitives;
python mirrors via `security` subprocess. Spec: key-management.md.

## D09: Swift is the base implementation; Python is validation + edges (2026-07-19)

**Decision:** New YX code (node daemon, tools, services) is written in Swift,
consumed via SPM (this repo is the package). The Python implementation is kept
for wire-format parity validation and for the two Python-bound edges
(ib_async bridge, MLX tooling) until they migrate. No pip distribution.
**Why:** the surrounding ecosystem (murphy, dagsmith, agent, memory, mind) is
Swift; single codesigned binaries beat interpreter/venv maintenance.

## D10: Discovery is pluggable — UDP broadcast now, Bonjour later (2026-07-19)

**Decision:** Peer discovery v1 stays 255.255.255.255 broadcast (flat LAN).
The node daemon treats discovery as a strategy so mDNS/Bonjour (NWBrowser /
NetService) can be added without protocol changes. Discovery is NOT membership;
the HMAC key remains the only trust boundary (D08).

## D11: S-expression is the canonical structured payload format (2026-07-19)

**Status:** Accepted. **Author:** Scott D. Yelich.

**Context.** yx Protocol 0 was defined as "text / JSON-RPC"; the node/message layer
exchanged JSON objects (`{"method":…,"params":…}`) and briefly spooled messages as UNF
(YAML-frontmatter + markdown). The surrounding ecosystem is s-expression native (ybs
`.sbs`, `.sxp`, the portfolio data block, the FSMB message schema). JSON/JSONL repeatedly
forces newline framing and full-document buffering to know when a value is complete.

**Decision — across the board.** Any payload richer than plaintext is an **S-expression,
not JSON.** S-expression is the base/default structured format, and is **preferred even
over plaintext when practical.** Preference order for a payload:
**S-expression > plaintext > binary** — use the most structured form that fits; drop to
plaintext only for opaque pass-through text, binary only for non-text.

Concretely for yx:
- The message body is a single s-expression: `(msg …)` (see message-format spec).
- Protocol 0's RPC/message layer migrates from JSON-RPC to s-expression forms **dispatched
  on the head symbol (car)**: `(node-hello …)`, `(node-info)`, `(msg …)`. The head atom is
  the verb; the rest are its arguments. No `{"method","params"}` envelope.
- On-disk representations are `.sxp` s-expressions — never YAML/JSON/markdown wrappers.
  **UNF is retired.**

**Rationale.**
- **Always-known parse state.** Track paren depth; a form is complete exactly when depth
  returns to 0. Framing is self-delimiting and uniform — no length prefix, no JSONL
  convention, no "read to a terminator you may not have received yet." Critical for a
  datagram protocol and for streaming agent output (vs. the JSONL buffering murphy needs).
- **One grammar, uniform nesting** — structured data nests natively without escaping.
- **Ecosystem consistency** — everything else already speaks s-expr; JSON was the outlier.
- **Human-writable, no library required** — legible and hand-editable (FSMB-proven).

**Consequences.**
- Protocol 0 is redefined: text = s-expression, dispatched on the car. Existing JSON-RPC
  handlers (`node.hello`/`node.info`/`msg.deliver`) get rewritten to s-expr forms; a
  transition shim MAY accept both briefly.
- `yxnode` stops writing UNF; it carries and (if spooling) stores `(msg …)` as `.sxp`.
- **JSON is confined to EXTERNAL edges** where a foreign contract requires it — the
  OpenAI-compatible LLM endpoints (mlx-router), MCP, third-party HTTP APIs. **Internal
  yx/agent payloads are never JSON.**
- Forward-looking and where-feasible: not a mandate to rewrite every existing JSON emitter
  at once (e.g. murphy's JSONL event stream is an external-ish contract — migrate when
  practical). New code follows this default from the start.
- Composes with D08: optional `(key-id …)`/`(sig …)` fields slot into the grammar later
  for per-message signing without a schema break.

## D12: Membership ≠ trust — Ed25519-signed authority over a flat trust store (2026-07-19)

**Status:** Accepted. **Author:** Scott D. Yelich. **Context:** the mesh will include
untrusted machines (e.g. a family member's malware-prone PC). Such a node can hold the
shared mesh key (membership) yet must NOT be able to make trusted nodes execute anything.

**Decision — two tiers, cleanly separated:**
- **Membership** (join, send/receive chat, be seen) = the shared **HMAC mesh key**
  (+ optional AES). Anyone on the bus has it. Membership proves "a mesh member sent an
  unmodified packet" — it does NOT prove which member. Encrypted ≠ trusted.
- **Authority** (a message that gets ACTED ON — run a command, place an order, anything
  consequential) = a valid **Ed25519 signature** whose public key is in the receiver's
  **flat trusted-signers store**. Chat is accepted from any member; authority is honored
  ONLY from a trusted signer.

**Rules:**
- Enforce at the point of action: the executor of a consequential action verifies
  `(sig)` over the canonical message bytes against a `(key-id)` in its trusted-signers
  set BEFORE acting. Never trust the `from` field; `from` is a claim, the signature is truth.
- Unsigned or untrusted-signed authority messages are received but REFUSED (logged; may be
  answered with a `reject`). Informational messages need no signature.
- **Flat trust store, not PKI.** No CAs/X.509/chains. A set of trusted Ed25519 pubkeys
  (SSH `authorized_keys` style), distributed via the vault or a committed config; private
  signing keys in the Keychain beside the mesh key (D08). Revoke = remove the pubkey;
  eject a whole node = rotate the mesh key.
- **Signing substrate:** the canonical S-expression form (D11) — Rivest csexp is built for
  signing; JSON canonicalization (JCS) is a known pain. `(msg …)` canonicalizes
  deterministically; sign those bytes with Ed25519.

**Confidentiality caveat:** shared-key AES hides traffic from non-members, NOT from
members — every mesh member (incl. an untrusted node) can decrypt. For "private from a
specific member," use per-recipient (ECDH) encryption — a separate mechanism, deferred.
Option for stronger isolation: put untrusted parties on a separate mesh key and bridge.

**Now vs later:** ship membership (HMAC) + the message bus first; the `(key-id)`/`(sig)`
slots are reserved in message-format.md so signing drops in without a schema break. Add
signatures when authority-bearing messages become real (the sdts/trading path).
