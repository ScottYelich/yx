import Foundation
// filename: SExpr.swift
//
// Protocol-0 S-expression value + reader + writer (ADR D11).
// Spec: protocol/specs/technical/protocol0-sexpr.md
//
// Grammar (the subset yx uses):
//   sexpr   := atom | list
//   list    := '(' ws? (sexpr (ws sexpr)*)? ws? ')'
//   atom    := symbol | string | number
//   symbol  := [A-Za-z][A-Za-z0-9._-]*
//   string  := '"' ( [^"\] | '\' ["\/nt] )* '"'     ; JSON-style escapes \" \\ \/ \n \t
//   number  := '-'? [0-9]+ ( '.' [0-9]+ )?
//   comment := ';;' ... end-of-line                  ; ignored between tokens
//
// Round-trip guarantee: parse → serialize → parse yields an equal tree.

public enum SExpr: Sendable, Equatable {
    case sym(String)
    case str(String)
    case num(Double)
    case list([SExpr])

    // MARK: - Reader

    /// Parses ONE balanced form from `text`. Completeness = paren depth back to 0.
    /// Leading whitespace/comments are skipped; trailing content is ignored.
    /// Returns nil on malformed or incomplete input.
    public static func parse(_ text: String) -> SExpr? {
        let chars = Array(text)
        var i = 0
        return parseForm(chars, &i)
    }

    private static func skipWS(_ chars: [Character], _ i: inout Int) {
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "\t" || c == "\n" || c == "\r" {
                i += 1
            } else if c == ";", i + 1 < chars.count, chars[i + 1] == ";" {
                while i < chars.count && chars[i] != "\n" { i += 1 }
            } else {
                break
            }
        }
    }

    private static func parseForm(_ chars: [Character], _ i: inout Int) -> SExpr? {
        skipWS(chars, &i)
        guard i < chars.count else { return nil }
        let c = chars[i]
        switch c {
        case "(":
            i += 1
            var items: [SExpr] = []
            while true {
                skipWS(chars, &i)
                guard i < chars.count else { return nil }  // unbalanced — incomplete form
                if chars[i] == ")" { i += 1; return .list(items) }
                guard let item = parseForm(chars, &i) else { return nil }
                items.append(item)
            }
        case "\"":
            return parseString(chars, &i)
        default:
            if c == "-" || (c.isASCII && c.isNumber) { return parseNumber(chars, &i) }
            if c.isASCII && c.isLetter { return parseSymbol(chars, &i) }
            return nil
        }
    }

    private static func parseString(_ chars: [Character], _ i: inout Int) -> SExpr? {
        i += 1  // opening quote
        var s = ""
        while i < chars.count {
            let c = chars[i]
            if c == "\"" { i += 1; return .str(s) }
            if c == "\\" {
                i += 1
                guard i < chars.count else { return nil }
                switch chars[i] {
                case "\"": s.append("\"")
                case "\\": s.append("\\")
                case "/":  s.append("/")
                case "n":  s.append("\n")
                case "t":  s.append("\t")
                default:   return nil  // unknown escape
                }
                i += 1
            } else {
                s.append(c)
                i += 1
            }
        }
        return nil  // unterminated string
    }

    private static func parseNumber(_ chars: [Character], _ i: inout Int) -> SExpr? {
        var s = ""
        if chars[i] == "-" { s.append("-"); i += 1 }
        var digits = 0
        while i < chars.count, chars[i].isASCII, chars[i].isNumber {
            s.append(chars[i]); i += 1; digits += 1
        }
        guard digits > 0 else { return nil }  // bare '-' is not a number
        if i + 1 < chars.count, chars[i] == ".", chars[i + 1].isASCII, chars[i + 1].isNumber {
            s.append("."); i += 1
            while i < chars.count, chars[i].isASCII, chars[i].isNumber {
                s.append(chars[i]); i += 1
            }
        }
        guard let d = Double(s) else { return nil }
        return .num(d)
    }

    private static func parseSymbol(_ chars: [Character], _ i: inout Int) -> SExpr? {
        var s = String(chars[i]); i += 1
        while i < chars.count {
            let c = chars[i]
            // "/" and ":" are legal symbol characters in every Lisp worth the
            // name, and real payloads are full of them -- "laptop/general",
            // "http://…", "12:30". Rejecting them made a peer's message
            // unparseable rather than merely ugly. Readers are tolerant; the
            // writer stays conservative.
            guard c.isASCII, c.isLetter || c.isNumber
                    || c == "." || c == "_" || c == "-" || c == "/" || c == ":"
            else { break }
            s.append(c); i += 1
        }
        return .sym(s)
    }

    // MARK: - Writer

    /// Serializes with one space between siblings and no superfluous whitespace
    /// (the light canonical form from the spec).
    public func serialize() -> String {
        switch self {
        case .sym(let s):
            return s
        case .str(let s):
            return "\"\(Self.escape(s))\""
        case .num(let d):
            if d == d.rounded(), d.magnitude < 1e15 {
                return String(Int64(d))
            }
            return String(d)
        case .list(let items):
            return "(" + items.map { $0.serialize() }.joined(separator: " ") + ")"
        }
    }

    private static func escape(_ s: String) -> String {
        var out = ""
        for c in s {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            default:   out.append(c)
            }
        }
        return out
    }

    // MARK: - Ergonomic accessors for the (verb (key val) …) shape

    /// The car symbol of a list, e.g. `(msg …)` → "msg".
    public var head: String? {
        if case .list(let items) = self, let first = items.first,
           case .sym(let s) = first {
            return s
        }
        return nil
    }

    /// The value of a `(key val)` child: finds the child list whose car symbol
    /// equals `name` and returns its SECOND element.
    /// e.g. from `(node-hello (node "colossus"))`, `field("node")` → `.str("colossus")`.
    public func field(_ name: String) -> SExpr? {
        guard case .list(let items) = self else { return nil }
        for item in items {
            if case .list(let inner) = item, inner.count >= 2,
               case .sym(let s) = inner[0], s == name {
                return inner[1]
            }
        }
        return nil
    }

    /// The string payload, if this is a `.str`.
    public var stringValue: String? {
        if case .str(let s) = self { return s }
        return nil
    }

    /// The symbol name, if this is a `.sym`.
    public var symValue: String? {
        if case .sym(let s) = self { return s }
        return nil
    }

    /// The numeric value, if this is a `.num`.
    public var numValue: Double? {
        if case .num(let d) = self { return d }
        return nil
    }
}

extension SExpr: CustomStringConvertible {
    public var description: String { serialize() }
}
