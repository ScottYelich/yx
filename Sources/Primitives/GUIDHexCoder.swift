import Foundation
// filename: GuidHexCoder.swift


public enum GuidHexCoder {
    /// Encodes a GUID (Data) to a hex string (e.g. "AABBCCDDEEFF")
    public static func encode(_ guid: Data) -> String {
        return guid.map { String(format: "%02X", $0) }.joined()
    }

    /// Decodes a hex string into a 6-byte Data GUID (returns nil if invalid)
    public static func decode(_ hex: String) -> Data? {
        guard let data = Data(hex: hex), data.count == 6 else {
            return nil
        }
        return data
    }
}
