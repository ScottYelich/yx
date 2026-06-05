import Testing
import Foundation
import CryptoKit
@testable import YXProtocol

// Proves Swift reproduces the canonical byte-fixed vectors EXACTLY (cross-language
// byte-identity) and decodes the round-trip (compressed/encrypted) cases to the
// original payload. (Data(hex:) is defined in CanonicalValidationTests.swift.)
@Suite struct CanonicalArtifactsTests {

    struct TransportCase: Codable {
        let name: String; let guid: String; let key: String
        let payload_hex: String; let expected_hmac: String; let expected_packet: String
    }
    struct TransportVectors: Codable { let test_cases: [TransportCase] }

    struct BinaryFixed: Codable {
        let name: String; let guid: String; let key: String
        let proto_opts: UInt8; let channel_id: UInt16; let sequence: UInt32
        let chunk_size: Int; let payload_hex: String; let expected_packets: [String]
    }
    struct BinaryRoundtrip: Codable {
        let name: String; let guid: String; let key: String
        let proto_opts: UInt8; let channel_id: UInt16; let sequence: UInt32
        let chunk_size: Int; let payload_hex: String; let expected_plaintext_hex: String
    }
    struct BinaryVectors: Codable { let byte_fixed: [BinaryFixed]; let round_trip: [BinaryRoundtrip] }

    actor Box { var msgs: [Data] = []; func add(_ d: Data) { msgs.append(d) } }

    static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    static func load<T: Decodable>(_ file: String, as: T.Type) throws -> T? {
        let url = URL(fileURLWithPath: "../../canonical/test-vectors/\(file)")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    @Test func transportVectorsAreByteIdentical() throws {
        guard let v = try Self.load("transport-packets.json", as: TransportVectors.self) else {
            Issue.record("transport-packets.json not found; run generate_canonical.py"); return
        }
        for tc in v.test_cases {
            let guid = Data(hex: tc.guid)!
            let key = SymmetricKey(data: Data(hex: tc.key)!)
            let payload = Data(hex: tc.payload_hex)!
            let packet = try PacketBuilder.buildAndSerialize(guid: guid, payload: payload, key: key)
            #expect(Self.hex(packet) == tc.expected_packet, "transport byte mismatch: \(tc.name)")
        }
    }

    @Test func binaryBaseVectorsAreByteIdentical() throws {
        guard let v = try Self.load("binary-protocol-packets.json", as: BinaryVectors.self) else {
            Issue.record("binary-protocol-packets.json not found; run generate_canonical.py"); return
        }
        for tc in v.byte_fixed {
            let packets = try SimplePacketBuilder.buildBinaryPackets(
                data: Data(hex: tc.payload_hex)!,
                guid: Data(hex: tc.guid)!,
                key: Data(hex: tc.key)!,
                protoOpts: tc.proto_opts,
                channelID: tc.channel_id,
                sequence: tc.sequence,
                chunkSize: tc.chunk_size)
            #expect(packets.map { Self.hex($0) } == tc.expected_packets, "binary base byte mismatch: \(tc.name)")
        }
    }

    @Test func binaryRoundtripDecodesToPayload() async throws {
        guard let v = try Self.load("binary-protocol-packets.json", as: BinaryVectors.self) else {
            Issue.record("binary-protocol-packets.json not found"); return
        }
        for tc in v.round_trip {
            let key = Data(hex: tc.key)!
            let payload = Data(hex: tc.payload_hex)!
            let box = Box()
            // AES key matches the Python canonical (shared test key), per build_binary_packet.
            let bp = BinaryProtocol(key: key, onMessage: { d in await box.add(d) })

            let packets = try SimplePacketBuilder.buildBinaryPackets(
                data: payload, guid: Data(hex: tc.guid)!, key: key,
                protoOpts: tc.proto_opts, encryptionKey: key,
                channelID: tc.channel_id, sequence: tc.sequence, chunkSize: tc.chunk_size)

            for pkt in packets {
                // strip transport [HMAC(16)][GUID(6)] -> protocol payload
                let protocolPayload = Data(pkt.suffix(from: pkt.startIndex + 22))
                try await bp.handle(payload: protocolPayload)
            }

            let msgs = await box.msgs
            #expect(msgs.first.map { Self.hex($0) } == tc.expected_plaintext_hex, "round-trip mismatch: \(tc.name)")
        }
    }
}
