import Foundation
import CryptoKit

/// Mesh key resolution — implements ADR D08 / key-management.md §R6.
///
/// The HMAC mesh key IS mesh membership. It is resolved at runtime, never
/// hardcoded for production use. Resolution order (first hit wins):
///   1. explicit hex string  (--key flag; tests, overrides)
///   2. YX_KEY env variable  (CI, launchd EnvironmentVariables)
///   3. macOS Keychain       (service org.spy.yx, account = mesh name)
///   4. built-in dev key     (SHA256("shared-secret")) + LOUD warning
public enum MeshKey {

    public static let service = "org.spy.yx"
    public static let defaultMesh = "mesh"

    /// The built-in development key. Convenience only; using it logs a warning.
    public static var developmentKey: SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data("shared-secret".utf8)))
    }

    public enum Source: String { case explicit, environment, keychain, development }

    /// Resolve a 32-byte mesh key and report where it came from.
    public static func resolve(explicitHex: String? = nil,
                               mesh: String = defaultMesh,
                               env: [String: String] = ProcessInfo.processInfo.environment
    ) -> (key: SymmetricKey, source: Source) {
        if let hex = explicitHex, let d = decode(hex) {
            return (SymmetricKey(data: d), .explicit)
        }
        if let hex = env["YX_KEY"], let d = decode(hex) {
            return (SymmetricKey(data: d), .environment)
        }
        if let d = keychainGet(mesh: mesh) {
            return (SymmetricKey(data: d), .keychain)
        }
        FileHandle.standardError.write(Data(
            "⚠️  WARNING: using built-in development key — not for production. Set one with: yxkey generate\n".utf8))
        return (developmentKey, .development)
    }

    // MARK: - Hex

    /// Decode exactly 32 bytes from 64 hex chars, else nil.
    public static func decode(_ hex: String) -> Data? {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count == 64 else { return nil }
        var out = Data(capacity: 32)
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            guard let b = UInt8(s[i..<j], radix: 16) else { return nil }
            out.append(b); i = j
        }
        return out
    }

    public static func encode(_ key: SymmetricKey) -> String {
        key.withUnsafeBytes { Data($0).map { String(format: "%02x", $0) }.joined() }
    }

    // MARK: - Keychain (generic password via `security`)

    /// Reads via `security find-generic-password -w`. Kept subprocess-based so
    /// the Swift and Python implementations share the exact same store/format.
    public static func keychainGet(mesh: String) -> Data? {
        let out = runSecurity(["find-generic-password", "-s", service, "-a", mesh, "-w"])
        guard let hex = out?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else { return nil }
        return decode(hex)
    }

    @discardableResult
    public static func keychainSet(mesh: String, hex: String) -> Bool {
        guard decode(hex) != nil else { return false }
        // -U upserts (update if present)
        return runSecurity(["add-generic-password", "-s", service, "-a", mesh,
                            "-w", hex, "-U", "-l", "yx-mesh-\(mesh)"]) != nil
    }

    @discardableResult
    public static func keychainRemove(mesh: String) -> Bool {
        runSecurity(["delete-generic-password", "-s", service, "-a", mesh]) != nil
    }

    private static func runSecurity(_ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
