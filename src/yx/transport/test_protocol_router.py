"""
Tests for protocol router.

Traceability:
- protocol/specs/architecture/protocol-layers.md (Testing Requirements)
"""

import pytest
from yx.transport.protocol_router import ProtocolRouter, ProtocolID


@pytest.mark.asyncio
async def test_protocol_router_routes_text():
    """Test router dispatches Protocol 0 to text handler."""
    received = []

    async def text_handler(payload: bytes):
        received.append(payload)

    router = ProtocolRouter()
    router.register(ProtocolID.TEXT, text_handler)

    # Route text protocol payload
    payload = bytes([0x00]) + b"test"
    await router.route(payload)

    assert len(received) == 1
    assert received[0] == payload


@pytest.mark.asyncio
async def test_protocol_router_unknown_protocol():
    """Test router handles unknown protocol ID gracefully."""
    router = ProtocolRouter()

    # Should not raise, just log error
    payload = bytes([0xFF]) + b"test"
    await router.route(payload)


@pytest.mark.asyncio
async def test_protocol_router_empty_payload():
    """Test router handles empty payload."""
    router = ProtocolRouter()
    await router.route(b"")
