r"""Protocol-0 S-expression value + reader + writer (ADR D11).

Python mirror of Sources/Primitives/SExpr.swift — behavior must match EXACTLY
(the canonical signing bytes of ADR D12 depend on it).
Spec: protocol/specs/technical/protocol0-sexpr.md

Grammar (the subset yx uses):
  sexpr   := atom | list
  list    := '(' ws? (sexpr (ws sexpr)*)? ws? ')'
  atom    := symbol | string | number
  symbol  := [A-Za-z][A-Za-z0-9._-]*
  string  := '"' ( [^"\\] | '\\' ["\\/nt] )* '"'   ; JSON-style escapes \" \\ \/ \n \t
  number  := '-'? [0-9]+ ( '.' [0-9]+ )?
  comment := ';;' ... end-of-line                  ; ignored between tokens

Round-trip guarantee: parse -> serialize -> parse yields an equal tree.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Tuple, Union

_WS = " \t\n\r"
_ASCII_LETTERS = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
_ASCII_DIGITS = frozenset("0123456789")
_SYM_CONT = _ASCII_LETTERS | _ASCII_DIGITS | frozenset("._-")


@dataclass(frozen=True)
class SExpr:
    """One S-expression node. kind is 'sym' | 'str' | 'num' | 'list'."""

    kind: str
    value: Union[str, float, Tuple["SExpr", ...]]

    # MARK: - Constructors

    @classmethod
    def sym(cls, name: str) -> "SExpr":
        return cls("sym", name)

    @classmethod
    def string(cls, s: str) -> "SExpr":
        return cls("str", s)

    @classmethod
    def num(cls, d: float) -> "SExpr":
        return cls("num", float(d))

    @classmethod
    def list_(cls, items) -> "SExpr":
        return cls("list", tuple(items))

    # MARK: - Reader

    @staticmethod
    def parse(text: str) -> Optional["SExpr"]:
        """Parse ONE balanced form from `text`. Completeness = paren depth back
        to 0. Leading whitespace/comments are skipped; trailing content is
        ignored. Returns None on malformed or incomplete input."""
        expr, _ = _parse_form(text, 0)
        return expr

    # MARK: - Writer

    def serialize(self) -> str:
        """One space between siblings, no superfluous whitespace (the light
        canonical form from the spec). Integral numbers WITHOUT `.0`."""
        if self.kind == "sym":
            return self.value
        if self.kind == "str":
            return '"' + _escape(self.value) + '"'
        if self.kind == "num":
            d = self.value
            if d == round(d) and abs(d) < 1e15:
                return str(int(d))
            return repr(d)
        # list
        return "(" + " ".join(item.serialize() for item in self.value) + ")"

    # MARK: - Ergonomic accessors for the (verb (key val) ...) shape

    @property
    def head(self) -> Optional[str]:
        """The car symbol of a list, e.g. `(msg ...)` -> "msg"."""
        if self.kind == "list" and self.value and self.value[0].kind == "sym":
            return self.value[0].value
        return None

    def field(self, name: str) -> Optional["SExpr"]:
        """The value of a `(key val)` child: the child list whose car symbol
        equals `name` -> its SECOND element."""
        if self.kind != "list":
            return None
        for item in self.value:
            if (item.kind == "list" and len(item.value) >= 2
                    and item.value[0].kind == "sym" and item.value[0].value == name):
                return item.value[1]
        return None

    @property
    def string_value(self) -> Optional[str]:
        return self.value if self.kind == "str" else None

    @property
    def sym_value(self) -> Optional[str]:
        return self.value if self.kind == "sym" else None

    @property
    def num_value(self) -> Optional[float]:
        return self.value if self.kind == "num" else None

    def __str__(self) -> str:
        return self.serialize()


# MARK: - Reader internals (mirror SExpr.swift character-for-character)

def _skip_ws(text: str, i: int) -> int:
    n = len(text)
    while i < n:
        c = text[i]
        if c in _WS:
            i += 1
        elif c == ";" and i + 1 < n and text[i + 1] == ";":
            while i < n and text[i] != "\n":
                i += 1
        else:
            break
    return i


def _parse_form(text: str, i: int):
    i = _skip_ws(text, i)
    if i >= len(text):
        return None, i
    c = text[i]
    if c == "(":
        i += 1
        items = []
        while True:
            i = _skip_ws(text, i)
            if i >= len(text):
                return None, i  # unbalanced — incomplete form
            if text[i] == ")":
                return SExpr.list_(items), i + 1
            item, i = _parse_form(text, i)
            if item is None:
                return None, i
            items.append(item)
    if c == '"':
        return _parse_string(text, i)
    if c == "-" or c in _ASCII_DIGITS:
        return _parse_number(text, i)
    if c in _ASCII_LETTERS:
        return _parse_symbol(text, i)
    return None, i


def _parse_string(text: str, i: int):
    i += 1  # opening quote
    n = len(text)
    out = []
    while i < n:
        c = text[i]
        if c == '"':
            return SExpr.string("".join(out)), i + 1
        if c == "\\":
            i += 1
            if i >= n:
                return None, i
            e = text[i]
            if e == '"':
                out.append('"')
            elif e == "\\":
                out.append("\\")
            elif e == "/":
                out.append("/")
            elif e == "n":
                out.append("\n")
            elif e == "t":
                out.append("\t")
            else:
                return None, i  # unknown escape
            i += 1
        else:
            out.append(c)
            i += 1
    return None, i  # unterminated string


def _parse_number(text: str, i: int):
    n = len(text)
    s = []
    if text[i] == "-":
        s.append("-")
        i += 1
    digits = 0
    while i < n and text[i] in _ASCII_DIGITS:
        s.append(text[i])
        i += 1
        digits += 1
    if digits == 0:
        return None, i  # bare '-' is not a number
    if i + 1 < n and text[i] == "." and text[i + 1] in _ASCII_DIGITS:
        s.append(".")
        i += 1
        while i < n and text[i] in _ASCII_DIGITS:
            s.append(text[i])
            i += 1
    try:
        return SExpr.num(float("".join(s))), i
    except ValueError:
        return None, i


def _parse_symbol(text: str, i: int):
    n = len(text)
    s = [text[i]]
    i += 1
    while i < n and text[i] in _SYM_CONT:
        s.append(text[i])
        i += 1
    return SExpr.sym("".join(s)), i


def _escape(s: str) -> str:
    out = []
    for c in s:
        if c == '"':
            out.append('\\"')
        elif c == "\\":
            out.append("\\\\")
        elif c == "\n":
            out.append("\\n")
        elif c == "\t":
            out.append("\\t")
        else:
            out.append(c)
    return "".join(out)
