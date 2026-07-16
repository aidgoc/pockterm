import sys
import time
import pytest
from pockterm.pty_process import PtyProcess

pytestmark = pytest.mark.skipif(sys.platform != "win32", reason="Windows PTY test")


def test_windows_echo():
    proc = PtyProcess.spawn(["cmd.exe", "/c", "echo hello_pockterm"])
    out = b""
    end = time.time() + 3
    while time.time() < end:
        chunk = proc.read(4096)
        if chunk:
            out += chunk
        else:
            time.sleep(0.05)
    assert b"hello_pockterm" in out
    proc.terminate()
