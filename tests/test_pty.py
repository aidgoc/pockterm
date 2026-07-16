import sys
import time
import pytest
from pockterm.pty_process import PtyProcess

pytestmark = pytest.mark.skipif(sys.platform == "win32", reason="POSIX PTY test")


def _drain(proc, deadline=2.0):
    out = b""
    end = time.time() + deadline
    while time.time() < end:
        try:
            data = proc.read(4096)
        except OSError:
            break
        if data:
            out += data
        else:
            time.sleep(0.02)
    return out


def test_echo_roundtrip():
    proc = PtyProcess.spawn(["/bin/sh", "-c", "echo hello_pockterm"])
    out = _drain(proc)
    assert b"hello_pockterm" in out
    proc.terminate()


def test_write_and_read():
    proc = PtyProcess.spawn(["/bin/cat"])
    proc.write(b"ping\n")
    time.sleep(0.2)
    out = proc.read(4096)
    assert b"ping" in out
    proc.terminate()


def test_alive_then_dead():
    proc = PtyProcess.spawn(["/bin/sh", "-c", "exit 0"])
    _drain(proc, 1.0)
    time.sleep(0.2)
    assert proc.alive is False


def test_resize_no_error():
    proc = PtyProcess.spawn(["/bin/cat"])
    proc.resize(100, 40)
    proc.terminate()
