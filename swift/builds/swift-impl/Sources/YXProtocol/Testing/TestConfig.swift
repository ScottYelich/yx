import Foundation

// Implements: protocol/specs/technical/default-values.md (test_port = 49999)
// Implements: protocol/specs/testing/interoperability-requirements.md (Shared Configuration)

/// Shared test configuration for interop testing.
public struct TestConfig {

    /// Test port (default: 49999)
    public static var testPort: UInt16 {
        if let s = ProcessInfo.processInfo.environment["TEST_YX_PORT"],
           let p = UInt16(s) { return p }
        return 49999
    }

    /// Fixed 6-byte GUID for reproducible tests (0x01 × 6)
    public static var testGUID: Data { Data(repeating: 0x01, count: 6) }

    /// Fixed 32-byte key for reproducible tests (0x00 × 32)
    public static var testKey: Data { Data(repeating: 0x00, count: 32) }
}
