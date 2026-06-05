import XCTest
import Foundation
@testable import YXProtocol

final class ProtocolRouterTests: XCTestCase {

    func testRegisterAndRoute() async throws {
        let router = ProtocolRouter()
        actor Flag { var v = false; func set() { v = true } }
        let flag = Flag()

        await router.register(protocolID: 0x00) { payload in
            XCTAssertEqual(payload[payload.startIndex], 0x00)
            await flag.set()
        }

        let payload = Data([0x00, 0x01, 0x02])
        try await router.route(payload: payload)

        let handled = await flag.v
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
                // expected
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }
}

final class RPCTypesTests: XCTestCase {

    func testRPCRequestEncoding() throws {
        let request = RPCRequest(method: "test.echo", params: AnyCodable(["message": "hello"]), id: AnyCodable(1))
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(RPCRequest.self, from: data)
        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.method, "test.echo")
        XCTAssertEqual(decoded.id, AnyCodable(1))
    }

    func testRPCRequestNotification() {
        XCTAssertTrue(RPCRequest(method: "test.notify", params: nil, id: nil).isNotification)
        XCTAssertFalse(RPCRequest(method: "test.call", params: nil, id: AnyCodable(1)).isNotification)
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
        let values: [AnyCodable] = [AnyCodable(nil), AnyCodable(true), AnyCodable(42), AnyCodable(3.14), AnyCodable("hello")]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in values {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AnyCodable.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
}

final class TextProtocolTests: XCTestCase {

    func testEncodeRequest() throws {
        let request = RPCRequest(method: "test.echo", params: AnyCodable(["message": "hello"]), id: AnyCodable(1))
        let payload = try TextProtocol.encodeRequest(request)
        XCTAssertEqual(payload[payload.startIndex], 0x00)
        let jsonData = Data(payload.suffix(from: payload.startIndex + 1))
        let decoded = try JSONDecoder().decode(RPCRequest.self, from: jsonData)
        XCTAssertEqual(decoded.method, "test.echo")
        XCTAssertEqual(decoded.id, AnyCodable(1))
    }

    func testHandleRequest() async throws {
        let dispatcher = RPCDispatcher()
        await dispatcher.register(method: "test.echo") { params in
            return params ?? AnyCodable(nil)
        }

        actor Box { var v: RPCResponse?; func set(_ r: RPCResponse) { v = r } }
        let box = Box()
        let textProtocol = TextProtocol(dispatcher: dispatcher) { response in
            await box.set(response)
        }

        let request = RPCRequest(method: "test.echo", params: AnyCodable("hello"), id: AnyCodable(1))
        let payload = try TextProtocol.encodeRequest(request)
        try await textProtocol.handle(payload: payload)

        let captured = await box.v
        XCTAssertNotNil(captured)
        XCTAssertEqual(captured?.result, AnyCodable("hello"))
        XCTAssertEqual(captured?.id, AnyCodable(1))
    }
}

final class RPCDispatcherTests: XCTestCase {

    func testRegisterAndDispatch() async throws {
        let dispatcher = RPCDispatcher()
        await dispatcher.register(method: "test.echo") { params in
            return params ?? AnyCodable(nil)
        }
        let request = RPCRequest(method: "test.echo", params: AnyCodable("hello"), id: AnyCodable(1))
        let response = await dispatcher.dispatch(request: request)
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
        actor Flag { var v = false; func set() { v = true } }
        let flag = Flag()
        await dispatcher.register(method: "test.notify") { _ in
            await flag.set()
            return AnyCodable(nil)
        }
        let request = RPCRequest(method: "test.notify", params: nil, id: nil)
        _ = await dispatcher.dispatch(request: request)
        let called = await flag.v
        XCTAssertTrue(called)
    }
}
