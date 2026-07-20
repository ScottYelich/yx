// filename: SExprTests.swift
// Protocol-0 S-expression reader/writer tests (ADR D11).
// Spec: protocol/specs/technical/protocol0-sexpr.md (V1: round-trip)

import XCTest
import Primitives

final class SExprTests: XCTestCase {

    // MARK: - Round-trip (parse → serialize → parse yields an equal tree)

    private func assertRoundTrip(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let first = SExpr.parse(text) else {
            XCTFail("parse failed: \(text)", file: file, line: line)
            return
        }
        let out = first.serialize()
        guard let second = SExpr.parse(out) else {
            XCTFail("re-parse failed: \(out)", file: file, line: line)
            return
        }
        XCTAssertEqual(first, second, "round-trip changed the tree for: \(text)", file: file, line: line)
    }

    func testRoundTripSpecV1Form() {
        // Spec §6 V1
        assertRoundTrip(#"(a (b "x y") (c 12) (d -3.5))"#)
    }

    func testRoundTripNested() {
        assertRoundTrip(#"(refs (commit "abc1234") (data (api (fn "composeData") (n 3))))"#)
    }

    func testRoundTripStringsWithSpacesAndEscapes() {
        assertRoundTrip(#"(body "line one\nline\ttwo \"quoted\" back\\slash a/b")"#)
        let e = SExpr.parse(#"(msg (body "a\"b\\c\nd\te\/f"))"#)
        XCTAssertEqual(e?.field("body")?.stringValue, "a\"b\\c\nd\te/f")
    }

    func testRoundTripNumbers() {
        assertRoundTrip("(nums 0 12 -3 4.25 -0.5 1000000)")
        XCTAssertEqual(SExpr.parse("42")?.numValue, 42)
        XCTAssertEqual(SExpr.parse("-3.5")?.numValue, -3.5)
        // Integral values serialize without a decimal point
        XCTAssertEqual(SExpr.num(12).serialize(), "12")
        XCTAssertEqual(SExpr.num(-3.5).serialize(), "-3.5")
    }

    func testSerializeMinimalWhitespace() {
        let text = "( a   ( b   \"x y\" )\n ( c 12 ) )"
        XCTAssertEqual(SExpr.parse(text)?.serialize(), #"(a (b "x y") (c 12))"#)
    }

    func testEmptyList() {
        XCTAssertEqual(SExpr.parse("()"), .list([]))
        XCTAssertEqual(SExpr.list([]).serialize(), "()")
    }

    // MARK: - Grammar details

    func testCommentsIgnored() {
        let text = """
        ;; presence beacon
        (node-hello ;; inline note
          (node "colossus"))
        """
        let e = SExpr.parse(text)
        XCTAssertEqual(e?.head, "node-hello")
        XCTAssertEqual(e?.field("node")?.stringValue, "colossus")
    }

    func testIncompleteFormFails() {
        XCTAssertNil(SExpr.parse("(a (b 1)"))      // depth never returns to 0
        XCTAssertNil(SExpr.parse("(a \"unterminated"))
        XCTAssertNil(SExpr.parse(""))
        XCTAssertNil(SExpr.parse("   ;; only a comment"))
    }

    func testSymbolCharacters() {
        XCTAssertEqual(SExpr.parse("node-hello")?.symValue, "node-hello")
        XCTAssertEqual(SExpr.parse("a.b_c-d2")?.symValue, "a.b_c-d2")
    }

    // MARK: - Accessors

    func testHeadAndField() {
        let e = SExpr.parse(#"(node-hello (node "colossus") (agents "colossus/claude-1,colossus/ops") (n 7))"#)!
        XCTAssertEqual(e.head, "node-hello")
        XCTAssertEqual(e.field("node")?.stringValue, "colossus")
        XCTAssertEqual(e.field("agents")?.stringValue, "colossus/claude-1,colossus/ops")
        XCTAssertEqual(e.field("n")?.numValue, 7)
        XCTAssertNil(e.field("missing"))
        XCTAssertNil(e.head.flatMap { _ in e.field("node")?.symValue })  // a string is not a symbol
    }

    func testAccessorsOnAtoms() {
        XCTAssertNil(SExpr.str("x").head)
        XCTAssertNil(SExpr.sym("x").field("a"))
        XCTAssertEqual(SExpr.str("x").stringValue, "x")
        XCTAssertNil(SExpr.str("x").symValue)
        XCTAssertNil(SExpr.sym("x").stringValue)
    }

    // MARK: - Realistic forms (message-format.md)

    func testParseRealisticMsg() {
        let text = """
        (msg (v 1) (id "b91c04d2") (type request) (from "colossus/claude-1") (to "laptop/claude")
          (created "2026-07-19T14:00:00Z") (priority high) (subject "need composeData()")
          (body "XNG query tool blocked; need composeData(query:) -> CompositionResult."))
        """
        guard let m = SExpr.parse(text) else { return XCTFail("msg parse failed") }
        XCTAssertEqual(m.head, "msg")
        XCTAssertEqual(m.field("v")?.numValue, 1)
        XCTAssertEqual(m.field("id")?.stringValue, "b91c04d2")
        XCTAssertEqual(m.field("type")?.symValue, "request")
        XCTAssertEqual(m.field("from")?.stringValue, "colossus/claude-1")
        XCTAssertEqual(m.field("to")?.stringValue, "laptop/claude")
        XCTAssertEqual(m.field("priority")?.symValue, "high")
        XCTAssertEqual(m.field("subject")?.stringValue, "need composeData()")
        assertRoundTrip(text)
    }

    func testParseNodeHello() {
        let e = SExpr.parse(#"(node-hello (node "studio") (agents "studio/claude"))"#)
        XCTAssertEqual(e?.head, "node-hello")
        XCTAssertEqual(e?.field("node")?.stringValue, "studio")
        XCTAssertEqual(e?.field("agents")?.stringValue, "studio/claude")
        assertRoundTrip(#"(node-hello (node "studio") (agents "studio/claude"))"#)
    }
}
