"""
Protocol 0: Text/JSON-RPC handler.

Traceability:
- protocol/specs/architecture/protocol-layers.md (Protocol 0 section)
- protocol/specs/technical/yx-protocol-spec.md (Protocol 0 wire format)
"""

import json
import logging
from typing import Optional, Callable, Awaitable, Dict, Any

from .protocol_router import ProtocolID
from ..rpc.json_rpc import RPCRequest

logger = logging.getLogger(__name__)


class TextProtocol:
    """
    Protocol 0 handler for text/JSON messages.

    Traceability:
    - protocol/specs/architecture/protocol-layers.md (Protocol 0)
    """

    def __init__(self, on_message: Optional[Callable[[Dict[str, Any]], Awaitable[None]]] = None):
        """
        Initialize text protocol handler.

        Args:
            on_message: Callback for received messages (async)
        """
        self._on_message = on_message
        self._send_api = None

    def install_send_api(self, send_fn: Callable[[bytes, str, int], Awaitable[None]]):
        """
        Install send function from transport layer.

        Args:
            send_fn: Async function(payload, host, port) that sends packet

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Handler Responsibilities)
        """
        self._send_api = send_fn

    async def handle(self, payload: bytes):
        """
        Process received Protocol 0 payload.

        Args:
            payload: Raw payload (starts with 0x00)

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Receive Path)
        """
        # Verify protocol ID
        if not payload or payload[0] != ProtocolID.TEXT:
            logger.error(f"Invalid protocol ID for text protocol: {payload[0] if payload else 'empty'}")
            return

        # Extract JSON payload (skip protocol ID byte)
        json_bytes = payload[1:]

        # Decode UTF-8
        try:
            json_str = json_bytes.decode('utf-8')
        except UnicodeDecodeError as e:
            logger.error(f"Failed to decode UTF-8: {e}")
            return

        # Parse JSON
        try:
            message = json.loads(json_str)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON: {e}")
            return

        logger.debug(f"Received text message: {message}")

        # Dispatch to callback
        if self._on_message:
            try:
                await self._on_message(message)
            except Exception as e:
                logger.exception(f"Error in message handler: {e}")

    async def send(
        self,
        message: Dict[str, Any],
        host: str,
        port: int
    ):
        """
        Send Protocol 0 message.

        Args:
            message: JSON-serializable dict
            host: Destination IP
            port: Destination port

        Traceability:
        - protocol/specs/architecture/protocol-layers.md (Send Path)
        """
        if self._send_api is None:
            raise RuntimeError("Send API not installed")

        # Encode as JSON
        json_str = json.dumps(message)
        json_bytes = json_str.encode('utf-8')

        # Check size (Protocol 0 is single packet)
        if len(json_bytes) > 1450:  # Conservative limit
            logger.warning(f"Message size {len(json_bytes)} bytes may exceed MTU")

        # Prepend protocol ID
        payload = bytes([ProtocolID.TEXT]) + json_bytes

        logger.debug(f"Sending text message to {host}:{port}")

        # Send via transport layer
        await self._send_api(payload, host, port)
