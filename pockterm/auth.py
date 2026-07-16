import base64
import hashlib
import hmac
import os
import secrets
import time


def _b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip("=")


class Auth:
    """Pairing token (rotates each server start) + signed session tokens."""

    def __init__(self, secret: bytes | None = None, ttl: int = 7 * 24 * 3600):
        self.secret = secret or os.urandom(32)
        self.ttl = ttl
        self.pairing_token = _b64(secrets.token_bytes(32))

    def rotate_pairing(self) -> str:
        self.pairing_token = _b64(secrets.token_bytes(32))
        return self.pairing_token

    def verify_pairing(self, token: str) -> bool:
        return bool(token) and hmac.compare_digest(token, self.pairing_token)

    def make_session_token(self) -> str:
        exp = str(int(time.time()) + self.ttl)
        sig = hmac.new(self.secret, exp.encode(), hashlib.sha256).digest()
        return f"{exp}.{_b64(sig)}"

    def verify_session_token(self, token: str) -> bool:
        if not token or "." not in token:
            return False
        exp_s, sig_s = token.split(".", 1)
        try:
            if int(exp_s) < time.time():
                return False
        except ValueError:
            return False
        expected = hmac.new(self.secret, exp_s.encode(), hashlib.sha256).digest()
        return hmac.compare_digest(_b64(expected), sig_s)
