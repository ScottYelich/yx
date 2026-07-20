"""Ed25519 signing tests (ADR D12) — canonical bytes, fixture V3 cross-language
interop (Swift-made signature verifies in Python), trusted-signers store."""

import os

import pytest

from yx.primitives.sexpr import SExpr
from yx.primitives.sexpr_sign import canonical_msg_bytes
from yx.primitives import signer, trusted_signers

FIXTURE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "..", "tests", "fixtures", "sign-vector.sxp")

# A fixed test seed (32 bytes 0x00..0x1f, matching the fixture's seed).
SEED_B64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8="


@pytest.fixture(scope="module")
def vector():
    with open(FIXTURE, "r", encoding="utf-8") as f:
        v = SExpr.parse(f.read())
    assert v is not None and v.head == "sign-vector"
    return v


class TestFixtureV3:
    """signing.md V3: cross-language — the Swift-generated vector MUST
    reproduce in Python (same canonical bytes, Swift sig verifies)."""

    def test_canonical_bytes_match_fixture(self, vector):
        msg = vector.field("message")
        expected = vector.field("canonical").string_value.encode("utf-8")
        assert canonical_msg_bytes(msg) == expected

    def test_swift_signature_verifies(self, vector):
        msg = vector.field("message")
        sig = vector.field("sig").string_value
        pub = vector.field("public-key").string_value
        assert signer.verify(canonical_msg_bytes(msg), sig, pub) is True

    def test_pubkey_derives_from_seed(self, vector):
        seed = vector.field("seed").string_value
        assert signer.public_key_from_seed(seed) == vector.field("public-key").string_value

    def test_python_signature_of_fixture_verifies(self, vector):
        # Re-sign the fixture canonical bytes with the fixture seed; the
        # contract is VERIFY (CryptoKit signing is randomized), so we check
        # our own signature verifies with the fixture pubkey.
        msg = vector.field("message")
        seed = vector.field("seed").string_value
        pub = vector.field("public-key").string_value
        sig = signer.sign(canonical_msg_bytes(msg), seed_b64=seed)
        assert sig is not None and sig.startswith("ed25519:")
        assert signer.verify(canonical_msg_bytes(msg), sig, pub) is True


class TestCanonicalBytes:
    def test_field_order_independence(self):
        a = SExpr.parse('(msg (v 1) (id "x") (type command) (body "b"))')
        b = SExpr.parse('(msg (body "b") (type command) (id "x") (v 1))')
        assert canonical_msg_bytes(a) == canonical_msg_bytes(b)

    def test_sig_dropped_key_id_kept(self):
        unsigned = SExpr.parse('(msg (v 1) (key-id "a/b"))')
        signed = SExpr.parse('(msg (v 1) (key-id "a/b") (sig "ed25519:xx"))')
        c = canonical_msg_bytes(signed)
        assert c == canonical_msg_bytes(unsigned)
        assert b"sig" not in c
        assert b"key-id" in c

    def test_byte_order_sort(self):
        # 'Z' (0x5A) < 'a' (0x61) in raw byte order — NOT locale collation.
        m = SExpr.parse('(msg (a 1) (Z 2))')
        assert canonical_msg_bytes(m) == b"(msg (Z 2) (a 1))"

    def test_integral_numbers_canonicalize_without_dot_zero(self):
        m = SExpr.list_([SExpr.sym("msg"), SExpr.list_([SExpr.sym("v"), SExpr.num(1.0)])])
        assert canonical_msg_bytes(m) == b"(msg (v 1))"


class TestSignVerify:
    def test_sign_verify_round_trip(self):
        data = canonical_msg_bytes(SExpr.parse('(msg (v 1) (type command) (body "run"))'))
        sig = signer.sign(data, seed_b64=SEED_B64)
        pub = signer.public_key_from_seed(SEED_B64)
        assert sig is not None and pub is not None
        assert signer.verify(data, sig, pub) is True

    def test_tamper_fails(self):
        data = canonical_msg_bytes(SExpr.parse('(msg (v 1) (body "run"))'))
        sig = signer.sign(data, seed_b64=SEED_B64)
        pub = signer.public_key_from_seed(SEED_B64)
        tampered = data[:-2] + b'X)'
        assert signer.verify(tampered, sig, pub) is False

    def test_wrong_pubkey_fails(self):
        data = b"payload"
        sig = signer.sign(data, seed_b64=SEED_B64)
        other_seed = "//79/Pv6+fj39vX08/Lx8O/u7ezr6uno5+bl5OPi4eA="  # 0xff..0xe0
        other_pub = signer.public_key_from_seed(other_seed)
        assert other_pub is not None
        assert signer.verify(data, sig, other_pub) is False

    def test_malformed_inputs_fail_closed(self):
        pub = signer.public_key_from_seed(SEED_B64)
        assert signer.verify(b"x", "not-a-sig", pub) is False
        assert signer.verify(b"x", "ed25519:!!!not-base64!!!", pub) is False
        assert signer.verify(b"x", "ed25519:AAAA", pub) is False       # not 64 bytes
        sig = signer.sign(b"x", seed_b64=SEED_B64)
        assert signer.verify(b"x", sig, "AAAA") is False               # not 32 bytes
        assert signer.sign(b"x", seed_b64="short") is None
        assert signer.sign(b"x") is None                               # no key given


class TestTrustedSigners:
    STORE = ('(trusted-signers\n'
             '  (signer (id "colossus/claude-1") (key "PUB1"))\n'
             '  (signer (id "laptop/claude") (key "PUB2")))\n')

    def test_parse(self):
        m = trusted_signers.parse(self.STORE)
        assert m == {"colossus/claude-1": "PUB1", "laptop/claude": "PUB2"}

    def test_malformed_or_wrong_head_is_empty(self):
        assert trusted_signers.parse("(something-else)") == {}
        assert trusted_signers.parse("not an sexpr") == {}
        assert trusted_signers.parse('(trusted-signers (signer (id "") (key "k")))') == {}

    def test_load_missing_file_is_empty(self, tmp_path):
        assert trusted_signers.load(str(tmp_path / "nope.sxp")) == {}

    def test_load_file(self, tmp_path):
        p = tmp_path / "trusted-signers.sxp"
        p.write_text(self.STORE, encoding="utf-8")
        assert trusted_signers.load(str(p))["laptop/claude"] == "PUB2"
