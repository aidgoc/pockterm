import pytest

pytest.importorskip("PIL")  # PNG output needs Pillow; skip where absent (CI backend)

from pockterm.qrimage import write_qr_png


def test_writes_a_png(tmp_path):
    p = str(tmp_path / "qr.png")
    write_qr_png('{"h":"1.2.3.4","p":8422,"t":"x","fp":"y","n":"z"}', p)
    with open(p, "rb") as f:
        head = f.read(8)
    assert head == b"\x89PNG\r\n\x1a\n"
