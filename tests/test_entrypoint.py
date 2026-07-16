from pockterm.__main__ import build_runtime


def test_build_runtime_returns_app_and_meta(tmp_path):
    rt = build_runtime(port=8500, state_dir=str(tmp_path))
    assert rt.app is not None
    assert rt.cert_path.endswith("cert.pem")
    assert rt.key_path.endswith("key.pem")
    assert len(rt.fingerprint) == 64
    assert rt.payload  # non-empty QR payload string
