// filename: ErrorHandlingTests.swift

import XCTest
@testable import Primitives
@testable import Transport

@MainActor
final class ErrorHandlingTests: XCTestCase {

    func testNetworkingErrorDescriptions() {
        let errors: [NetworkingError] = [
            .socketCreationFailed,
            .bindFailed(port: 9999),
            .sendFailed(destination: "127.0.0.1", reason: "timeout"),
            .receiveFailed(reason: "connection reset"),
            .invalidAddress("invalid"),
            .timeout
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty,
                          "Error \(error) has no description")
        }
    }

    func testPacketErrorDescriptions() {
        let errors: [PacketError] = [
            .invalidPacket(reason: "malformed"),
            .hmacValidationFailed,
            .decryptionFailed,
            .insufficientData(expected: 100, got: 50),
            .guidMissing,
            .invalidProtocolID(0xFF)
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty,
                          "Error \(error) has no description")
        }
    }

    func testRPCErrorDescriptions() {
        let errors: [RPCError] = [
            .methodNotFound("test.method"),
            .invalidRequest(reason: "missing params"),
            .invalidResponse(reason: "malformed JSON"),
            .timeout,
            .handlerError(method: "test", underlying: "crashed")
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty,
                          "Error \(error) has no description")
        }
    }

    func testProtocolErrorDescriptions() {
        let errors: [ProtocolError] = [
            .parsingFailed(protocol: "Protocol1", reason: "bad header"),
            .assemblyFailed(messageID: "123", reason: "missing chunks"),
            .compressionFailed,
            .decompressionFailed
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty,
                          "Error \(error) has no description")
        }
    }

    func testOperationResultSuccess() throws {
        let result: OperationResult<Int> = .success(42)
        let value = try result.get()
        XCTAssertEqual(value, 42)
        XCTAssertTrue(result.isSuccess)
        XCTAssertFalse(result.isFailure)
    }

    func testOperationResultFailure() {
        let result: OperationResult<Int> = .failure(PacketError.guidMissing)

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertTrue(error is PacketError)
        }
        XCTAssertFalse(result.isSuccess)
        XCTAssertTrue(result.isFailure)
    }

    func testOperationResultMap() throws {
        let result: OperationResult<Int> = .success(21)
        let doubled = result.map { $0 * 2 }

        let value = try doubled.get()
        XCTAssertEqual(value, 42)
    }

    func testOperationResultMapPreservesFailure() {
        let result: OperationResult<Int> = .failure(PacketError.guidMissing)
        let doubled = result.map { $0 * 2 }

        XCTAssertTrue(doubled.isFailure)
        XCTAssertThrowsError(try doubled.get())
    }
}
