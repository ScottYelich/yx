import Foundation
import CryptoKit

// Implements: protocol/specs/technical/yx-protocol-spec.md

// MARK: - SymmetricKey helper

public extension Data {
    /// Create a SymmetricKey from raw bytes.
    static func symmetricKey(from keyData: Data) throws -> SymmetricKey {
        guard keyData.count == 32 else {
            throw CryptoError.invalidKeySize
        }
        return SymmetricKey(data: keyData)
    }
}

// MARK: - Hex encoding/decoding

public extension Data {
    /// Create Data from hex string.
    init?(hexString: String) {
        guard hexString.count % 2 == 0 else { return nil }
        var data = Data()
        var idx = hexString.startIndex
        while idx < hexString.endIndex {
            let next = hexString.index(idx, offsetBy: 2)
            guard let byte = UInt8(hexString[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        self = data
    }

    /// Convert Data to hex string.
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
