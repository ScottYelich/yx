import Foundation

/// Protocol 0: Text (JSON-RPC 2.0) handler
///
/// Wire format: [0x00] + [UTF-8 JSON]
actor TextProtocol {

    /// Protocol ID for Text protocol
    static let protocolID: UInt8 = 0x00

    private let dispatcher: RPCDispatcher
    private let onResponse: ((RPCResponse) async -> Void)?

    init(dispatcher: RPCDispatcher, onResponse: ((RPCResponse) async -> Void)? = nil) {
        self.dispatcher = dispatcher
        self.onResponse = onResponse
    }

    /// Handle incoming text protocol payload ([0x00] + JSON)
    func handle(payload: Data) async throws {
        guard !payload.isEmpty, payload[payload.startIndex] == Self.protocolID else {
            throw ProtocolError.invalidFormat("Expected protocol ID 0x00")
        }

        let jsonData = Data(payload.suffix(from: payload.startIndex + 1))
        let decoder = JSONDecoder()

        if let request = try? decoder.decode(RPCRequest.self, from: jsonData) {
            try await handleRequest(request)
            return
        }

        if let response = try? decoder.decode(RPCResponse.self, from: jsonData) {
            try await handleResponse(response)
            return
        }

        throw ProtocolError.decodingError("Could not decode as RPCRequest or RPCResponse")
    }

    private func handleRequest(_ request: RPCRequest) async throws {
        let response = await dispatcher.dispatch(request: request)
        if !request.isNotification, let onResponse = onResponse {
            await onResponse(response)
        }
    }

    private func handleResponse(_ response: RPCResponse) async throws {
        if let onResponse = onResponse {
            await onResponse(response)
        }
    }

    /// Encode RPC request to wire format ([0x00] + JSON)
    static func encodeRequest(_ request: RPCRequest) throws -> Data {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        var payload = Data(capacity: 1 + jsonData.count)
        payload.append(protocolID)
        payload.append(jsonData)

        return payload
    }

    /// Encode RPC response to wire format ([0x00] + JSON)
    static func encodeResponse(_ response: RPCResponse) throws -> Data {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(response)

        var payload = Data(capacity: 1 + jsonData.count)
        payload.append(protocolID)
        payload.append(jsonData)

        return payload
    }
}
