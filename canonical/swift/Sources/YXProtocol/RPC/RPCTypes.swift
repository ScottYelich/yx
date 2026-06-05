import Foundation

/// JSON-RPC 2.0 Request
///
/// Specification: https://www.jsonrpc.org/specification
struct RPCRequest: Codable, Equatable, Sendable {
    let jsonrpc: String
    let method: String
    let params: AnyCodable?
    let id: AnyCodable?

    init(method: String, params: AnyCodable? = nil, id: AnyCodable? = nil) {
        self.jsonrpc = "2.0"
        self.method = method
        self.params = params
        self.id = id
    }

    /// Check if this is a notification (no response expected)
    var isNotification: Bool {
        return id == nil
    }
}

/// JSON-RPC 2.0 Response
struct RPCResponse: Codable, Equatable, Sendable {
    let jsonrpc: String
    let result: AnyCodable?
    let error: RPCError?
    let id: AnyCodable?

    static func success(result: AnyCodable, id: AnyCodable) -> RPCResponse {
        return RPCResponse(jsonrpc: "2.0", result: result, error: nil, id: id)
    }

    static func failure(error: RPCError, id: AnyCodable?) -> RPCResponse {
        return RPCResponse(jsonrpc: "2.0", result: nil, error: error, id: id)
    }
}

/// JSON-RPC 2.0 Error
struct RPCError: Codable, Equatable, Sendable {
    let code: Int
    let message: String
    let data: AnyCodable?

    static let parseError = RPCError(code: -32700, message: "Parse error", data: nil)
    static let invalidRequest = RPCError(code: -32600, message: "Invalid request", data: nil)
    static let methodNotFound = RPCError(code: -32601, message: "Method not found", data: nil)
    static let invalidParams = RPCError(code: -32602, message: "Invalid params", data: nil)
    static let internalError = RPCError(code: -32603, message: "Internal error", data: nil)
}

/// Type-erased Codable wrapper for JSON values
///
/// Supports: String, Int, Double, Bool, Array, Dictionary, nil
struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    let value: Any?

    init(_ value: Any?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = nil
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case nil:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            throw EncodingError.invalidValue(value as Any, context)
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil):
            return true
        case (let l as Bool, let r as Bool):
            return l == r
        case (let l as Int, let r as Int):
            return l == r
        case (let l as Double, let r as Double):
            return l == r
        case (let l as String, let r as String):
            return l == r
        default:
            return false
        }
    }
}
