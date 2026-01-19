import Foundation
import CryptoKit

public struct PacketBuilder {
    public static func buildPacket(guid: Data, payload: Data, key: SymmetricKey) throws -> Packet {
        let paddedGUID = GUIDFactory.pad(guid: guid)
        let hmac = DataCrypto.computePacketHMAC(guid: paddedGUID, payload: payload, key: key)
        return try Packet(hmac: hmac, guid: paddedGUID, payload: payload)
    }

    public static func buildAndSerialize(guid: Data, payload: Data, key: SymmetricKey) throws -> Data {
        let packet = try buildPacket(guid: guid, payload: payload, key: key)
        return packet.toBytes()
    }

    public static func parsePacket(_ data: Data) -> Packet? {
        return Packet.fromBytes(data)
    }

    public static func validateHMAC(_ packet: Packet, key: SymmetricKey) -> Bool {
        return DataCrypto.validatePacketHMAC(guid: packet.guid, payload: packet.payload, key: key, expectedHMAC: packet.hmac)
    }

    public static func parseAndValidate(_ data: Data, key: SymmetricKey) -> Packet? {
        guard let packet = parsePacket(data) else { return nil }
        guard validateHMAC(packet, key: key) else { return nil }
        return packet
    }
}
