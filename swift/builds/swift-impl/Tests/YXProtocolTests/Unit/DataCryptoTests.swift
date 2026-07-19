import XCTest
import CryptoKit
@testable import YXProtocol

final class DataCryptoTests: XCTestCase {
    func testComputeHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let data = Data("test".utf8)

        let hmac = DataCrypto.computeHMAC(data: data, key: key)

        XCTAssertEqual(hmac.count, 16)
    }

    func testValidateHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let data = Data("test".utf8)

        let hmac = DataCrypto.computeHMAC(data: data, key: key)
        let isValid = DataCrypto.validateHMAC(data: data, key: key, expectedHMAC: hmac)

        XCTAssertTrue(isValid)
    }

    func testComputePacketHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let hmac = DataCrypto.computePacketHMAC(guid: guid, payload: payload, key: key)

        XCTAssertEqual(hmac.count, 16)
    }

    func testValidatePacketHMAC() {
        let key = SymmetricKey(data: Data(repeating: 0x00, count: 32))
        let guid = Data(repeating: 0x01, count: 6)
        let payload = Data("test".utf8)

        let hmac = DataCrypto.computePacketHMAC(guid: guid, payload: payload, key: key)
        let isValid = DataCrypto.validatePacketHMAC(guid: guid, payload: payload, key: key, expectedHMAC: hmac)

        XCTAssertTrue(isValid)
    }

    func testAESGCMRoundtrip() throws {
        let key = SymmetricKey(data: Data(repeating: 0x42, count: 32))
        let plaintext = Data("hello world".utf8)

        let encrypted = try plaintext.aesGCMEncrypt(key: key)
        let decrypted = try encrypted.aesGCMDecrypt(key: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func testAESGCMNonceIsRandom() throws {
        let key = SymmetricKey(data: Data(repeating: 0x42, count: 32))
        let plaintext = Data("hello".utf8)

        let enc1 = try plaintext.aesGCMEncrypt(key: key)
        let enc2 = try plaintext.aesGCMEncrypt(key: key)

        // Different nonces mean different ciphertexts
        XCTAssertNotEqual(enc1, enc2)
    }

    func testZlibRoundtrip() throws {
        let data = Data(repeating: 0xAA, count: 1000)

        let compressed = try data.zlibCompress()
        let decompressed = try compressed.zlibDecompress()

        XCTAssertEqual(decompressed, data)
        XCTAssertLessThan(compressed.count, data.count)
    }
}
