"""
Text protocol (Protocol 0) handler

Handles JSON/text packets matching Swift Protocol0Actor.
"""

import asyncio
from typing import Callable, Awaitable, Optional
from ..primitives.json_utils import json_decode_bytes, json_encode_bytes
from ..primitives.logger import Logger

logger = Logger("TextProtocol")


class TextProtocol:
    """Protocol 0: Text/JSON message handler"""

    def __init__(self, on_message: Optional[Callable[[dict], Awaitable[None]]] = None):
        """
        Initialize text protocol handler.

        Args:
            on_message: Callback for received JSON messages
        """
        self.on_message = on_message

    async def handle(self, payload: bytes):
        """
        Handle text protocol payload.

        Args:
            payload: Raw payload (UTF-8 JSON)
        """
        try:
            # Decode JSON
            message = json_decode_bytes(payload)

            logger.info(f"Received text message: {message}")

            # Dispatch to handler
            if self.on_message:
                await self.on_message(message)

        except Exception as e:
            logger.error(f"Failed to handle text protocol: {e}")

    async def send(self, message: dict) -> bytes:
        """
        Encode message as text protocol payload.

        Args:
            message: JSON-serializable message

        Returns:
            bytes: Encoded payload
        """
        return json_encode_bytes(message)
