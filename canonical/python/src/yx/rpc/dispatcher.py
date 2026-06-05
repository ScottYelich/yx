"""
RPC dispatcher for method routing.

Traceability:
- specs/architecture/protocol-layers.md (Application Layer)
"""

from typing import Dict, Callable, Awaitable, Any
import logging
from .json_rpc import RPCRequest, RPCResponse

logger = logging.getLogger(__name__)


class RPCDispatcher:
    """
    Dispatches RPC requests to registered handlers.

    Traceability:
    - specs/architecture/api-contracts.md (RPC Dispatcher)
    """

    def __init__(self):
        self._handlers: Dict[str, Callable[[RPCRequest], Awaitable[None]]] = {}

    def register(
        self,
        method: str,
        handler: Callable[[RPCRequest], Awaitable[None]]
    ):
        """
        Register RPC method handler.

        Args:
            method: Method name (e.g., "task.hello")
            handler: Async function that processes request
        """
        self._handlers[method] = handler
        logger.info(f"Registered RPC handler: {method}")

    async def dispatch(self, request: RPCRequest):
        """
        Dispatch request to handler.

        Args:
            request: Parsed RPC request
        """
        handler = self._handlers.get(request.method)

        if handler is None:
            logger.warning(f"RPC method not found: {request.method}")
            return

        try:
            await handler(request)
        except Exception as e:
            logger.exception(f"Error in RPC handler '{request.method}': {e}")
