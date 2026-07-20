// filename: SigningTests.swift
// Ed25519 message signing tests (ADR D12).
// Spec: protocol/specs/technical/signing.md (V2 sign/verify, V3 fixture self-side)
//
// NOTE: CryptoKit's Ed25519 signing is randomized (same bytes → different,
// equally valid sigs), so "sig stability" is proven as: the fixture's stored
// signature verifies forever, and any fresh signature from the same seed
// verifies against the same canonical bytes + pubkey.
//
// Regenerate the cross-language fixture with:
//   YX_EMIT_VECTOR=1 swift test --filter SigningTests/testFixtureRoundTrip

import XCTest
import Primitives

final class SigningTests: XCTestCase {

    // Fixed 32-byte seed: bytes 0x00…0x1f.
    static let seedB64 = Data((0..<32).map { UInt8($0) }).base64EncodedString()

    /// The fixed test message (fields deliberately NOT in canonical order).
    static func fixtureMsg(withKeyID: Bool = true) -> SExpr {
        var children: [SExpr] = [
            .sym("msg"),
            .list([.sym("v"), .num(1)]),
            .list([.sym("id"), .str("cafebabe")]),
            .list([.sym("type"), .sym("command")]),
            .list([.sym("from"), .str("colossus/claude-1")]),
            .list([.sym("to"), .str("laptop/claude")]),
            .list([.sym("created"), .str("2026-07-19T12:00:00Z")]),
            .list([.sym("body"), .str("echo hello")]),
        ]
        if withKeyID { children.append(.list([.sym("key-id"), .str("colossus/claude-1")])) }
        return .list(children)
    }

    static var fixturePath: String {
        URL(fileURLWithPath: #filePath)               // …/Tests/yxTests/SigningTests.swift
            .deletingLastPathComponent()              // …/Tests/yxTests
            .deletingLastPathComponent()              // …/Tests
            .deletingLastPathComponent()              // repo root
            .appendingPathComponent("tests/fixtures/sign-vector.sxp").path
    }

    // MARK: - Canonical bytes (signing.md §3)

    func testCanonicalBytesSortedAndSigStripped() {
        let msg = Self.fixtureMsg()
        let canonical = String(data: SExpr.canonicalMsgBytes(msg), encoding: .utf8)
        XCTAssertEqual(canonical,
            #"(msg (body "echo hello") (created "2026-07-19T12:00:00Z") (from "colossus/claude-1") "#
            + #"(id "cafebabe") (key-id "colossus/claude-1") (to "laptop/claude") (type command) (v 1))"#)
    }

    func testCanonicalBytesDeterministicAcrossFieldOrder() {
        let msg = Self.fixtureMsg()
        // Same fields, shuffled order, with a (sig …) attached — canonical must be identical.
        guard case .list(let items) = msg else { return XCTFail("not a list") }
        var shuffled = Array(items.dropFirst()).shuffled()
        shuffled.append(.list([.sym("sig"), .str("ed25519:bogus")]))
        let reordered = SExpr.list([.sym("msg")] + shuffled)
        XCTAssertEqual(SExpr.canonicalMsgBytes(msg), SExpr.canonicalMsgBytes(reordered))
        // And repeated calls are byte-identical.
        XCTAssertEqual(SExpr.canonicalMsgBytes(msg), SExpr.canonicalMsgBytes(msg))
    }

    func testCanonicalBytesKeepKeyIDDropSig() {
        let without = String(data: SExpr.canonicalMsgBytes(Self.fixtureMsg(withKeyID: false)),
                             encoding: .utf8)!
        let with = String(data: SExpr.canonicalMsgBytes(Self.fixtureMsg()), encoding: .utf8)!
        XCTAssertFalse(without.contains("key-id"))
        XCTAssertTrue(with.contains(#"(key-id "colossus/claude-1")"#))
        XCTAssertFalse(with.contains("(sig"))
    }

    // MARK: - Sign / verify from a fixed seed (V2)

    func testSignVerifyFromFixedSeed() {
        let bytes = SExpr.canonicalMsgBytes(Self.fixtureMsg())
        guard let pub = Signer.publicKey(seedB64: Self.seedB64),
              let sig = Signer.sign(bytes, seedB64: Self.seedB64) else {
            return XCTFail("sign/pubkey from seed failed")
        }
        XCTAssertTrue(sig.hasPrefix("ed25519:"))
        XCTAssertTrue(Signer.verify(bytes, sig: sig, pubkeyB64: pub))
        // Fixed seed → fixed public key (key derivation is deterministic).
        XCTAssertEqual(pub, "A6EHv/POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg=")
        // A second signature (CryptoKit randomizes) must ALSO verify.
        guard let sig2 = Signer.sign(bytes, seedB64: Self.seedB64) else {
            return XCTFail("second sign failed")
        }
        XCTAssertTrue(Signer.verify(bytes, sig: sig2, pubkeyB64: pub))
    }

    func testTamperedContentFailsVerify() {
        let bytes = SExpr.canonicalMsgBytes(Self.fixtureMsg())
        guard let pub = Signer.publicKey(seedB64: Self.seedB64),
              let sig = Signer.sign(bytes, seedB64: Self.seedB64) else {
            return XCTFail("sign failed")
        }
        // Tamper the body → canonical bytes change → verify false.
        var tampered = Self.fixtureMsg()
        if case .list(var items) = tampered {
            items = items.map { child in
                child.head == "body" ? .list([.sym("body"), .str("echo pwned")]) : child
            }
            tampered = .list(items)
        }
        XCTAssertFalse(Signer.verify(SExpr.canonicalMsgBytes(tampered), sig: sig, pubkeyB64: pub))
        // Single-byte tamper of the raw bytes as well.
        var flipped = bytes; flipped[flipped.count - 2] ^= 0x01
        XCTAssertFalse(Signer.verify(flipped, sig: sig, pubkeyB64: pub))
    }

    func testWrongPubkeyFailsVerify() {
        let bytes = SExpr.canonicalMsgBytes(Self.fixtureMsg())
        let otherSeed = Data((0..<32).map { UInt8($0 &+ 1) }).base64EncodedString()
        guard let sig = Signer.sign(bytes, seedB64: Self.seedB64),
              let wrongPub = Signer.publicKey(seedB64: otherSeed) else {
            return XCTFail("setup failed")
        }
        XCTAssertFalse(Signer.verify(bytes, sig: sig, pubkeyB64: wrongPub))
        XCTAssertFalse(Signer.verify(bytes, sig: "ed25519:not-base64!!", pubkeyB64: wrongPub))
        XCTAssertFalse(Signer.verify(bytes, sig: "rsa:AAAA", pubkeyB64: wrongPub))
    }

    // MARK: - Trusted-signers store (signing.md §2)

    func testTrustedSignersParse() {
        let text = """
        ;; trust store
        (trusted-signers
          (signer (id "colossus/claude-1") (key "PUB1"))
          (signer (id "laptop/claude") (key "PUB2")))
        """
        let map = TrustedSigners.parse(text)
        XCTAssertEqual(map, ["colossus/claude-1": "PUB1", "laptop/claude": "PUB2"])
        XCTAssertEqual(TrustedSigners.parse("(other-form)"), [:])
        XCTAssertEqual(TrustedSigners.parse("garbage"), [:])
        XCTAssertEqual(TrustedSigners.load(path: "/nonexistent/trusted-signers.sxp"), [:])
    }

    // MARK: - Cross-language fixture round-trip (V3, self side)

    func testFixtureRoundTrip() throws {
        let path = Self.fixturePath
        if ProcessInfo.processInfo.environment["YX_EMIT_VECTOR"] == "1" {
            try Self.emitVector(to: path)
        }
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return XCTFail("fixture missing at \(path) — regenerate: YX_EMIT_VECTOR=1 swift test --filter SigningTests/testFixtureRoundTrip")
        }
        guard let vector = SExpr.parse(text), vector.head == "sign-vector",
              let message = vector.field("message"),
              let seed = vector.field("seed")?.stringValue,
              let pub = vector.field("public-key")?.stringValue,
              let canonical = vector.field("canonical")?.stringValue,
              let sig = vector.field("sig")?.stringValue else {
            return XCTFail("fixture malformed at \(path)")
        }
        // Canonical bytes recomputed from the embedded (msg …) match the stored string.
        let bytes = SExpr.canonicalMsgBytes(message)
        XCTAssertEqual(String(data: bytes, encoding: .utf8), canonical)
        // Public key derives from the seed.
        XCTAssertEqual(Signer.publicKey(seedB64: seed), pub)
        // Stored signature verifies over the canonical bytes (sig stability).
        XCTAssertTrue(Signer.verify(bytes, sig: sig, pubkeyB64: pub))
        // The (sig …) embedded in the message is the same signature and verifies too.
        XCTAssertEqual(message.field("sig")?.stringValue, sig)
        // key-id is bound into the signed bytes.
        XCTAssertTrue(canonical.contains("(key-id "))
        XCTAssertFalse(canonical.contains("(sig "))
        // A fresh signature from the fixture seed also verifies (re-signable from seed).
        if let fresh = Signer.sign(bytes, seedB64: seed) {
            XCTAssertTrue(Signer.verify(bytes, sig: fresh, pubkeyB64: pub))
        } else {
            XCTFail("could not re-sign from fixture seed")
        }
    }

    /// Generate tests/fixtures/sign-vector.sxp from this implementation.
    static func emitVector(to path: String) throws {
        let msg = fixtureMsg()
        let bytes = SExpr.canonicalMsgBytes(msg)
        guard let canonical = String(data: bytes, encoding: .utf8),
              let pub = Signer.publicKey(seedB64: seedB64),
              let sig = Signer.sign(bytes, seedB64: seedB64),
              Signer.verify(bytes, sig: sig, pubkeyB64: pub) else {
            throw NSError(domain: "yx.sign-vector", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "vector generation failed"])
        }
        guard case .list(let items) = msg else { fatalError("fixture msg not a list") }
        let signedMsg = SExpr.list(items + [.list([.sym("sig"), .str(sig)])])
        let vector = SExpr.list([
            .sym("sign-vector"),
            .list([.sym("message"), signedMsg]),
            .list([.sym("seed"), .str(seedB64)]),
            .list([.sym("public-key"), .str(pub)]),
            .list([.sym("canonical"), .str(canonical)]),
            .list([.sym("sig"), .str(sig)]),
        ])
        let header = """
        ;; yx cross-language signing test vector (ADR D12 / signing.md V3).
        ;; Generated by the Swift implementation (SigningTests.emitVector).
        ;; seed = base64 of the 32-byte Ed25519 seed; canonical = the exact UTF-8
        ;; signing bytes for (message …); sig = a valid detached signature.
        ;; NOTE: Ed25519 signing may be randomized (CryptoKit) — verify against
        ;; `sig`; do NOT expect re-signing to reproduce it byte-for-byte.

        """
        try FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try (header + vector.serialize() + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
}
