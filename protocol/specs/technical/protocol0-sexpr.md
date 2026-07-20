# Protocol 0 — S-expression text (spec)

**Status:** SPEC v1 (2026-07-19). **Author:** Scott D. Yelich. **Implements:** ADR D11.
**Supersedes:** the JSON-RPC framing of Protocol 0 (kept only as a legacy accept-shim).

## 1. Decision (D11)

Protocol 0 payloads are **S-expressions**, dispatched on the **head symbol (car)**. The
first list element is the verb; the remaining elements are its arguments. No
`{"method":…,"params":…}` envelope. JSON is confined to external edges (mlx-router,
MCP, 3rd-party HTTP) — never internal yx payloads.

## 2. Wire

A Protocol-0 payload (the bytes after the yx GUID, inside the HMAC-authenticated packet)
is a single UTF-8 S-expression. A reader determines completeness by **paren depth = 0**
after a complete form — self-delimiting, no length prefix, no newline framing.

**Dispatch:** peek the first non-whitespace byte of the payload:
- `(`  → S-expression. Parse; dispatch on the car symbol to a registered handler.
- `{`  → **legacy** JSON-RPC (accept-shim; dispatch by `"method"`). Emitted by nothing new.

Senders emit only S-expressions.

## 3. S-expression grammar (the subset yx uses)

```
sexpr   := atom | list
list    := '(' ws? (sexpr (ws sexpr)*)? ws? ')'
atom    := symbol | string | number
symbol  := [A-Za-z][A-Za-z0-9._-]*           ; e.g. msg, node-hello, node/agent-id? -> use a string for slashes
string  := '"' ( [^"\\] | '\\' ["\\/nt] )* '"'   ; JSON-style escapes: \" \\ \/ \n \t
number  := '-'? [0-9]+ ( '.' [0-9]+ )?
ws      := (' ' | '\t' | '\n' | '\r')+
comment := ';;' ... end-of-line            ; allowed between tokens, ignored
```

- **Strings** carry any text (paths, prose, slugs like `"colossus/claude-1"`); symbols are
  bare identifiers used for verbs/keys/enums. When in doubt, quote it.
- **Round-trip:** parse→serialize→parse yields an equal tree. The serializer emits one
  space between siblings and no superfluous whitespace (a light canonical form; full
  canonical-csexp for signing is a later concern, ADR D12).

## 4. Core verbs (car-dispatch)

| Form | Meaning |
|---|---|
| `(node-hello (node "<id>") (agents "<csv>"))` | presence heartbeat (replaces JSON `node.hello`) |
| `(node-info)` | request node identity; reply is a `(node-info-reply …)` |
| `(node-info-reply (node "<id>") (agents "<csv>") (uptime <sec>))` | node.info answer |
| `(msg …)` | an agent message — see message-format.md |

Unknown car → ignored (logged at debug). Forward-compatible.

## 5. Migration / compatibility

- yx core gains an S-expr dispatch path alongside the JSON-RPC one (peek `(` vs `{`).
  `registerSexp(head, handler)` registers a car handler; `registerRPC(method, …)` remains
  for legacy consumers (e.g. sdts AlgoTrader) until they migrate.
- A brief dual-accept window: receivers accept both `(` and `{`; senders emit `(` only.
- `yxnode` uses S-expr exclusively and spools received `(msg …)` as `.sxp` (never UNF).

## 6. Verification

- V1: parser round-trips `(a (b "x y") (c 12) (d -3.5))`.
- V2: a node emits `(node-hello …)`, a peer parses+dispatches it (presence updates).
- V3: `(msg …)` delivered → `.sxp` file written; JSON `{…}` still accepted by the shim.
- V4: cross-machine (colossus↔laptop) node discovery + `(msg …)` both ways, pure S-expr.
