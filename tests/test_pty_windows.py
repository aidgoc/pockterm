import sys
import time
import pytest
from pockterm.pty_process import PtyProcess

pytestmark = pytest.mark.skipif(sys.platform != "win32", reason="Windows PTY test")


def test_windows_echo():
    # Spawn an interactive shell and type into it (mirrors the POSIX cat test).
    # A one-shot `cmd /c echo` exits before ConPTY flushes its rendered screen,
    # so the output races the process teardown — keep the PTY alive instead.
    proc = PtyProcess.spawn(["cmd.exe"])
    time.sleep(0.5)
    proc.write(b"echo hello_pockterm\r\n")
    out = b""
    end = time.time() + 6
    while time.time() < end:
        chunk = proc.read(4096)
        if chunk:
            out += chunk
            if b"hello_pockterm" in out:
                break
        else:
            time.sleep(0.05)
    proc.terminate()
    assert b"hello_pockterm" in out
