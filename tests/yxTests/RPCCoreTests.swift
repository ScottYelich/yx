// filename: RPCCoreTests.swift

import XCTest
@preconcurrency import RPC

@MainActor
final class RPCCoreTests: XCTestCase {

    private func makeDispatcher() async -> RPCDispatcher {
        let dispatcher = RPCDispatcher()

        // Register test method: "ping" ➝ "pong"
        await dispatcher.register("ping") { request in
            request.reply(result: "pong")
        }

        // Register dummy handler for chain test
        await dispatcher.register("rpc.chain") { request in
            request.reply(result: "hello")
        }

        return dispatcher
    }

    func testPingRequest() {
        let expectation = XCTestExpectation(description: "RPC ping response")
        nonisolated(unsafe) let json: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "abc123",
            "method": "ping",
            "params": [:]
        ]

        Task { @MainActor in
            let dispatcher = await makeDispatcher()
            await dispatcher.handle(json: json) { response in
                guard let response = response as? [String: Any],
                      let result = response["result"] as? String else {
                    XCTFail("Invalid or missing result in response")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(result, "pong", "Ping should return pong")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testRpcChainRequest() {
        let expectation = XCTestExpectation(description: "RPC chain response")
        nonisolated(unsafe) let json: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "chain-test-1",
            "method": "rpc.chain",
            "params": [:]
        ]

        Task { @MainActor in
            let dispatcher = await makeDispatcher()
            await dispatcher.handle(json: json) { response in
                guard let response = response as? [String: Any],
                      let result = response["result"] as? String else {
                    XCTFail("Invalid or missing result in response")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(result, "hello", "rpc.chain should return hello")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testMissingMethod() {
        let expectation = XCTestExpectation(description: "RPC error for missing method")
        nonisolated(unsafe) let json: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "missing-method"
            // "method" is intentionally missing
        ]

        Task { @MainActor in
            let dispatcher = await makeDispatcher()
            await dispatcher.handle(json: json) { response in
                guard let response = response as? [String: Any],
                      let error = response["error"] as? [String: Any],
                      let code = error["code"] as? Int else {
                    XCTFail("Missing or invalid error response")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(code, -32600, "Expected code for missing method")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testUnknownMethod() {
        // Broadcast-mesh contract: an unknown method is silently ignored — no error
        // reply. Every service receives every broadcast and handles only its own
        // methods; error replies here would flood the network.
        let expectation = XCTestExpectation(description: "no reply for unknown method")
        expectation.isInverted = true
        nonisolated(unsafe) let json: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "unknown-method",
            "method": "doesNotExist",
            "params": [:]
        ]

        Task { @MainActor in
            let dispatcher = await makeDispatcher()
            await dispatcher.handle(json: json) { _ in
                expectation.fulfill()  // any reply = failure (inverted expectation)
            }
        }

        wait(for: [expectation], timeout: 0.5)
    }
}


