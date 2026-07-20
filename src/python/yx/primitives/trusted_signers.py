"""Trusted-signers store — ADR D12 / signing.md §2.

Python mirror of Sources/Primitives/TrustedSigners.swift.

`~/.config/yx/trusted-signers.sxp`:
  (trusted-signers
    (signer (id "colossus/claude-1") (key "<base64-ed25519-pubkey>"))
    ...)

A signer in this set is trusted for AUTHORITY (command/order execution).
Missing file => empty map => nothing trusted (chat still open to the mesh).
"""

from __future__ import annotations

import os
from typing import Dict, Optional

from .sexpr import SExpr


def default_path() -> str:
    """Default store path: ~/.config/yx/trusted-signers.sxp"""
    return os.path.expanduser("~/.config/yx/trusted-signers.sxp")


def load(path: Optional[str] = None) -> Dict[str, str]:
    """Load the store -> {agent_id: pubkey_b64}. Missing/unreadable/malformed
    file => empty (nothing trusted)."""
    p = path if path is not None else default_path()
    try:
        with open(p, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return {}
    return parse(text)


def parse(text: str) -> Dict[str, str]:
    """Parse the (trusted-signers ...) form from text (exposed for tests)."""
    expr = SExpr.parse(text)
    if expr is None or expr.head != "trusted-signers" or expr.kind != "list":
        return {}
    out: Dict[str, str] = {}
    for item in expr.value[1:]:
        if item.head != "signer":
            continue
        id_f = item.field("id")
        key_f = item.field("key")
        agent_id = id_f.string_value if id_f is not None else None
        key = key_f.string_value if key_f is not None else None
        if agent_id and key:
            out[agent_id] = key
    return out
