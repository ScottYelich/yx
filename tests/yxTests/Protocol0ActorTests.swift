//
//  TextProtocolTests.swift
//  yx
//
//  Created by Scott Yelich on 5/20/25.
//


// filename: TextProtocolTests.swift

import XCTest
import CryptoKit
@testable import Transport

final class TextProtocolTests: XCTestCase {

    func testSendAndReceive() async throws {
        let actor = TextProtocol()
        let expectationSend = XCTestExpectation(description: "send called")
        let expectationReceive = XCTestExpectation(description: "receive called")

        // Simulate a sendAPI that confirms payload round-trip
        await actor.installSendAPI { data, host, port in
            XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
            XCTAssertEqual(host, "127.0.0.1")
            XCTAssertEqual(port, 7777)
            expectationSend.fulfill()
        }

        // Set receive handler that confirms payload received
        await actor.setReceiveHandler { data in
            XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
            expectationReceive.fulfill()
        }

        // Simulate sending
        let payload = Data("hello".utf8)
        await actor.send(payload, to: "127.0.0.1", port: 7777)

        // Simulate receiving via ingest (HMAC/GUID not validated here)
        let guid = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        let packet = UDPPacketUtils.build(guid: guid, bytesAfterGUID: payload, key: SymmetricKey(size: .bits256))
        await actor.ingest(packet, key: SymmetricKey(size: .bits256))

        await fulfillment(of: [expectationSend, expectationReceive], timeout: 1.0)
    }
}
