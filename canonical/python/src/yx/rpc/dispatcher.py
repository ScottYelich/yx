"""
RPC dispatcher for method routing.

Traceability:
- protocol/specs/architecture/api-contracts.md (RPC Dispatcher)
"""

from typing import Dict, Callable, Awaitable, Any
import logging
from .json_rpc import RPCRequest, RPCResponse

logger = logging.getLogger(__name__)


class RPCDispatcher:
    """
    Dispatches RPC requests to registered handlers.

    Traceability:
    - protocol/specs/architecture/api-contracts.md (RPC Dispatcher)
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

    async def dispatch(self, request: RPCRequest) -> Optional[RPCResponse]:
        """
        Dispatch request to handler.

        Args:
            request: Parsed RPC request

        Returns:
            RPCResponse if handler returns one, None otherwise
        """
        handler = self._handlers.get(request.method)

        if handler is None:
            logger.warning(f"RPC method not found: {request.method}")
            return request.reply_error(-32601, "Method not found")

        try:
            result = await handler(request)
            if result is None:
                # Handler didn't return a response, create success with None
                return request.reply(None)
            return result
        except Exception as e:
            logger.exception(f"Error in RPC handler '{request.method}': {e}")
            return request.reply_error(-32000, f"Internal error: {str(e)}")
