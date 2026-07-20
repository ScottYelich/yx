import Foundation
// filename: TrustedSigners.swift
//
// Trusted-signers store — ADR D12 / signing.md §2.
//
// `~/.config/yx/trusted-signers.sxp`:
//   (trusted-signers
//     (signer (id "colossus/claude-1") (key "<base64-ed25519-pubkey>"))
//     …)
//
// A signer in this set is trusted for AUTHORITY (command/order execution).
// Missing file ⇒ empty map ⇒ nothing trusted (chat still open to the mesh).

public enum TrustedSigners {

    /// Default store path: ~/.config/yx/trusted-signers.sxp
    public static var defaultPath: String {
        NSHomeDirectory() + "/.config/yx/trusted-signers.sxp"
    }

    /// Load the store → [agentID: pubkeyB64]. Missing/unreadable/malformed
    /// file ⇒ empty (nothing trusted).
    public static func load(path: String = defaultPath) -> [String: String] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
        return parse(text)
    }

    /// Parse the (trusted-signers …) form from text (exposed for tests).
    public static func parse(_ text: String) -> [String: String] {
        guard let expr = SExpr.parse(text), expr.head == "trusted-signers",
              case .list(let items) = expr else { return [:] }
        var out: [String: String] = [:]
        for item in items.dropFirst() where item.head == "signer" {
            if let id = item.field("id")?.stringValue,
               let key = item.field("key")?.stringValue,
               !id.isEmpty, !key.isEmpty {
                out[id] = key
            }
        }
        return out
    }
}
