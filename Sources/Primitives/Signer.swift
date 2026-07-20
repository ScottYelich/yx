import Foundation
import CryptoKit
// filename: Signer.swift
//
// Ed25519 message signing — ADR D12 / signing.md §1.
//
// Private keys live in the macOS Keychain (generic password, service
// `org.spy.yx.sig`, account = <agent-id>, value = base64 of the 32-byte
// seed). Mirrors the MeshKey `security`-subprocess pattern so the Swift and
// Python implementations share the exact same store/format. Public key =
// base64 of the 32 raw bytes; signatures are "ed25519:<base64 64-byte sig>".
//
// NOTE: CryptoKit's Ed25519 signing is randomized (RFC 8032-verifiable, but
// signing the same bytes twice yields different — equally valid — signatures).
// Fixture stability therefore rests on the canonical bytes + verification,
// not on byte-identical re-signing.

public enum Signer {

    public static let service = "org.spy.yx.sig"
    public static let sigPrefix = "ed25519:"

    // MARK: - Key management (Keychain-backed)

    /// Generate a keypair for `agentID`, store the private seed in the
    /// Keychain, and return the public key (base64, 32 raw bytes).
    public static func generate(agentID: String) -> String? {
        let key = Curve25519.Signing.PrivateKey()
        let seedB64 = key.rawRepresentation.base64EncodedString()
        guard keychainSet(agentID: agentID, seedB64: seedB64) else { return nil }
        return key.publicKey.rawRepresentation.base64EncodedString()
    }

    /// The stored public key for `agentID` (base64), or nil if absent.
    public static func publicKey(agentID: String) -> String? {
        privateKey(agentID: agentID)?.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Agent-ids with signing keys present in the Keychain (sorted).
    public static func list() -> [String] {
        guard let dump = runSecurity(["dump-keychain"]) else { return [] }
        // Attributes are alphabetical, so "acct" precedes "svce" within an item.
        func quoted(_ s: Substring) -> String? {
            guard let r = s.range(of: "=\"", options: .backwards), s.hasSuffix("\"") else { return nil }
            return String(s[r.upperBound...].dropLast())
        }
        var ids = Set<String>(); var pendingAcct: String? = nil
        for line in dump.split(separator: "\n") {
            if line.contains("\"acct\"<blob>=") { pendingAcct = quoted(line) }
            if line.contains("\"svce\"<blob>=\"\(service)\""), let a = pendingAcct {
                ids.insert(a)
            }
        }
        return ids.sorted()
    }

    /// Delete the signing key for `agentID`.
    @discardableResult
    public static func remove(agentID: String) -> Bool {
        runSecurity(["delete-generic-password", "-s", service, "-a", agentID]) != nil
    }

    // MARK: - Sign / verify

    /// Sign `bytes` with the Keychain key for `agentID` → "ed25519:<base64>".
    public static func sign(_ bytes: Data, agentID: String) -> String? {
        privateKey(agentID: agentID).flatMap { sign(bytes, privateKey: $0) }
    }

    /// Sign `bytes` with an explicit 32-byte seed (base64) — tests/fixtures.
    public static func sign(_ bytes: Data, seedB64: String) -> String? {
        privateKey(seedB64: seedB64).flatMap { sign(bytes, privateKey: $0) }
    }

    /// Public key (base64) derived from an explicit seed — tests/fixtures.
    public static func publicKey(seedB64: String) -> String? {
        privateKey(seedB64: seedB64)?.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Verify an "ed25519:<base64>" signature over `bytes` with a base64 pubkey.
    public static func verify(_ bytes: Data, sig: String, pubkeyB64: String) -> Bool {
        guard sig.hasPrefix(sigPrefix),
              let sigData = Data(base64Encoded: String(sig.dropFirst(sigPrefix.count))),
              sigData.count == 64,
              let pubData = Data(base64Encoded: pubkeyB64), pubData.count == 32,
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData)
        else { return false }
        return pub.isValidSignature(sigData, for: bytes)
    }

    // MARK: - Internals

    private static func sign(_ bytes: Data, privateKey: Curve25519.Signing.PrivateKey) -> String? {
        guard let sig = try? privateKey.signature(for: bytes) else { return nil }
        return sigPrefix + sig.base64EncodedString()
    }

    private static func privateKey(seedB64: String) -> Curve25519.Signing.PrivateKey? {
        guard let seed = Data(base64Encoded: seedB64), seed.count == 32 else { return nil }
        return try? Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    }

    private static func privateKey(agentID: String) -> Curve25519.Signing.PrivateKey? {
        guard let b64 = keychainGet(agentID: agentID) else { return nil }
        return privateKey(seedB64: b64)
    }

    // MARK: - Keychain (generic password via `security`, mirroring MeshKey)

    static func keychainGet(agentID: String) -> String? {
        let out = runSecurity(["find-generic-password", "-s", service, "-a", agentID, "-w"])
        guard let b64 = out?.trimmingCharacters(in: .whitespacesAndNewlines), !b64.isEmpty else { return nil }
        return b64
    }

    @discardableResult
    static func keychainSet(agentID: String, seedB64: String) -> Bool {
        // -U upserts (update if present)
        runSecurity(["add-generic-password", "-s", service, "-a", agentID,
                     "-w", seedB64, "-U", "-l", "yx-sig-\(agentID)"]) != nil
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
