# yx message signing — Ed25519 over canonical S-expr (spec)

**Status:** SPEC v1 (2026-07-19). **Author:** Scott D. Yelich. **Implements:** ADR D12.
**Depends on:** message-format.md (`(msg …)`), protocol0-sexpr.md, D08 (Keychain).

Membership (send/receive) = the shared mesh HMAC key. **Authority** (a message that gets
ACTED ON) = a valid Ed25519 signature from a key in the receiver's trusted-signers store.

## 1. Keys

- Each agent has an **Ed25519 signing keypair**. Private key stored in the Keychain
  (`security` generic-password, service `org.spy.yx.sig`, account = `<agent-id>`), value =
  base64 of the 32-byte seed. Public key is distributable (base64 of 32 raw bytes).
- Managed by `yxkey`:
  - `yxkey sign-gen  --id <agent-id>`  → generate keypair, store private, print the pubkey (base64).
  - `yxkey sign-pub  --id <agent-id>`  → print the public key (base64).
  - `yxkey sign-list`                   → list signing agent-ids present.

## 2. Trusted-signers store

`~/.config/yx/trusted-signers.sxp` — an S-expression (D11), loaded by every node:
```lisp
(trusted-signers
  (signer (id "colossus/claude-1") (key "<base64-ed25519-pubkey>"))
  (signer (id "laptop/claude")     (key "<base64-ed25519-pubkey>")))
```
A signer in this set is trusted for authority. Absent ⇒ untrusted (chat only). Revoke by
removing the entry; distribute via the vault or commit (pubkeys aren't secret).

## 3. Canonical signing bytes (MUST be byte-identical across Swift & Python)

To sign a `(msg …)`:
1. Take the message's child fields EXCLUDING any existing `(sig …)`. **Keep `(key-id …)`**
   (so the signer identity is bound into the signature).
2. Emit the **canonical form**: `(msg` then each field, **sorted by field name (the child's
   car) ascending (byte order)**, each serialized by the standard SExpr writer (one space
   between siblings, strings with `\" \\ \/ \n \t` escapes, integral numbers without `.0`),
   single spaces, no extra whitespace, then `)`. This canonical serializer is defined ONCE
   and implemented identically in Swift and Python.
3. UTF-8 encode → these are the signed bytes.

Sign with the agent's Ed25519 private key; append `(sig "ed25519:<base64-64-byte-sig>")`.

**Verify:** strip `(sig …)`; recompute the canonical bytes; verify the signature with the
pubkey named by `(key-id …)`; AND require that `key-id` is in trusted-signers. Honor only
if BOTH hold.

**Interop test vector** (both impls MUST agree): a fixed `(msg …)` + a fixed 32-byte seed →
a fixed canonical byte string and a fixed signature. Ship it as a test fixture; Swift-signed
verifies in Python and vice versa.

## 4. Authority policy

- `(type command)` (and `order`) are **authority-bearing**: the receiver executes the action
  ONLY if the message carries a valid `(sig)` from a trusted `(key-id)`. Otherwise it is
  **refused** (logged; MAY answer with a `(type reject) (body "untrusted")`).
- All other types (`request`/`reply`/`ack`/`note`) need no signature — chat is open to any
  mesh member.
- Enforcement is at the point of action: never trust `from`; trust the signature.

## 5. Verification (acceptance)

- V1: `sign-gen` → `sign-pub` round-trips; private in Keychain, public printed.
- V2: sign a `(msg (type command) …)`; verify true with the right pubkey, false if any byte
  of the canonical content changes or the wrong pubkey is used.
- V3: cross-language — a Swift-signed command verifies in Python and vice versa (shared test
  vector: same canonical bytes, same signature).
- V4: yxnode HONORS a trusted-signed command (logs EXECUTED) and REFUSES an unsigned or
  untrusted-signed command (logs REFUSED) — proven for all four combos
  (swift↔swift, swift↔python, python↔python, python↔swift).

## 6. Notes / limits

- HMAC authenticates the node; `from`/`key-id` agent identity is bound only by the signature.
- Confidentiality: shared-key AES is readable by all members; signing does not add secrecy.
- Canonical form here is a fixed-order S-expr serialization (sufficient + deterministic); it
  is NOT full Rivest csexp — adopt csexp later if a formal canonical encoding is wanted.
