import Foundation

public struct Packet {
    public let hmac: Data      // 16 bytes
    public let guid: Data      // 6 bytes
    public let payload: Data   // Variable

    public init(hmac: Data, guid: Data, payload: Data) throws {
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

    public func toBytes() -> Data {
        return hmac + guid + payload
    }

    public static func fromBytes(_ data: Data) -> Packet? {
        guard data.count >= 22 else { return nil }

        let hmac = data[0..<16]
        let guid = data[16..<22]
        let payload = data[22...]

        return try? Packet(hmac: Data(hmac), guid: Data(guid), payload: Data(payload))
    }
}

public enum PacketError: Error {
    case invalidHMACLength
    case invalidGUIDLength
}
