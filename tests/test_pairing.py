import ipaddress
import json
import os
from pockterm.pairing import lan_ip, ensure_cert, qr_payload


def test_lan_ip_is_valid():
    ip = lan_ip()
    ipaddress.ip_address(ip)  # raises if invalid


def test_ensure_cert_creates_files_and_fingerprint(tmp_path):
    cert = tmp_path / "cert.pem"
    key = tmp_path / "key.pem"
    fp1 = ensure_cert(str(cert), str(key), "127.0.0.1")
    assert cert.exists() and key.exists()
    assert len(fp1) == 64  # sha256 hex
    fp2 = ensure_cert(str(cert), str(key), "127.0.0.1")  # idempotent
    assert fp1 == fp2


def test_qr_payload_shape():
    p = json.loads(qr_payload("192.168.1.5", 8422, "tok", "ab" * 32, "MyMac"))
    assert p == {"h": "192.168.1.5", "p": 8422, "t": "tok",
                 "fp": "ab" * 32, "n": "MyMac"}
