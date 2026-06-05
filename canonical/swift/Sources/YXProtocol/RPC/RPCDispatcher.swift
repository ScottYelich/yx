import Foundation

/// RPC method handler function type
typealias RPCHandler = (AnyCodable?) async throws -> AnyCodable

/// Dispatches RPC requests to registered method handlers
actor RPCDispatcher {

    private var handlers: [String: RPCHandler] = [:]

    /// Register an RPC method handler
    func register(method: String, handler: @escaping RPCHandler) {
        handlers[method] = handler
    }

    /// Dispatch RPC request to appropriate handler
    func dispatch(request: RPCRequest) async -> RPCResponse {
        guard let requestID = request.id else {
            await dispatchNotification(request: request)
            return RPCResponse(jsonrpc: "2.0", result: nil, error: nil, id: nil)
        }

        guard let handler = handlers[request.method] else {
            return RPCResponse.failure(error: .methodNotFound, id: requestID)
        }

        do {
            let result = try await handler(request.params)
            return RPCResponse.success(result: result, id: requestID)
        } catch {
            let rpcError = RPCError(
                code: -32603,
                message: "Internal error",
                data: AnyCodable(error.localizedDescription)
            )
            return RPCResponse.failure(error: rpcError, id: requestID)
        }
    }

    private func dispatchNotification(request: RPCRequest) async {
        guard let handler = handlers[request.method] else {
            return
        }
        _ = try? await handler(request.params)
    }

    /// Get registered method names
    func registeredMethods() -> [String] {
        return Array(handlers.keys).sorted()
    }
}
