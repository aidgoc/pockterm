import time
from pockterm.auth import Auth


def test_pairing_token_verifies():
    a = Auth()
    assert a.verify_pairing(a.pairing_token)
    assert not a.verify_pairing("wrong")


def test_rotate_changes_pairing_token():
    a = Auth()
    old = a.pairing_token
    new = a.rotate_pairing()
    assert new != old
    assert not a.verify_pairing(old)
    assert a.verify_pairing(new)


def test_session_token_roundtrip():
    a = Auth()
    tok = a.make_session_token()
    assert a.verify_session_token(tok)


def test_session_token_rejects_tampered():
    a = Auth()
    tok = a.make_session_token()
    bad = tok[:-2] + ("aa" if not tok.endswith("aa") else "bb")
    assert not a.verify_session_token(bad)


def test_session_token_expires():
    a = Auth(ttl=-1)
    tok = a.make_session_token()
    assert not a.verify_session_token(tok)


def test_session_token_from_other_secret_rejected():
    tok = Auth().make_session_token()
    assert not Auth().verify_session_token(tok)
