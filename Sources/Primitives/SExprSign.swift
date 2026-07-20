import Foundation
// filename: SExprSign.swift
//
// Canonical signing bytes for a (msg …) — ADR D12.
// Spec: protocol/specs/technical/signing.md §3.
//
// The canonical form MUST be byte-identical across the Swift and Python
// implementations: `(msg` + child fields sorted ascending by the child's head
// symbol (byte order), each serialized by the standard SExpr writer (single
// spaces, standard escapes, integral numbers without `.0`), + `)`. Any
// existing (sig …) child is dropped; (key-id …) is KEPT so the signer
// identity is bound into the signature. UTF-8 encoded.

extension SExpr {

    /// Canonical byte string of a `(msg …)` for signing/verification (D12 §3).
    /// Deterministic: independent of the original field order and of any
    /// attached `(sig …)`.
    public static func canonicalMsgBytes(_ msg: SExpr) -> Data {
        guard case .list(let items) = msg, !items.isEmpty else {
            return Data(msg.serialize().utf8)
        }
        let head = msg.head ?? "msg"
        // Child fields, excluding the head symbol and any (sig …). KEEP (key-id …).
        let fields = items.dropFirst().filter { $0.head != "sig" }
        // Sort ascending by the child's head symbol, comparing UTF-8 bytes.
        // (Index tiebreak keeps the sort deterministic for duplicate heads.)
        let sorted = fields.enumerated().sorted { a, b in
            let ka = Array((a.element.head ?? a.element.serialize()).utf8)
            let kb = Array((b.element.head ?? b.element.serialize()).utf8)
            if ka != kb { return byteLess(ka, kb) }
            return a.offset < b.offset
        }.map { $0.element }
        var out = "(" + head
        for f in sorted { out += " " + f.serialize() }
        out += ")"
        return Data(out.utf8)
    }

    /// Strict lexicographic byte-order comparison (NOT Unicode collation).
    private static func byteLess(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        for (x, y) in zip(a, b) where x != y { return x < y }
        return a.count < b.count
    }
}
