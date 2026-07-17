import os
from pockterm.secretstore import load_or_create_secret
from pockterm.auth import Auth


def test_creates_and_is_idempotent(tmp_path):
    p = str(tmp_path / "secret")
    s1 = load_or_create_secret(p)
    assert len(s1) == 32
    assert os.path.exists(p)
    assert load_or_create_secret(p) == s1  # same on second call


def test_mode_is_600(tmp_path):
    p = str(tmp_path / "secret")
    load_or_create_secret(p)
    assert (os.stat(p).st_mode & 0o777) == 0o600


def test_token_survives_simulated_restart(tmp_path):
    p = str(tmp_path / "secret")
    s = load_or_create_secret(p)
    tok = Auth(secret=s).make_session_token()
    s2 = load_or_create_secret(p)  # "restart": reload same secret
    assert Auth(secret=s2).verify_session_token(tok)
    assert not Auth(secret=os.urandom(32)).verify_session_token(tok)
