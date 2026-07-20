"""Canonical signing bytes for a (msg ...) — ADR D12.

Python mirror of Sources/Primitives/SExprSign.swift.
Spec: protocol/specs/technical/signing.md §3.

The canonical form MUST be byte-identical across the Swift and Python
implementations: `(msg` + child fields sorted ascending by the child's head
symbol (raw UTF-8 byte order, NOT locale/Unicode collation), each serialized
by the standard SExpr writer (single spaces, standard escapes, integral
numbers without `.0`), + `)`. Any existing (sig ...) child is dropped;
(key-id ...) is KEPT so the signer identity is bound into the signature.
UTF-8 encoded.
"""

from __future__ import annotations

from .sexpr import SExpr


def canonical_msg_bytes(msg: SExpr) -> bytes:
    """Canonical byte string of a `(msg ...)` for signing/verification (D12 §3).

    Deterministic: independent of the original field order and of any
    attached `(sig ...)`.
    """
    if msg.kind != "list" or not msg.value:
        return msg.serialize().encode("utf-8")
    head = msg.head or "msg"
    # Child fields, excluding the head symbol and any (sig ...). KEEP (key-id ...).
    fields = [f for f in msg.value[1:] if f.head != "sig"]
    # Sort ascending by the child's head symbol, comparing raw UTF-8 bytes.
    # (Python's sort is stable, matching the Swift index tiebreak for
    # duplicate heads.)
    fields.sort(key=lambda f: (f.head if f.head is not None else f.serialize()).encode("utf-8"))
    out = "(" + head
    for f in fields:
        out += " " + f.serialize()
    out += ")"
    return out.encode("utf-8")
