import qrcode


def write_qr_png(payload: str, path: str) -> None:
    """Render payload to a scannable PNG at path (requires Pillow)."""
    qrcode.make(payload).save(path)
