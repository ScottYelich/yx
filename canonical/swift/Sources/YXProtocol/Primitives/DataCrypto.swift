import Foundation
import CryptoKit

public struct DataCrypto {
    public static func computeHMAC(data: Data, key: SymmetricKey, truncateTo: Int = 16) -> Data {
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac.prefix(truncateTo))
    }

    public static func validateHMAC(data: Data, key: SymmetricKey, expectedHMAC: Data, truncateTo: Int = 16) -> Bool {
        let computed = computeHMAC(data: data, key: key, truncateTo: truncateTo)
        return computed == expectedHMAC
    }

    public static func computePacketHMAC(guid: Data, payload: Data, key: SymmetricKey) -> Data {
        let combined = guid + payload
        return computeHMAC(data: combined, key: key, truncateTo: 16)
    }

    public static func validatePacketHMAC(guid: Data, payload: Data, key: SymmetricKey, expectedHMAC: Data) -> Bool {
        let computed = computePacketHMAC(guid: guid, payload: payload, key: key)
        return computed == expectedHMAC
    }
}
