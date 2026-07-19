import XCTest
import CryptoKit
@testable import YXProtocol

final class BinaryProtocolTests: XCTestCase {

    func testEncodeDecodeSingleChunk() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: [Data] = []

        let handler = BinaryProtocol(key: key) { data in
            received.append(data)
        }

        let data = Data("hello world".utf8)
        let payloads = try await handler.encode(data: data, protoOpts: 0x00)
        XCTAssertEqual(payloads.count, 1)

        for payload in payloads {
            try await handler.handle(payload: payload)
        }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], data)
    }

    func testEncodeDecodeCompressed() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: [Data] = []

        let handler = BinaryProtocol(key: key) { data in
            received.append(data)
        }

        let data = Data(repeating: 0xAA, count: 500)
        let payloads = try await handler.encode(data: data, protoOpts: 0x01)

        for payload in payloads {
            try await handler.handle(payload: payload)
        }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], data)
    }

    func testEncodeDecodeEncrypted() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: [Data] = []

        let handler = BinaryProtocol(key: key) { data in
            received.append(data)
        }

        let data = Data("secret message".utf8)
        let payloads = try await handler.encode(data: data, protoOpts: 0x02)

        for payload in payloads {
            try await handler.handle(payload: payload)
        }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], data)
    }

    func testEncodeDecodeBoth() async throws {
        let key = Data(repeating: 0x42, count: 32)
        var received: [Data] = []

        let handler = BinaryProtocol(key: key) { data in
            received.append(data)
        }

        let data = Data(repeating: 0xCC, count: 200)
        let payloads = try await handler.encode(data: data, protoOpts: 0x03)

        for payload in payloads {
            try await handler.handle(payload: payload)
        }
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0], data)
    }
}
