import os
import socket
from dataclasses import dataclass

import uvicorn

from pockterm.auth import Auth
from pockterm.pairing import ensure_cert, lan_ip, print_qr, qr_payload
from pockterm.secretstore import load_or_create_secret
from pockterm.server import build_app

DEFAULT_PORT = 8422
SESSION_TTL = 3650 * 24 * 3600  # ~10 years — pairing persists until "Forget"


@dataclass
class Runtime:
    app: object
    auth: Auth
    cert_path: str
    key_path: str
    fingerprint: str
    payload: str
    host: str
    port: int


def build_runtime(port: int = DEFAULT_PORT, state_dir: str | None = None) -> Runtime:
    state_dir = state_dir or os.path.expanduser("~/.pockterm")
    os.makedirs(state_dir, exist_ok=True)
    cert_path = os.path.join(state_dir, "cert.pem")
    key_path = os.path.join(state_dir, "key.pem")
    host = lan_ip()
    fp = ensure_cert(cert_path, key_path, host)
    secret = load_or_create_secret(os.path.join(state_dir, "secret"))
    auth = Auth(secret=secret, ttl=SESSION_TTL)
    name = socket.gethostname()
    payload = qr_payload(host, port, auth.pairing_token, fp, name)
    app = build_app(auth, pair_config={"host": host, "port": port,
                                        "fp": fp, "name": name})
    return Runtime(app, auth, cert_path, key_path, fp, payload, host, port)


def main() -> None:
    port = int(os.environ.get("POCKTERM_PORT", DEFAULT_PORT))
    rt = build_runtime(port=port)
    print(f"\n  pockterm on https://{rt.host}:{rt.port}")
    print("  Scan this with the pockterm app:\n")
    print_qr(rt.payload)
    print(f"\n  (or open https://{rt.host}:{rt.port}/pair)\n")
    uvicorn.run(rt.app, host="0.0.0.0", port=rt.port,
                ssl_certfile=rt.cert_path, ssl_keyfile=rt.key_path,
                ws="websockets-sansio", log_level="warning")


if __name__ == "__main__":
    main()
