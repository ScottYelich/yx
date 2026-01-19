import Testing
import CryptoKit
@testable import YXProtocol

@Suite struct DataCryptoTests {
    @Test func computeHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let data = Data("test".utf8)

        let hmac = DataCrypto.computeHMAC(data: data, key: key)

        #expect(hmac.count == 16)
    }

    @Test func validateHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let data = Data("test".utf8)

        let hmac = DataCrypto.computeHMAC(data: data, key: key)
        let isValid = DataCrypto.validateHMAC(data: data, key: key, expectedHMAC: hmac)

        #expect(isValid)
    }

    @Test func computePacketHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let hmac = DataCrypto.computePacketHMAC(guid: guid, payload: payload, key: key)

        #expect(hmac.count == 16)
    }

    @Test func validatePacketHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let hmac = DataCrypto.computePacketHMAC(guid: guid, payload: payload, key: key)
        let isValid = DataCrypto.validatePacketHMAC(guid: guid, payload: payload, key: key, expectedHMAC: hmac)

        #expect(isValid)
    }
}
