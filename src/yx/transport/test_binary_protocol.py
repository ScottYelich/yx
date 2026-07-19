"""Tests for Protocol 1 binary handler."""

import pytest
import struct
import os
from yx.transport.binary_protocol import BinaryProtocol, HEADER_FORMAT
from yx.transport.protocol_router import ProtocolID


@pytest.mark.asyncio
async def test_single_chunk():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    msg = b"Small message"
    header = struct.pack(HEADER_FORMAT, ProtocolID.BINARY, 0x00, 0, 0, 0, 1)
    await handler.handle(header + msg)
    assert received == [msg]


@pytest.mark.asyncio
async def test_multi_chunk():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    original = b"A" * 25
    chunks = [original[i:i+10] for i in range(0, 25, 10)]
    for i, chunk in enumerate(chunks):
        header = struct.pack(HEADER_FORMAT, ProtocolID.BINARY, 0x00, 0, 0, i, len(chunks))
        await handler.handle(header + chunk)
    assert received == [original]


@pytest.mark.asyncio
async def test_send_receive_compressed():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)
    original = b"Hello! " * 100
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x01)
    for p in sent:
        await handler.handle(p)
    assert received == [original]


@pytest.mark.asyncio
async def test_send_receive_encrypted():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)
    original = b"Secret!"
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x02)
    for p in sent:
        await handler.handle(p)
    assert received == [original]


@pytest.mark.asyncio
async def test_send_receive_both():
    key = os.urandom(32)
    received = []

    async def on_msg(data):
        received.append(data)

    handler = BinaryProtocol(key=key, on_message=on_msg)
    sent = []

    async def send_api(payload, host, port):
        sent.append(payload)

    handler.install_send_api(send_api)
    original = b"Secret! " * 100
    await handler.send(original, "127.0.0.1", 9999, proto_opts=0x03)
    for p in sent:
        await handler.handle(p)
    assert received == [original]
