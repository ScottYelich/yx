# YBS Step 11 (Swift): Protocol 0 (Text/JSON-RPC)

**Step ID:** `ybs-step_g1h2i3j4k5l6`
**Language:** Swift
**System:** YX Protocol
**Focus:** Protocol 0 (Text/JSON-RPC 2.0) implementation

## Prerequisites

- ✅ Steps 1-10 completed (core transport layer)
- ✅ Python Step 11 completed (reference implementation)
- ✅ Specifications: `specs/architecture/protocol-layers.md`
- ✅ Specifications: `specs/architecture/api-contracts.md`

## Overview

Implement **Protocol 0** (Text/JSON-RPC 2.0) for YX protocol, enabling JSON-based RPC communication over UDP with HMAC authentication.

**Wire Format:**
```
[HMAC(16)] + [GUID(6)] + [0x00] + [UTF-8 JSON]
```

**Protocol Stack:**
```
Application Layer (RPC Methods)
        ↓
    RPCDispatcher
        ↓
   TextProtocol (Protocol 0)
        ↓
  ProtocolRouter (0x00 → TextProtocol)
        ↓
  TransportLayer (HMAC + GUID)
        ↓
      UDP Socket
```

## Traceability

**Specifications:**
- `specs/architecture/protocol-layers.md` § Protocol 0 (Text)
- `specs/technical/yx-protocol-spec.md` § Wire Format
- `specs/architecture/api-contracts.md` § RPC API

**Gaps Addressed:**
- Gap 1.1: Protocol 0 implementation
- Gap 1.3: JSON-RPC 2.0 support
- Gap 4.1: RPC request/response types
- Gap 4.2: RPC dispatcher

**SDTS Lessons:**
- SDTS Issue #4: Handle missing/nil JSON fields correctly
- Proof-based development: Test → Implement → Verify

## Build Instructions

### 1. Create Protocol Router

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/ProtocolRouter.swift`

```swift
import Foundation

/// Routes incoming payloads to protocol-specific handlers based on protocol ID
///
/// Protocol IDs:
/// - 0x00: Text (JSON-RPC 2.0)
/// - 0x01: Binary (Chunked with compression/encryption)
actor ProtocolRouter {

    /// Protocol handler function type
    typealias ProtocolHandler = (Data) async throws -> Void

    /// Registered protocol handlers
    private var handlers: [UInt8: ProtocolHandler] = [:]

    /// Register a protocol handler
    /// - Parameters:
    ///   - protocolID: Protocol identifier (0x00, 0x01, etc.)
    ///   - handler: Async handler function
    func register(protocolID: UInt8, handler: @escaping ProtocolHandler) {
        handlers[protocolID] = handler
    }

    /// Route payload to appropriate protocol handler
    /// - Parameter payload: Payload with protocol ID prefix
    /// - Throws: ProtocolError if protocol not supported or payload invalid
    func route(payload: Data) async throws {
        guard !payload.isEmpty else {
            throw ProtocolError.emptyPayload
        }

        let protocolID = payload[0]

        guard let handler = handlers[protocolID] else {
            throw ProtocolError.unsupportedProtocol(protocolID)
        }

        try await handler(payload)
    }

    /// Get registered protocol IDs
    func registeredProtocols() -> [UInt8] {
        return Array(handlers.keys).sorted()
    }
}

/// Protocol routing errors
enum ProtocolError: Error, CustomStringConvertible {
    case emptyPayload
    case unsupportedProtocol(UInt8)
    case invalidFormat(String)
    case encodingError(String)
    case decodingError(String)

    var description: String {
        switch self {
        case .emptyPayload:
            return "Empty payload"
        case .unsupportedProtocol(let id):
            return "Unsupported protocol: 0x\(String(format: "%02X", id))"
        case .invalidFormat(let msg):
            return "Invalid format: \(msg)"
        case .encodingError(let msg):
            return "Encoding error: \(msg)"
        case .decodingError(let msg):
            return "Decoding error: \(msg)"
        }
    }
}
```

**Key Design:**
- Actor for thread-safe handler registration
- Dictionary-based routing (O(1) lookup)
- Protocol ID is first byte of payload
- Async handlers for concurrent processing

### 2. Create RPC Types

**File:** `Sources/{{CONFIG:swift_module_name}}/RPC/RPCTypes.swift`

```swift
import Foundation

/// JSON-RPC 2.0 Request
///
/// Specification: https://www.jsonrpc.org/specification
struct RPCRequest: Codable, Equatable, Sendable {
    /// JSON-RPC version (must be "2.0")
    let jsonrpc: String

    /// Method name
    let method: String

    /// Parameters (optional)
    let params: AnyCodable?

    /// Request ID (optional for notifications)
    let id: AnyCodable?

    /// Create RPC request
    /// - Parameters:
    ///   - method: Method name
    ///   - params: Parameters (optional)
    ///   - id: Request ID (optional, omit for notifications)
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
    /// JSON-RPC version (must be "2.0")
    let jsonrpc: String

    /// Result (present on success)
    let result: AnyCodable?

    /// Error (present on failure)
    let error: RPCError?

    /// Request ID (matches request)
    let id: AnyCodable?

    /// Create success response
    /// - Parameters:
    ///   - result: Result value
    ///   - id: Request ID
    static func success(result: AnyCodable, id: AnyCodable) -> RPCResponse {
        return RPCResponse(jsonrpc: "2.0", result: result, error: nil, id: id)
    }

    /// Create error response
    /// - Parameters:
    ///   - error: Error details
    ///   - id: Request ID
    static func failure(error: RPCError, id: AnyCodable?) -> RPCResponse {
        return RPCResponse(jsonrpc: "2.0", result: nil, error: error, id: id)
    }
}

/// JSON-RPC 2.0 Error
struct RPCError: Codable, Equatable, Sendable {
    /// Error code
    let code: Int

    /// Error message
    let message: String

    /// Additional error data (optional)
    let data: AnyCodable?

    /// Standard error codes
    static let parseError = RPCError(code: -32700, message: "Parse error", data: nil)
    static let invalidRequest = RPCError(code: -32600, message: "Invalid request", data: nil)
    static let methodNotFound = RPCError(code: -32601, message: "Method not found", data: nil)
    static let invalidParams = RPCError(code: -32602, message: "Invalid params", data: nil)
    static let internalError = RPCError(code: -32603, message: "Internal error", data: nil)
}

/// Type-erased Codable wrapper for JSON values
///
/// Supports: String, Int, Double, Bool, Array, Dictionary, nil
struct AnyCodable: Codable, Equatable, Sendable {
    let value: Any?

    init(_ value: Any?) {
        self.value = value
    }

    // Codable implementation
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

    // Equatable implementation
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
```

**Key Design:**
- Fully compliant JSON-RPC 2.0 types
- `AnyCodable` for dynamic JSON values
- `Sendable` conformance for actor safety
- Standard error codes defined
- Notification support (id == nil)

**SDTS Issue #4 Protection:**
- AnyCodable handles nil values correctly
- No use of dictionary.get() with nil confusion

### 3. Create Text Protocol Handler

**File:** `Sources/{{CONFIG:swift_module_name}}/Transport/TextProtocol.swift`

```swift
import Foundation

/// Protocol 0: Text (JSON-RPC 2.0) handler
///
/// Wire format: [0x00] + [UTF-8 JSON]
actor TextProtocol {

    /// Protocol ID for Text protocol
    static let protocolID: UInt8 = 0x00

    /// RPC dispatcher for handling requests
    private let dispatcher: RPCDispatcher

    /// Message handler for responses
    private let onResponse: ((RPCResponse) async -> Void)?

    /// Initialize text protocol handler
    /// - Parameters:
    ///   - dispatcher: RPC dispatcher for handling requests
    ///   - onResponse: Optional response handler
    init(dispatcher: RPCDispatcher, onResponse: ((RPCResponse) async -> Void)? = nil) {
        self.dispatcher = dispatcher
        self.onResponse = onResponse
    }

    /// Handle incoming text protocol payload
    /// - Parameter payload: Payload with 0x00 prefix + JSON
    func handle(payload: Data) async throws {
        // Verify protocol ID
        guard !payload.isEmpty, payload[0] == Self.protocolID else {
            throw ProtocolError.invalidFormat("Expected protocol ID 0x00")
        }

        // Extract JSON bytes (skip first byte)
        let jsonData = payload.suffix(from: 1)

        // Decode JSON
        let decoder = JSONDecoder()

        // Try to decode as request first
        if let request = try? decoder.decode(RPCRequest.self, from: jsonData) {
            try await handleRequest(request)
            return
        }

        // Try to decode as response
        if let response = try? decoder.decode(RPCResponse.self, from: jsonData) {
            try await handleResponse(response)
            return
        }

        // Neither request nor response - invalid
        throw ProtocolError.decodingError("Could not decode as RPCRequest or RPCResponse")
    }

    /// Handle RPC request
    private func handleRequest(_ request: RPCRequest) async throws {
        // Dispatch to RPC handler
        let response = await dispatcher.dispatch(request: request)

        // Send response if not a notification
        if !request.isNotification, let onResponse = onResponse {
            await onResponse(response)
        }
    }

    /// Handle RPC response
    private func handleResponse(_ response: RPCResponse) async throws {
        // Forward to response handler
        if let onResponse = onResponse {
            await onResponse(response)
        }
    }

    /// Encode RPC request to wire format
    /// - Parameter request: RPC request
    /// - Returns: Wire format data ([0x00] + JSON)
    static func encodeRequest(_ request: RPCRequest) throws -> Data {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)

        var payload = Data(capacity: 1 + jsonData.count)
        payload.append(protocolID)
        payload.append(jsonData)

        return payload
    }

    /// Encode RPC response to wire format
    /// - Parameter response: RPC response
    /// - Returns: Wire format data ([0x00] + JSON)
    static func encodeResponse(_ response: RPCResponse) throws -> Data {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(response)

        var payload = Data(capacity: 1 + jsonData.count)
        payload.append(protocolID)
        payload.append(jsonData)

        return payload
    }
}
```

**Key Design:**
- Actor for thread-safe message handling
- Automatic request vs response detection
- JSON-RPC 2.0 compliant encoding/decoding
- Notification support (no response for id == nil)

### 4. Create RPC Dispatcher

**File:** `Sources/{{CONFIG:swift_module_name}}/RPC/RPCDispatcher.swift`

```swift
import Foundation

/// RPC method handler function type
typealias RPCHandler = (AnyCodable?) async throws -> AnyCodable

/// Dispatches RPC requests to registered method handlers
actor RPCDispatcher {

    /// Registered RPC method handlers
    private var handlers: [String: RPCHandler] = [:]

    /// Register an RPC method handler
    /// - Parameters:
    ///   - method: Method name (e.g., "test.echo")
    ///   - handler: Async handler function
    func register(method: String, handler: @escaping RPCHandler) {
        handlers[method] = handler
    }

    /// Dispatch RPC request to appropriate handler
    /// - Parameter request: RPC request
    /// - Returns: RPC response (success or error)
    func dispatch(request: RPCRequest) async -> RPCResponse {
        // Validate request ID exists (unless notification)
        guard let requestID = request.id else {
            // Notification - dispatch but don't return response
            await dispatchNotification(request: request)
            // Return dummy response (won't be sent)
            return RPCResponse(jsonrpc: "2.0", result: nil, error: nil, id: nil)
        }

        // Look up handler
        guard let handler = handlers[request.method] else {
            return RPCResponse.failure(error: .methodNotFound, id: requestID)
        }

        // Execute handler
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

    /// Dispatch notification (no response expected)
    private func dispatchNotification(request: RPCRequest) async {
        guard let handler = handlers[request.method] else {
            // Silently ignore unknown notification methods
            return
        }

        // Execute handler (ignore result)
        _ = try? await handler(request.params)
    }

    /// Get registered method names
    func registeredMethods() -> [String] {
        return Array(handlers.keys).sorted()
    }
}
```

**Key Design:**
- Actor for thread-safe handler registration
- Dictionary-based dispatch (O(1) lookup)
- Automatic error handling and response generation
- Notification support (no response for id == nil)

## Verification

### Unit Tests

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Transport/ProtocolRouterTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class ProtocolRouterTests: XCTestCase {

    func testRegisterAndRoute() async throws {
        let router = ProtocolRouter()
        var handled = false

        // Register handler for protocol 0x00
        await router.register(protocolID: 0x00) { payload in
            XCTAssertEqual(payload[0], 0x00)
            handled = true
        }

        // Route payload
        let payload = Data([0x00, 0x01, 0x02])
        try await router.route(payload: payload)

        XCTAssertTrue(handled)
    }

    func testUnsupportedProtocol() async {
        let router = ProtocolRouter()

        let payload = Data([0xFF, 0x01, 0x02])

        do {
            try await router.route(payload: payload)
            XCTFail("Should throw unsupportedProtocol error")
        } catch let error as ProtocolError {
            if case .unsupportedProtocol(let id) = error {
                XCTAssertEqual(id, 0xFF)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func testEmptyPayload() async {
        let router = ProtocolRouter()

        do {
            try await router.route(payload: Data())
            XCTFail("Should throw emptyPayload error")
        } catch let error as ProtocolError {
            if case .emptyPayload = error {
                // Expected
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/RPC/RPCTypesTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class RPCTypesTests: XCTestCase {

    func testRPCRequestEncoding() throws {
        let request = RPCRequest(
            method: "test.echo",
            params: AnyCodable(["message": "hello"]),
            id: AnyCodable(1)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RPCRequest.self, from: data)

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.method, "test.echo")
        XCTAssertEqual(decoded.id, AnyCodable(1))
    }

    func testRPCRequestNotification() {
        let request = RPCRequest(method: "test.notify", params: nil, id: nil)
        XCTAssertTrue(request.isNotification)

        let request2 = RPCRequest(method: "test.call", params: nil, id: AnyCodable(1))
        XCTAssertFalse(request2.isNotification)
    }

    func testRPCResponseSuccess() throws {
        let response = RPCResponse.success(result: AnyCodable("ok"), id: AnyCodable(1))

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.result, AnyCodable("ok"))
        XCTAssertNil(response.error)
        XCTAssertEqual(response.id, AnyCodable(1))
    }

    func testRPCResponseError() {
        let response = RPCResponse.failure(error: .methodNotFound, id: AnyCodable(1))

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32601)
        XCTAssertEqual(response.id, AnyCodable(1))
    }

    func testAnyCodableTypes() throws {
        let values: [(Any?, AnyCodable)] = [
            (nil, AnyCodable(nil)),
            (true, AnyCodable(true)),
            (42, AnyCodable(42)),
            (3.14, AnyCodable(3.14)),
            ("hello", AnyCodable("hello"))
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for (_, original) in values {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AnyCodable.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/Transport/TextProtocolTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class TextProtocolTests: XCTestCase {

    func testEncodeRequest() throws {
        let request = RPCRequest(
            method: "test.echo",
            params: AnyCodable(["message": "hello"]),
            id: AnyCodable(1)
        )

        let payload = try TextProtocol.encodeRequest(request)

        // Check protocol ID
        XCTAssertEqual(payload[0], 0x00)

        // Decode JSON
        let jsonData = payload.suffix(from: 1)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RPCRequest.self, from: jsonData)

        XCTAssertEqual(decoded.method, "test.echo")
        XCTAssertEqual(decoded.id, AnyCodable(1))
    }

    func testEncodeResponse() throws {
        let response = RPCResponse.success(result: AnyCodable("ok"), id: AnyCodable(1))

        let payload = try TextProtocol.encodeResponse(response)

        // Check protocol ID
        XCTAssertEqual(payload[0], 0x00)

        // Decode JSON
        let jsonData = payload.suffix(from: 1)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RPCResponse.self, from: jsonData)

        XCTAssertEqual(decoded.result, AnyCodable("ok"))
        XCTAssertEqual(decoded.id, AnyCodable(1))
    }

    func testHandleRequest() async throws {
        let dispatcher = RPCDispatcher()
        await dispatcher.register(method: "test.echo") { params in
            return params ?? AnyCodable(nil)
        }

        var capturedResponse: RPCResponse?
        let textProtocol = TextProtocol(dispatcher: dispatcher) { response in
            capturedResponse = response
        }

        // Create request
        let request = RPCRequest(
            method: "test.echo",
            params: AnyCodable("hello"),
            id: AnyCodable(1)
        )
        let payload = try TextProtocol.encodeRequest(request)

        // Handle request
        try await textProtocol.handle(payload: payload)

        // Verify response
        XCTAssertNotNil(capturedResponse)
        XCTAssertEqual(capturedResponse?.result, AnyCodable("hello"))
        XCTAssertEqual(capturedResponse?.id, AnyCodable(1))
    }
}
```

Create tests in `Tests/{{CONFIG:swift_module_name}}Tests/RPC/RPCDispatcherTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class RPCDispatcherTests: XCTestCase {

    func testRegisterAndDispatch() async throws {
        let dispatcher = RPCDispatcher()

        // Register echo method
        await dispatcher.register(method: "test.echo") { params in
            return params ?? AnyCodable(nil)
        }

        // Dispatch request
        let request = RPCRequest(
            method: "test.echo",
            params: AnyCodable("hello"),
            id: AnyCodable(1)
        )
        let response = await dispatcher.dispatch(request: request)

        // Verify response
        XCTAssertEqual(response.result, AnyCodable("hello"))
        XCTAssertNil(response.error)
        XCTAssertEqual(response.id, AnyCodable(1))
    }

    func testMethodNotFound() async {
        let dispatcher = RPCDispatcher()

        let request = RPCRequest(method: "unknown.method", params: nil, id: AnyCodable(1))
        let response = await dispatcher.dispatch(request: request)

        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, -32601)
    }

    func testNotification() async {
        let dispatcher = RPCDispatcher()

        var called = false
        await dispatcher.register(method: "test.notify") { _ in
            called = true
            return AnyCodable(nil)
        }

        // Dispatch notification (no id)
        let request = RPCRequest(method: "test.notify", params: nil, id: nil)
        _ = await dispatcher.dispatch(request: request)

        // Handler should be called
        XCTAssertTrue(called)
    }
}
```

### Integration Test

Create `Tests/{{CONFIG:swift_module_name}}Tests/Integration/Protocol0IntegrationTests.swift`:

```swift
import XCTest
@testable import {{CONFIG:swift_module_name}}

final class Protocol0IntegrationTests: XCTestCase {

    func testFullRPCFlow() async throws {
        // Setup RPC dispatcher
        let dispatcher = RPCDispatcher()
        await dispatcher.register(method: "math.add") { params in
            guard let dict = params?.value as? [String: Any],
                  let a = dict["a"] as? Int,
                  let b = dict["b"] as? Int else {
                return AnyCodable(nil)
            }
            return AnyCodable(a + b)
        }

        // Setup protocol router
        let router = ProtocolRouter()
        var responseReceived: RPCResponse?

        let textProtocol = TextProtocol(dispatcher: dispatcher) { response in
            responseReceived = response
        }

        await router.register(protocolID: 0x00) { payload in
            try await textProtocol.handle(payload: payload)
        }

        // Create request
        let request = RPCRequest(
            method: "math.add",
            params: AnyCodable(["a": 10, "b": 32]),
            id: AnyCodable(1)
        )
        let payload = try TextProtocol.encodeRequest(request)

        // Route through protocol router
        try await router.route(payload: payload)

        // Verify response
        XCTAssertNotNil(responseReceived)
        XCTAssertEqual(responseReceived?.result, AnyCodable(42))
        XCTAssertNil(responseReceived?.error)
    }
}
```

### Success Criteria

- [ ] All 13+ tests pass
- [ ] ProtocolRouter routes to correct handlers
- [ ] TextProtocol encodes/decodes JSON-RPC 2.0 correctly
- [ ] RPCDispatcher dispatches to registered methods
- [ ] RPC types (Request/Response/Error) work correctly
- [ ] AnyCodable handles all JSON types (nil, bool, int, double, string, array, dict)
- [ ] Notifications work (no response for id == nil)
- [ ] Integration test demonstrates full RPC flow
- [ ] Code coverage ≥ 80%
- [ ] All code uses actors for thread safety

### Run Tests

```bash
cd {{CONFIG:swift_build_dir}}
swift test --filter Protocol0
```

## Implementation Notes

### Swift-Specific Considerations

1. **Actor-Based Concurrency:**
   - Use `actor` for all handlers (ProtocolRouter, TextProtocol, RPCDispatcher)
   - Actor isolation prevents data races
   - All handler methods are `async`

2. **Sendable Conformance:**
   - All RPC types must be `Sendable` for actor safety
   - AnyCodable must be `Sendable`

3. **Data vs bytes:**
   - Swift uses `Data` instead of Python's `bytes`
   - Use `Data.suffix(from:)` to skip protocol ID byte

4. **JSON Encoding:**
   - Swift has native `JSONEncoder/JSONDecoder`
   - Use `Codable` protocol for automatic serialization

5. **Error Handling:**
   - Use Swift's typed errors (`throws`)
   - Define custom `ProtocolError` enum

### Differences from Python

| Python | Swift | Notes |
|--------|-------|-------|
| `class` | `actor` | Thread safety |
| `bytes` | `Data` | Binary data type |
| `dict` | `[String: Any]` | Dictionary type |
| `json.dumps()` | `JSONEncoder().encode()` | JSON serialization |
| `asyncio` | `async/await` | Async syntax is similar |
| `Dict[str, Callable]` | `[String: Handler]` | Handler storage |

### SDTS Issue #4 Protection

**Issue:** Python used `dict.get()` with None values, causing confusion.

**Swift Protection:**
- AnyCodable explicitly handles nil values
- Optional chaining prevents nil confusion
- No equivalent to Python's dict.get() with default None

## Traceability Matrix

| Gap ID | Specification | Implementation | Tests |
|--------|---------------|----------------|-------|
| 1.1 | protocol-layers.md § Protocol 0 | ProtocolRouter.swift | ProtocolRouterTests.swift |
| 1.3 | protocol-layers.md § JSON-RPC | RPCTypes.swift | RPCTypesTests.swift |
| 4.1 | api-contracts.md § RPC Types | RPCTypes.swift | RPCTypesTests.swift |
| 4.2 | api-contracts.md § RPC Dispatcher | RPCDispatcher.swift | RPCDispatcherTests.swift |

## Next Steps

After completing this step:

1. ✅ Protocol 0 (Text/JSON-RPC) working
2. ⏭️ **Next:** Step 12 - Protocol 1 (Binary/Chunked)
3. Then: Step 13 - Security (Replay Protection + Rate Limiting)
4. Then: Step 14 - SimplePacketBuilder (Test Helpers)
5. Then: Step 15 - Interoperability Test Suite

## References

- `specs/architecture/protocol-layers.md` - Protocol stack design
- `specs/architecture/api-contracts.md` - RPC API specification
- `specs/technical/yx-protocol-spec.md` - Wire format
- JSON-RPC 2.0 Specification: https://www.jsonrpc.org/specification
- Python Step 11: `steps/python/ybs-step_g1h2i3j4k5l6.md`
