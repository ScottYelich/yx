"""
Text protocol (Protocol 0) handler

Protocol-0 dispatch (ADR D11), matching Swift RPCSystem.handle:
peek the first non-whitespace byte —
  `(` -> S-expression; parse and dispatch on the car (head) symbol.
  `{` -> legacy JSON-RPC (accept-shim).
Senders emit only S-expressions; the JSON path remains for legacy consumers.
"""

import asyncio
from typing import Callable, Awaitable, Dict, Optional
from ..primitives.json_utils import json_decode_bytes, json_encode_bytes
from ..primitives.sexpr import SExpr
from ..primitives.logger import Logger

logger = Logger("TextProtocol")

_WS_BYTES = frozenset((0x20, 0x09, 0x0A, 0x0D))


class TextProtocol:
    """Protocol 0: text handler — S-expression car-dispatch + legacy JSON"""

    def __init__(self, on_message: Optional[Callable[[dict], Awaitable[None]]] = None):
        """
        Initialize text protocol handler.

        Args:
            on_message: Callback for received (legacy) JSON messages
        """
        self.on_message = on_message
        # S-expression car-dispatch table (ADR D11): head symbol -> handler.
        self.sexp_handlers: Dict[str, Callable[[SExpr], Awaitable[None]]] = {}

    def register_sexp(self, head: str, handler: Callable[[SExpr], Awaitable[None]]):
        """Register an S-expression handler for a car (head) symbol (ADR D11)."""
        self.sexp_handlers[head] = handler

    async def handle(self, payload: bytes):
        """
        Handle text protocol payload.

        Args:
            payload: Raw payload (UTF-8 s-expression, or legacy JSON)
        """
        # S-expression path: first non-whitespace byte is '('
        first = next((b for b in payload if b not in _WS_BYTES), None)
        if first == ord("("):
            try:
                text = payload.decode("utf-8")
            except UnicodeDecodeError:
                logger.warning("Malformed S-expression payload (not UTF-8)")
                return
            expr = SExpr.parse(text)
            head = expr.head if expr is not None else None
            if expr is None or head is None:
                logger.warning("Malformed S-expression payload")
                return
            handler = self.sexp_handlers.get(head)
            if handler:
                await handler(expr)
            else:
                logger.info(f"No S-expr handler for '{head}' — ignored")
            return

        # Legacy JSON path
        try:
            message = json_decode_bytes(payload)
            preview = str(message)
            if len(preview) > 300:
                preview = preview[:300] + f"… (+{len(preview) - 300} chars)"
            logger.info(f"Received text message: {preview}")
            if self.on_message:
                await self.on_message(message)
        except Exception as e:
            logger.error(f"Failed to handle text protocol: {e}")

    async def send(self, message: dict) -> bytes:
        """
        Encode message as (legacy JSON) text protocol payload.

        Args:
            message: JSON-serializable message

        Returns:
            bytes: Encoded payload
        """
        return json_encode_bytes(message)
