"""
Protocol router for dispatching packets by protocol ID

Matches Swift ProtocolID and ProtocolRouter implementation.
"""

from enum import IntEnum
from typing import Callable, Dict, Awaitable


class ProtocolID(IntEnum):
    """Protocol identifiers matching Swift implementation"""
    TEXT = 0x00  # Detected by first byte >= 32 (ASCII)
    BINARY = 0x01  # Binary protocol with chunking


class ProtocolRouter:
    """Route packets to protocol handlers based on protocol ID"""

    def __init__(self):
        """Initialize router with empty handler registry"""
        self.handlers: Dict[int, Callable[[bytes], Awaitable[None]]] = {}

    def register(self, protocol_id: int, handler: Callable[[bytes], Awaitable[None]]):
        """
        Register a protocol handler.

        Args:
            protocol_id: Protocol identifier
            handler: Async handler function
        """
        self.handlers[protocol_id] = handler

    async def route(self, payload: bytes):
        """
        Route payload to appropriate protocol handler.

        Args:
            payload: Packet payload (after HMAC + GUID)
        """
        if not payload:
            return

        # Detect protocol by first byte
        first_byte = payload[0]

        if first_byte < 32:
            # Binary protocol - first byte is protocol ID
            protocol_id = first_byte
        else:
            # Text protocol (ASCII/JSON)
            protocol_id = ProtocolID.TEXT

        # Dispatch to handler
        handler = self.handlers.get(protocol_id)
        if handler:
            await handler(payload)
