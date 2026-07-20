# yx message format — `(msg …)` (spec)

**Status:** SPEC v1 (2026-07-19). **Author:** Scott D. Yelich.
**Implements:** ADR D11 (s-expr) · rides Protocol 0 (protocol0-sexpr.md) · trust: ADR D12.

An agent message is a single S-expression carried as a Protocol-0 payload. yx is the
envelope (HMAC auth + GUID + routing); this is the body.

## Schema

```lisp
(msg
  (v 1)                              ;; REQ  schema version
  (id "b91c04d2")                    ;; REQ  sender-random hex (8+). Dedup+thread key = (from,id).
  (type request)                     ;; REQ  request | ack | reply | reject | note
  (from "colossus/claude-1")         ;; REQ  agent-level sender (yx GUID = node, not agent)
  (to "laptop/claude")               ;; REQ  node/agent-id, or "@all" for broadcast
  (created "2026-07-19T14:00:00Z")   ;; REQ  ISO-8601. Advisory (clock skew) — never a dedup key.
  (in-reply-to "a0…")                ;; REQ on ack/reply/reject · FORBIDDEN on request
  (subject "one line")               ;; REQ on request/note · optional otherwise
  (body "prose")                     ;; REQ on reject (the why) · optional otherwise
  ;; -- optional --
  (priority normal)                  ;;      low | normal(default) | high
  (content-type text)                ;;      text(default) | markdown | json  (describes body)
  (data (…))                         ;;      structured payload as NATIVE nested s-expr
  (thread "root-id")                 ;;      conversation root for multi-hop threads
  (refs (commit "…") (step "…") (file "…"))
  (key-id "colossus/claude-1#1")     ;;      D12: which pubkey signed (authority msgs)
  (sig "ed25519:base64…"))           ;;      D12: detached sig over canonical bytes
```

## Conversation model (discrete messages, no shared state)

- **request** → optional **ack** (in-reply-to) "seen, working" → **reply** (done) or
  **reject** (why, body required). Sender matches `in-reply-to` against its own outstanding
  table; it learns outcomes ONLY from inbound messages.
- **1→many:** one message per recipient with DISTINCT ids (never one id fanned out).
- **broadcast:** `(to "@all") (type note)` — informational, no acks expected. To engage,
  a recipient opens a normal 1:1 thread. `@all` is addressing; `note` is a type.
- **note:** fire-and-forget 1:1 or broadcast; no reply expected.

## Trust (D12, summary)

Membership (may send/receive) = the shared mesh HMAC key. Authority (a message that gets
ACTED ON — run a command, place an order) = a valid `(sig)` from a `(key-id)` in the
receiver's trusted-signers store. Unsigned / untrusted-signed authority messages are
received but REFUSED. `from` is a claim; the signature is the truth.

## Delivery / dedup / reliability

- Delivered via Protocol 0 to the target node; the node filters `to` to its local agents
  (`@all`, exact agent-id, or `node/*`).
- Dedup on `(from,id)`; a re-sent request with the same id is idempotent.
- yx is best-effort UDP: a lost message is invisible to the sender. `ack` doubles as
  delivery-confirmation; high-priority requests SHOULD be acked; sender MAY re-send.

## Storage

A received `(msg …)` is spooled verbatim as `~/ai/mail/YYYY/MM/<id>.sxp` (S-expression,
never UNF/YAML/markdown). The file IS the message.

## Examples

Request:
```lisp
(msg (v 1) (id "b91c04d2") (type request) (from "colossus/claude-1") (to "laptop/claude")
  (created "2026-07-19T14:00:00Z") (priority high) (subject "need composeData()")
  (body "XNG query tool blocked; need composeData(query:) -> CompositionResult."))
```
Reply (threaded, structured data):
```lisp
(msg (v 1) (id "7e22ab90") (type reply) (from "laptop/claude") (to "colossus/claude-1")
  (created "2026-07-19T14:30:00Z") (in-reply-to "b91c04d2") (subject "shipped")
  (body "added; ComposedQuery takes fields + filters.")
  (data (api (fn "composeData") (returns "CompositionResult"))) (refs (commit "abc1234")))
```
