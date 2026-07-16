import pytest
from fastapi.testclient import TestClient
from pockterm.server import build_app
from pockterm.auth import Auth


def make_client():
    auth = Auth()
    app = build_app(auth, pair_config={"host": "127.0.0.1", "port": 8422,
                                        "fp": "ab" * 32, "name": "Test"})
    return auth, TestClient(app)


def test_pair_with_good_token_returns_session_token():
    auth, client = make_client()
    r = client.post("/api/pair", json={"token": auth.pairing_token})
    assert r.status_code == 200
    body = r.json()
    assert auth.verify_session_token(body["token"])
    assert body["name"] == "Test"


def test_pair_with_bad_token_401():
    auth, client = make_client()
    r = client.post("/api/pair", json={"token": "wrong"})
    assert r.status_code == 401


def test_pair_rate_limited_after_many_bad():
    auth, client = make_client()
    codes = [client.post("/api/pair", json={"token": "x"}).status_code
             for _ in range(12)]
    assert 429 in codes


def test_pair_page_served():
    auth, client = make_client()
    r = client.get("/pair")
    assert r.status_code == 200
    assert "pockterm" in r.text.lower()
