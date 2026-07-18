import os


def load_or_create_secret(path: str) -> bytes:
    """Return the persisted 32-byte signing secret, creating it (0600) if absent."""
    if os.path.exists(path):
        with open(path, "rb") as f:
            data = f.read()
        if len(data) == 32:
            return data
    secret = os.urandom(32)
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "wb") as f:
        f.write(secret)
    os.chmod(path, 0o600)
    return secret
