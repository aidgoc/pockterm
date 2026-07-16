import pytest


class FakePty:
    """In-memory stand-in for PtyProcess. Echoes writes to its read buffer."""

    def __init__(self, argv=None, cwd=None, env=None):
        self.argv = argv
        self.cwd = cwd
        self._buf = bytearray()
        self._alive = True
        self.resized = None

    def feed(self, data: bytes):
        self._buf.extend(data)

    def read(self, size=65536) -> bytes:
        out = bytes(self._buf[:size])
        del self._buf[:size]
        return out

    def write(self, data: bytes):
        self._buf.extend(data)

    def resize(self, cols, rows):
        self.resized = (cols, rows)

    @property
    def alive(self):
        return self._alive

    def terminate(self):
        self._alive = False


@pytest.fixture
def fake_pty_factory():
    created = []

    def factory(argv, cwd=None, env=None):
        p = FakePty(argv, cwd, env)
        created.append(p)
        return p

    factory.created = created
    return factory
