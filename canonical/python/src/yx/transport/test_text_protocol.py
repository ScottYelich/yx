"""
Tests for Protocol 0 (text) handler.

Traceability:
- specs/architecture/protocol-layers.md (Protocol 0 Tests)
"""

import pytest
import json
from yx.transport.text_protocol import TextProtocol
from yx.transport.protocol_router import ProtocolID


@pytest.mark.asyncio
async def test_text_protocol_receive_json():
    """Test Protocol 0 receives and parses JSON."""
    received = []

    async def on_message(msg):
        received.append(msg)

    handler = TextProtocol(on_message=on_message)

    # Create Protocol 0 payload
    message = {"method": "test", "params": {"value": 42}}
    json_bytes = json.dumps(message).encode('utf-8')
    payload = bytes([ProtocolID.TEXT]) + json_bytes

    await handler.handle(payload)

    assert len(received) == 1
    assert received[0] == message


@pytest.mark.asyncio
async def test_text_protocol_send_json():
    """Test Protocol 0 sends JSON with protocol ID."""
    sent = []

    async def send_api(payload, host, port):
        sent.append((payload, host, port))

    handler = TextProtocol()
    handler.install_send_api(send_api)

    message = {"method": "test", "params": {"value": 42}}
    await handler.send(message, "127.0.0.1", 9999)

    assert len(sent) == 1
    payload, host, port = sent[0]

    # Verify protocol ID
    assert payload[0] == ProtocolID.TEXT

    # Verify JSON content
    json_bytes = payload[1:]
    parsed = json.loads(json_bytes.decode('utf-8'))
    assert parsed == message


@pytest.mark.asyncio
async def test_text_protocol_invalid_json():
    """Test Protocol 0 handles invalid JSON gracefully."""
    received = []

    async def on_message(msg):
        received.append(msg)

    handler = TextProtocol(on_message=on_message)

    # Invalid JSON
    payload = bytes([ProtocolID.TEXT]) + b"{invalid json}"

    # Should not raise, just log error
    await handler.handle(payload)

    assert len(received) == 0


@pytest.mark.asyncio
async def test_text_protocol_invalid_utf8():
    """Test Protocol 0 handles invalid UTF-8 gracefully."""
    received = []

    async def on_message(msg):
        received.append(msg)

    handler = TextProtocol(on_message=on_message)

    # Invalid UTF-8
    payload = bytes([ProtocolID.TEXT]) + bytes([0xFF, 0xFE])

    # Should not raise, just log error
    await handler.handle(payload)

    assert len(received) == 0


@pytest.mark.asyncio
async def test_text_protocol_large_message():
    """Test Protocol 0 warns on large messages."""
    handler = TextProtocol()

    async def send_api(payload, host, port):
        pass

    handler.install_send_api(send_api)

    # Large message (>1450 bytes)
    large_message = {"data": "X" * 2000}

    # Should send but log warning
    await handler.send(large_message, "127.0.0.1", 9999)
