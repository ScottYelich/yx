#!/usr/bin/env swift

import Foundation
import CryptoKit

// Inline YXProtocol implementation for standalone script

struct GUIDFactory {
    static func pad(guid: Data) -> Data {
        if guid.count == 6 {
            return guid
        } else if guid.count < 6 {
            return guid + Data(repeating: 0, count: 6 - guid.count)
        } else {
            return guid.prefix(6)
        }
    }
}

struct DataCrypto {
    static func computePacketHMAC(guid: Data, payload: Data, key: SymmetricKey) -> Data {
        let combined = guid + payload
        let hmac = HMAC<SHA256>.authenticationCode(for: combined, using: key)
        return Data(hmac.prefix(16))
    }

    static func validatePacketHMAC(guid: Data, payload: Data, key: SymmetricKey, expectedHMAC: Data) -> Bool {
        let computed = computePacketHMAC(guid: guid, payload: payload, key: key)
        return computed == expectedHMAC
    }
}

enum PacketError: Error {
    case invalidHMACLength
    case invalidGUIDLength
}

struct Packet {
    let hmac: Data
    let guid: Data
    let payload: Data

    init(hmac: Data, guid: Data, payload: Data) throws {
        guard hmac.count == 16 else {
            throw PacketError.invalidHMACLength
        }
        guard guid.count == 6 else {
            throw PacketError.invalidGUIDLength
        }
        self.hmac = hmac
        self.guid = guid
        self.payload = payload
    }

    func toBytes() -> Data {
        return hmac + guid + payload
    }

    static func fromBytes(_ data: Data) -> Packet? {
        guard data.count >= 22 else { return nil }
        let hmac = data[0..<16]
        let guid = data[16..<22]
        let payload = data[22...]
        return try? Packet(hmac: Data(hmac), guid: Data(guid), payload: Data(payload))
    }
}

struct PacketBuilder {
    static func buildPacket(guid: Data, payload: Data, key: SymmetricKey) throws -> Packet {
        let paddedGUID = GUIDFactory.pad(guid: guid)
        let hmac = DataCrypto.computePacketHMAC(guid: paddedGUID, payload: payload, key: key)
        return try Packet(hmac: hmac, guid: paddedGUID, payload: payload)
    }

    static func parsePacket(_ data: Data) -> Packet? {
        return Packet.fromBytes(data)
    }

    static func validateHMAC(_ packet: Packet, key: SymmetricKey) -> Bool {
        return DataCrypto.validatePacketHMAC(guid: packet.guid, payload: packet.payload, key: key, expectedHMAC: packet.hmac)
    }

    static func parseAndValidate(_ data: Data, key: SymmetricKey) -> Packet? {
        guard let packet = parsePacket(data) else { return nil }
        guard validateHMAC(packet, key: key) else { return nil }
        return packet
    }
}

// Integration Tests

print("🧪 Running Integration Tests...")
print("")

var testsPassed = 0
var testsFailed = 0

// Test 1: Complete Packet Flow
do {
    print("Test 1: Complete packet flow")
    let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
    let guid = Data(repeating: 0xaa, count: 6)
    let payload = Data("integration test payload".utf8)

    let packet = try PacketBuilder.buildPacket(guid: guid, payload: payload, key: key)
    let data = packet.toBytes()
    let parsed = PacketBuilder.parsePacket(data)

    guard parsed != nil else {
        print("  ❌ Failed to parse packet")
        testsFailed += 1
        throw NSError(domain: "test", code: 1)
    }

    let isValid = PacketBuilder.validateHMAC(parsed!, key: key)
    guard isValid else {
        print("  ❌ HMAC validation failed")
        testsFailed += 1
        throw NSError(domain: "test", code: 2)
    }

    guard parsed?.payload == payload else {
        print("  ❌ Payload mismatch")
        testsFailed += 1
        throw NSError(domain: "test", code: 3)
    }

    print("  ✅ Build → Serialize → Parse → Validate → Verify payload")
    testsPassed += 1
} catch {
    print("  ❌ Test failed with error: \(error)")
    testsFailed += 1
}

// Test 2: Multiple Packets
do {
    print("Test 2: Multiple packets (10 iterations)")
    let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))

    for i in 0..<10 {
        let payload = Data("packet \(i)".utf8)
        let packet = try PacketBuilder.buildPacket(guid: Data(repeating: 0x01, count: 6), payload: payload, key: key)
        let data = packet.toBytes()
        let parsed = PacketBuilder.parseAndValidate(data, key: key)

        guard parsed != nil, parsed?.payload == payload else {
            print("  ❌ Failed on packet \(i)")
            testsFailed += 1
            throw NSError(domain: "test", code: 4)
        }
    }

    print("  ✅ All 10 packets processed correctly")
    testsPassed += 1
} catch {
    print("  ❌ Test failed with error: \(error)")
    testsFailed += 1
}

// Test 3: Invalid Key Rejected
do {
    print("Test 3: Invalid key rejection")
    let sendKey = SymmetricKey(data: Data(repeating: 0x00, count: 32))
    let recvKey = SymmetricKey(data: Data(repeating: 0xff, count: 32))

    let packet = try PacketBuilder.buildPacket(guid: Data(repeating: 0x01, count: 6), payload: Data("test".utf8), key: sendKey)
    let data = packet.toBytes()
    let parsed = PacketBuilder.parseAndValidate(data, key: recvKey)

    if parsed == nil {
        print("  ✅ Packet with wrong key correctly rejected")
        testsPassed += 1
    } else {
        print("  ❌ Packet with wrong key was NOT rejected")
        testsFailed += 1
    }
} catch {
    print("  ❌ Test failed with error: \(error)")
    testsFailed += 1
}

// Test 4: Empty Payload
do {
    print("Test 4: Empty payload")
    let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
    let packet = try PacketBuilder.buildPacket(guid: Data(repeating: 0x01, count: 6), payload: Data(), key: key)
    let data = packet.toBytes()

    guard data.count == 22 else {
        print("  ❌ Empty payload packet should be 22 bytes, got \(data.count)")
        testsFailed += 1
        throw NSError(domain: "test", code: 5)
    }

    let parsed = PacketBuilder.parseAndValidate(data, key: key)
    guard parsed != nil, parsed?.payload.isEmpty == true else {
        print("  ❌ Failed to parse empty payload packet")
        testsFailed += 1
        throw NSError(domain: "test", code: 6)
    }

    print("  ✅ Empty payload handled correctly")
    testsPassed += 1
} catch {
    print("  ❌ Test failed with error: \(error)")
    testsFailed += 1
}

// Test 5: Large Payload
do {
    print("Test 5: Large payload (10KB)")
    let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
    let largePayload = Data(repeating: 0x58, count: 10000)

    let packet = try PacketBuilder.buildPacket(guid: Data(repeating: 0x01, count: 6), payload: largePayload, key: key)
    let data = packet.toBytes()
    let parsed = PacketBuilder.parseAndValidate(data, key: key)

    guard parsed != nil, parsed?.payload == largePayload else {
        print("  ❌ Large payload verification failed")
        testsFailed += 1
        throw NSError(domain: "test", code: 7)
    }

    print("  ✅ 10KB payload handled correctly")
    testsPassed += 1
} catch {
    print("  ❌ Test failed with error: \(error)")
    testsFailed += 1
}

print("")
print(String(repeating: "=", count: 60))
print("Results: \(testsPassed) passed, \(testsFailed) failed out of \(testsPassed + testsFailed) total")
print(String(repeating: "=", count: 60))

if testsFailed == 0 {
    print("✅ ALL INTEGRATION TESTS PASSED")
    exit(0)
} else {
    print("❌ SOME TESTS FAILED")
    exit(1)
}
