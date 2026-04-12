"""
Protocol Router - Dispatches packets to protocol handlers.

Traceability:
- protocol/specs/architecture/protocol-layers.md (Protocol Router section)
"""

from enum import IntEnum
from typing import Dict, Callable, Awaitable, Optional
import logging

logger = logging.getLogger(__name__)


class ProtocolID(IntEnum):
    """
    Protocol identifier byte (first byte of payload).

    Traceability:
    - protocol/specs/architecture/protocol-layers.md (Protocol ID Registry)
    """
    TEXT = 0x00     # Protocol 0: Text/JSON-RPC
    BINARY = 0x01   # Protocol 1: Binary/Chunked


class ProtocolRouter:
    """
    Routes validated payloads to appropriate protocol handler.

    Traceability:
    - protocol/specs/architecture/protocol-layers.md (Protocol Router)
    """

    def __init__(self):
        self._handlers: Dict[int, Callable[[bytes], Awaitable[None]]] = {}

    def register(
        self,
        protocol_id: int,
        handler: Callable[[bytes], Awaitable[None]]
    ):
        """
        Register protocol handler.

        Args:
            protocol_id: Protocol ID byte (e.g., 0x00 for text)
            handler: Async function that processes payload
        """
        self._handlers[protocol_id] = handler
        logger.info(f"Registered protocol handler for ID: 0x{protocol_id:02x}")

    async def route(self, payload: bytes):
        """
        Route payload to handler by protocol ID.

        Args:
            payload: Raw payload (first byte is protocol ID)
        """
        if not payload:
            logger.debug("Empty payload, ignoring")
            return

        protocol_id = payload[0]

        handler = self._handlers.get(protocol_id)
        if handler is None:
            logger.error(f"Unknown protocol ID: 0x{protocol_id:02x}")
            return

        try:
            await handler(payload)
        except Exception as e:
            logger.exception(f"Error in protocol handler 0x{protocol_id:02x}: {e}")
