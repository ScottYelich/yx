"""S-expression parser/writer tests (ADR D11) — mirrors the Swift SExpr behavior."""

from yx.primitives.sexpr import SExpr


class TestParse:
    def test_round_trip_spec_v1(self):
        # protocol0-sexpr.md V1: parser round-trips (a (b "x y") (c 12) (d -3.5))
        text = '(a (b "x y") (c 12) (d -3.5))'
        e = SExpr.parse(text)
        assert e is not None
        assert e.serialize() == text
        assert SExpr.parse(e.serialize()) == e

    def test_atoms(self):
        assert SExpr.parse("msg") == SExpr.sym("msg")
        assert SExpr.parse('"hello"') == SExpr.string("hello")
        assert SExpr.parse("42") == SExpr.num(42)
        assert SExpr.parse("-3.5") == SExpr.num(-3.5)

    def test_symbol_charset(self):
        assert SExpr.parse("node-hello.v1_x") == SExpr.sym("node-hello.v1_x")
        # symbols must start with a letter
        assert SExpr.parse("_x") is None
        assert SExpr.parse("(a 1x)") is None or SExpr.parse("(a 1x)") != SExpr.list_(
            [SExpr.sym("a"), SExpr.sym("1x")])

    def test_string_escapes(self):
        assert SExpr.parse(r'"a\"b"') == SExpr.string('a"b')
        assert SExpr.parse(r'"a\\b"') == SExpr.string("a\\b")
        assert SExpr.parse(r'"a\/b"') == SExpr.string("a/b")
        assert SExpr.parse(r'"a\nb"') == SExpr.string("a\nb")
        assert SExpr.parse(r'"a\tb"') == SExpr.string("a\tb")
        assert SExpr.parse(r'"a\qb"') is None  # unknown escape

    def test_unterminated_and_unbalanced(self):
        assert SExpr.parse('"abc') is None       # unterminated string
        assert SExpr.parse("(a (b 1)") is None   # unbalanced list (incomplete)
        assert SExpr.parse("") is None
        assert SExpr.parse("-") is None          # bare '-' is not a number

    def test_comments_and_whitespace(self):
        e = SExpr.parse(";; header comment\n  (a ;; trailing\n 1)\n;; after")
        assert e == SExpr.list_([SExpr.sym("a"), SExpr.num(1)])

    def test_nested(self):
        e = SExpr.parse('(msg (data (api (fn "composeData"))))')
        assert e is not None
        assert e.field("data").head == "api"

    def test_trailing_content_ignored(self):
        assert SExpr.parse("(a 1) extra") == SExpr.list_([SExpr.sym("a"), SExpr.num(1)])


class TestSerialize:
    def test_integral_numbers_without_dot_zero(self):
        assert SExpr.num(1.0).serialize() == "1"
        assert SExpr.num(-7.0).serialize() == "-7"
        assert SExpr.num(0).serialize() == "0"

    def test_fractional_numbers(self):
        assert SExpr.num(-3.5).serialize() == "-3.5"
        assert SExpr.num(0.25).serialize() == "0.25"

    def test_string_escaping(self):
        assert SExpr.string('a"b\\c\nd\te').serialize() == r'"a\"b\\c\nd\te"'
        # '/' is NOT escaped on output (matches the Swift writer)
        assert SExpr.string("a/b").serialize() == '"a/b"'

    def test_single_space_between_siblings(self):
        e = SExpr.parse("( a   1\n\t2 )")
        assert e.serialize() == "(a 1 2)"

    def test_empty_list(self):
        assert SExpr.list_([]).serialize() == "()"


class TestAccessors:
    def test_head_and_field(self):
        e = SExpr.parse('(node-hello (node "colossus") (agents "a,b"))')
        assert e.head == "node-hello"
        assert e.field("node").string_value == "colossus"
        assert e.field("agents").string_value == "a,b"
        assert e.field("missing") is None

    def test_value_accessors(self):
        e = SExpr.parse('(msg (v 1) (type request) (id "x"))')
        assert e.field("v").num_value == 1
        assert e.field("type").sym_value == "request"
        assert e.field("id").string_value == "x"
        # wrong-kind accessors return None
        assert e.field("v").string_value is None
        assert e.field("id").num_value is None

    def test_head_of_atom_is_none(self):
        assert SExpr.sym("a").head is None
        assert SExpr.parse('("str" 1)').head is None
