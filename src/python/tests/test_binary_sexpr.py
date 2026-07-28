"""ADR-014 (sdts): binary Protocol-1 payloads whose content is an
S-expression route to on_sexpr (head-symbol dispatch), not the JSON path.
Compression is transport, not format."""

import asyncio

import pytest

from yx.transport.binary_protocol import BinaryProtocol
from yx.primitives.sexpr import SExpr

KEY = bytes.fromhex(
    "D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD")


def _run(coro):
    return asyncio.run(coro)


def _feed(proto: BinaryProtocol, content: bytes, compress: bool):
    async def go():
        packets = await proto.send(
            content,
            proto_opts=BinaryProtocol.PROTO_OPTS_COMPRESS if compress else 0)
        for pkt in packets:
            await proto.handle(pkt)
    _run(go())


class TestBinarySexpr:
    def test_compressed_sexpr_routes_to_on_sexpr(self):
        proto = BinaryProtocol(KEY)
        got = []

        async def on_sexpr(expr):
            got.append(expr)

        async def on_message(msg):  # must NOT be called
            got.append(("json", msg))

        proto.on_sexpr = on_sexpr
        proto.on_message = on_message

        wire = ('(reply (to "req-1") (result ((success true) '
                '(orders (((order_id 1005) (status "Submitted")))))))')
        _feed(proto, wire.encode(), compress=True)

        assert len(got) == 1
        expr = got[0]
        assert isinstance(expr, SExpr) and expr.head == "reply"
        to = expr.field("to")
        assert to is not None and to.string_value == "req-1"

    def test_json_still_routes_to_on_message(self):
        proto = BinaryProtocol(KEY)
        got = []

        async def on_sexpr(expr):
            got.append(("sexpr", expr))

        async def on_message(msg):
            got.append(("json", msg))

        proto.on_sexpr = on_sexpr
        proto.on_message = on_message

        _feed(proto, b'{"method": "_response", "params": {"x": 1}}',
              compress=True)

        assert got and got[0][0] == "json"
        assert got[0][1]["method"] == "_response"

    def test_large_multichunk_sexpr(self):
        proto = BinaryProtocol(KEY, chunk_size=256)
        got = []

        async def on_sexpr(expr):
            got.append(expr)

        proto.on_sexpr = on_sexpr
        rows = " ".join(
            f'((order_id {i}) (symbol "ES") (status "Filled"))'
            for i in range(200))
        wire = f'(reply (to "big-1") (result ((orders ({rows})))))'
        _feed(proto, wire.encode(), compress=True)

        assert len(got) == 1 and got[0].head == "reply"
