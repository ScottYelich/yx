import Foundation
// filename: GUIDFactory.swift


public enum GUIDFactory {
    
    /// Generates a new secure 6-byte GUID using system entropy.
    public static func random() -> Data {
        var bytes = [UInt8](repeating: 0, count: 6)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(result == errSecSuccess, "Failed to generate secure random bytes")
        return Data(bytes)
    }
    
    /// Generates a clean 6-byte (48-bit) GUID as Data
    public static func generate() -> Data {
        var bytes = [UInt8](repeating: 0, count: 6)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
    
    /// Converts a hex string to a 6-byte GUID (if valid)
    public static func fromHex(_ hex: String) -> Data? {
        guard let data = Data(hex: hex), data.count == 6 else {
            return nil
        }
        return data
    }
    
}
