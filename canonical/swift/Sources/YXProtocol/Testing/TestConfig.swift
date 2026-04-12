import Foundation

/// Shared test configuration for interop testing.
///
/// Traceability:
/// - protocol/specs/architecture/api-contracts.md § Test Configuration
public struct TestConfig {

    /// Test UDP port (override via TEST_YX_PORT env var)
    public static var testPort: UInt16 {
        if let portStr = ProcessInfo.processInfo.environment["TEST_YX_PORT"],
           let port = UInt16(portStr) {
            return port
        }
        return 49999
    }

    /// Test GUID (6 bytes, all 0x01)
    public static var testGUID: Data {
        return Data(repeating: 0x01, count: 6)
    }

    /// Test HMAC key (32 bytes, all 0x00)
    public static var testKey: Data {
        return Data(repeating: 0x00, count: 32)
    }

    /// Test encryption key (32 bytes, all 0x42)
    public static var testEncryptionKey: Data {
        return Data(repeating: 0x42, count: 32)
    }

    /// Test host
    public static var testHost: String {
        return "127.0.0.1"
    }
}
