// filename: RPCSystemIntakeTests.swift
//
// Regression guard for the 2026-07-28 live deadlock (sdts trading mesh):
// an s-expr handler that awaits an RPC reply blocked the whole receive chain
// (UDPTransport.receiveLoop → ProtocolRouter.route → TextProtocol.ingest →
// RPCSystem.handle → await handler), so the reply it was waiting for could
// never be read off the socket. The bridge answered in 1 ms; Swift timed out
// at 5 s and read the reply only after giving up.
//
// The contract these tests pin down: `RPCSystem.handle` returns to the intake
// path immediately — handler execution is detached.

import XCTest
import Primitives
import CryptoKit
@testable import Transport
@testable import YX

final class RPCSystemIntakeTests: XCTestCase {

    private func sexpr(_ text: String) -> Data { Data(text.utf8) }

    /// The intake shape that matters: ONE serial consumer draining frames in
    /// arrival order, which is exactly `UDPTransport.receiveLoop` →
    /// `ProtocolRouter.route` → `TextProtocol.ingest` → `RPCSystem.handle`.
    ///
    /// Asserting against a serial loop (rather than calling `handle` directly
    /// from the test body) is what makes these regression guards: `handle` is
    /// actor-reentrant, so parallel callers hide head-of-line blocking that a
    /// real single-socket loop cannot hide.
    private func receiveLoop(_ system: RPCSystem, _ frames: [Data]) -> Task<Void, Never> {
        Task {
            for frame in frames {
                if Task.isCancelled { return }
                await system.handle(frame)
            }
        }
    }

    /// `handle` must not wait for the handler to finish.
    func testHandleDoesNotBlockOnSlowSexpHandler() async throws {
        let system = RPCSystem()
        let entered = XCTestExpectation(description: "handler entered")
        let released = XCTestExpectation(description: "handler released")

        await system.registerSexp("slow") { _ in
            entered.fulfill()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            released.fulfill()
        }

        let start = Date()
        await system.handle(sexpr("(slow (params ()))"))
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 0.5,
                          "handle() awaited the handler — the receive loop would be blocked")
        await fulfillment(of: [entered], timeout: 2.0)
        await fulfillment(of: [released], timeout: 5.0)
    }

    /// The live shape: a handler that awaits a REPLY which can only be
    /// delivered by a later `handle` call. Without detached dispatch this
    /// deadlocks (and the test times out).
    func testReplyIsDeliveredWhileAnotherHandlerAwaitsIt() async throws {
        let system = RPCSystem()
        let gate = Gate()
        let resolved = XCTestExpectation(description: "in-handler call resolved")

        await system.registerSexp("reply") { expr in
            await gate.open(expr.field("to")?.stringValue ?? "")
        }
        await system.registerSexp("event") { _ in
            // The EventRouter/TradeEngine shape: act on an inbound event by
            // making a bridge call and awaiting its reply.
            let id = await gate.wait()
            XCTAssertEqual(id, "req-1")
            resolved.fulfill()
        }

        // Bounded on purpose: on the pre-fix code this call never returns, and
        // a hung test is a worse signal than a failed one.
        let intakeFree = XCTestExpectation(description: "intake path free after the event")
        let eventFrame = sexpr("(event (params ()))")
        Task {
            await system.handle(eventFrame)
            intakeFree.fulfill()
        }
        await fulfillment(of: [intakeFree], timeout: 3.0)

        // The reply arrives on the same wire, after the event.
        await system.handle(sexpr("(reply (to \"req-1\") (result ((success true))))"))

        await fulfillment(of: [resolved], timeout: 5.0)
    }

    /// The JSON-RPC wire carries the same guarantee.
    func testHandleDoesNotBlockOnSlowJSONHandler() async throws {
        let system = RPCSystem()
        let entered = XCTestExpectation(description: "handler entered")

        await system.register("slow.method") { _ in
            entered.fulfill()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        let start = Date()
        await system.handle(sexpr(#"{"method":"slow.method","params":{},"id":"1"}"#))
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 0.5,
                          "handle() awaited the JSON handler — the receive loop would be blocked")
        await fulfillment(of: [entered], timeout: 2.0)
    }

    // MARK: - The JSON wire carries the FULL guarantee, not just "returns fast"

    /// Catches: the s-expr path was detached but the JSON path was left
    /// awaiting `dispatcher.handle` — a JSON handler that issues an RPC and
    /// awaits its reply would still deadlock (the exact 2026-07-28 shape,
    /// just on the legacy wire). Not covered before: the existing JSON test
    /// only measures that `handle` returns quickly.
    func testJSONHandlerAwaitingAReplyIsResolvedByALaterPacket() async throws {
        let system = RPCSystem()
        let gate = Gate()
        let resolved = XCTestExpectation(description: "in-handler JSON call resolved")

        await system.register("bridge.reply") { request in
            await gate.open(request.params["to"]?.stringValue ?? "")
        }
        await system.register("ib.tick") { _ in
            // Act on an inbound event by calling the bridge and awaiting it.
            let id = await gate.wait()
            XCTAssertEqual(id, "req-json-1")
            resolved.fulfill()
        }

        // ONE serial consumer — the reply can only be read by the very loop
        // the handler would be blocking.
        let loop = receiveLoop(system, [
            sexpr(#"{"method":"ib.tick","params":{},"id":"e1"}"#),
            sexpr(#"{"method":"bridge.reply","params":{"to":"req-json-1"},"id":"r1"}"#),
        ])
        defer { loop.cancel() }

        await fulfillment(of: [resolved], timeout: 5.0)
    }

    // MARK: - Head-of-line blocking between DIFFERENT handlers

    /// Catches: a serialized intake that makes one slow consumer stall every
    /// other subscriber. On the live mesh the bridge's tick/status/execution
    /// broadcasts share one socket — a 2 s handler must not hold up the next
    /// packet's unrelated handler.
    func testASlowHandlerDoesNotDelayDeliveryToAnotherHandler() async throws {
        let system = RPCSystem()
        let slowEntered = XCTestExpectation(description: "slow handler entered")
        let fastFired = XCTestExpectation(description: "fast handler fired")

        await system.registerSexp("slow") { _ in
            slowEntered.fulfill()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        await system.registerSexp("fast") { _ in
            fastFired.fulfill()
        }

        // Both packets arrive back-to-back on ONE socket, drained by ONE loop.
        let start = Date()
        let loop = receiveLoop(system, [sexpr("(slow (params ()))"),
                                        sexpr("(fast (params ()))")])
        defer { loop.cancel() }

        await fulfillment(of: [slowEntered, fastFired], timeout: 1.0)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0,
                          "the second head waited behind the first handler")
    }

    // MARK: - A broken handler must not take the intake path with it

    private struct HandlerFailure: Error {}

    /// Catches: an intake path that propagates (or is stopped by) a handler
    /// failure. A handler that dies mid-flight is an application bug; a
    /// receive loop that stops dispatching afterwards is a dead service.
    func testAFailingHandlerDoesNotStopLaterPacketsFromDispatching() async throws {
        let system = RPCSystem()
        let failed = XCTestExpectation(description: "failing handler ran")
        let later = XCTestExpectation(description: "later packet dispatched")
        later.expectedFulfillmentCount = 3

        await system.registerSexp("boom") { _ in
            defer { failed.fulfill() }
            // The work the handler exists to do throws; the handler returns
            // having accomplished nothing.
            let work = Task<Void, Error> { throw HandlerFailure() }
            do { try await work.value } catch { return }
            XCTFail("unreachable — the work must have thrown")
        }
        await system.registerSexp("ok") { _ in later.fulfill() }

        let frames = [sexpr("(boom (params ()))")]
            + Array(repeating: sexpr("(ok (params ()))"), count: 3)
        let loop = receiveLoop(system, frames)
        defer { loop.cancel() }

        await fulfillment(of: [failed, later], timeout: 2.0)
    }

    /// The worst case: a handler that NEVER returns (an un-resumed
    /// continuation — what the live deadlock actually looked like from the
    /// loop's point of view). The intake must not care at all.
    func testAHandlerThatNeverReturnsDoesNotWedgeTheIntakePath() async throws {
        let system = RPCSystem()
        let hungEntered = XCTestExpectation(description: "hung handler entered")
        let later = XCTestExpectation(description: "later packets dispatched")
        later.expectedFulfillmentCount = 5

        await system.registerSexp("hang") { _ in
            hungEntered.fulfill()
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in
                // never resumed — this handler is gone forever
            }
        }
        await system.registerSexp("ok") { _ in later.fulfill() }

        let start = Date()
        let frames = [sexpr("(hang (params ()))")]
            + Array(repeating: sexpr("(ok (params ()))"), count: 5)
        let loop = receiveLoop(system, frames)
        defer { loop.cancel() }

        await fulfillment(of: [hungEntered, later], timeout: 2.0)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }

    // MARK: - Concurrency storm

    /// Catches: an intake that is only "detached enough" for ONE in-flight
    /// handler. 50 event handlers suspend on their own reply; the 50 replies
    /// then arrive on the same wire, out of order, while every one of them is
    /// mid-await. This is the live failure multiplied — the bridge answers
    /// tick/status/execution traffic in parallel, not one at a time.
    func testFiftyInterleavedInHandlerCallsAllResolve() async throws {
        let system = RPCSystem()
        let pending = PendingTable()
        let count = 50

        let entered = XCTestExpectation(description: "every handler suspended on its reply")
        entered.expectedFulfillmentCount = count
        let resolved = XCTestExpectation(description: "every in-handler call resolved")
        resolved.expectedFulfillmentCount = count

        await system.registerSexp("reply") { expr in
            await pending.resolve(expr.field("to")?.stringValue ?? "")
        }
        await system.registerSexp("event") { expr in
            let id = expr.field("id")?.stringValue ?? ""
            await pending.wait(id, onSuspend: { entered.fulfill() })
            resolved.fulfill()
        }

        // 50 events, then their 50 replies out of order — ONE socket, ONE
        // draining loop, exactly as the mesh delivers them.
        let events = (0..<count).map { sexpr("(event (id \"req-\($0)\"))") }
        let replies = (0..<count).shuffled().map {
            sexpr("(reply (to \"req-\($0)\") (result ((success true))))")
        }
        let loop = receiveLoop(system, events + replies)
        defer { loop.cancel() }

        await fulfillment(of: [entered, resolved], timeout: 10.0)
        let stranded = await pending.waiting
        XCTAssertEqual(stranded, 0, "a reply was read but never matched to its waiter")
    }

    // MARK: - The big binary reply (the 121 KB ib.orders proof)

    /// Catches: an s-expr that arrives over Protocol-1 (compressed, chunked)
    /// never reaching the s-expr car-dispatch table — the live 2026-07-28
    /// `ib.orders` reply was ~121 KB, i.e. >100 chunks, and it MUST land in
    /// the same registry a small Protocol-0 reply lands in. Sockets are not
    /// involved: the chunks go out through an installed send API and come
    /// straight back in through `ingest`.
    func testLargeCompressedBinarySexprReplyDispatchesToTheSexprRegistry() async throws {
        let keyData = Data(hex: "D3046ECC8DD3242ADF62801A33EF1004003B01B4C8F558DF72E637DA30321CCD")!
        let key = SymmetricKey(data: keyData)

        let system = RPCSystem()
        let arrived = XCTestExpectation(description: "big reply dispatched to the sexp registry")
        let seen = Captured()

        await system.registerSexp("reply") { expr in
            await seen.record(to: expr.field("to")?.stringValue,
                              orders: expr.field("result")?
                                          .field("orders")?.listCount ?? 0)
            arrived.fulfill()
        }

        let binary = BinaryProtocol(chunkSize: 1024)
        await binary.setKey(key)
        await binary.setReceiveHandler { data in await system.handle(data) }

        let collector = ChunkCollector()
        await binary.installSendAPI { data, _, _ in await collector.append(data) }

        // A synthetic ib.orders reply of the size that broke it live.
        let payload = Self.bigOrdersReply(orders: 900)
        XCTAssertGreaterThan(payload.count, 100_000, "the live reply was ~121 KB")

        // protoOpts 0x01 = zlib compression, the option the bridge uses for
        // anything this big.
        await binary.send(payload: Data(payload.utf8), protoOpts: 0x01,
                          to: "127.0.0.1", port: 51999)

        let chunks = await collector.chunks
        XCTAssertGreaterThan(chunks.count, 1, "a 121 KB reply is not one datagram")

        let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        for chunk in chunks {
            let body = guid + chunk
            let hmac = HMAC<SHA256>.authenticationCode(for: body, using: key)
            let wire = Data(hmac.prefix(16)) + body
            let packet = UDPPacketUtils.parse(wire, key: key,
                                              sourceIP: "127.0.0.1", sourcePort: 51999)
            await binary.ingest(packet, key: key)
        }

        await fulfillment(of: [arrived], timeout: 10.0)
        let record = await seen.value
        XCTAssertEqual(record.to, "req-orders-1")
        XCTAssertEqual(record.orders, 900, "the reassembled s-expr lost rows")
    }

    /// `(reply (to …) (result ((success true) (orders (…)))))` with `orders`
    /// rows, sized to clear the live 121 KB mark.
    private static func bigOrdersReply(orders: Int) -> String {
        var text = "(reply (to \"req-orders-1\") (result ((success true) (orders ("
        for i in 0..<orders {
            text += "((order_id \(9000 + i)) (status \"Submitted\") (symbol \"ESU6\") "
            text += "(action \"BUY\") (quantity 2) (limit_price 7431.25) "
            text += "(order_type \"LMT\") (account \"DU1234567\")) "
        }
        // close: orders-list, orders, result-list, result, reply
        text += ")))))"
        return text
    }
}

// MARK: - Helpers

private extension SExpr {
    /// Number of elements in the value of a `(name (…))` field.
    var listCount: Int {
        if case .list(let items) = self { return items.count }
        return 0
    }
}

/// Keyed rendezvous for the storm test. A reply may arrive BEFORE its waiter
/// registers (handlers are detached and unordered), so an early resolution is
/// remembered rather than dropped.
private actor PendingTable {
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]
    private var resolvedEarly: Set<String> = []

    var waiting: Int { waiters.count }

    func resolve(_ id: String) {
        if let waiter = waiters.removeValue(forKey: id) {
            waiter.resume()
        } else {
            resolvedEarly.insert(id)
        }
    }

    func wait(_ id: String, onSuspend: @Sendable () -> Void) async {
        if resolvedEarly.remove(id) != nil {
            onSuspend()
            return
        }
        await withCheckedContinuation { continuation in
            waiters[id] = continuation
            onSuspend()
        }
    }
}

private actor ChunkCollector {
    private(set) var chunks: [Data] = []
    func append(_ data: Data) { chunks.append(data) }
}

private actor Captured {
    struct Record: Sendable { var to: String?; var orders: Int }
    private(set) var value = Record(to: nil, orders: 0)
    func record(to: String?, orders: Int) { value = Record(to: to, orders: orders) }
}

/// A one-shot rendezvous: `wait()` suspends until `open(_:)` supplies a value.
private actor Gate {
    private var value: String?
    private var waiter: CheckedContinuation<String, Never>?

    func open(_ value: String) {
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: value)
        } else {
            self.value = value
        }
    }

    func wait() async -> String {
        if let value {
            self.value = nil
            return value
        }
        return await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }
}
