import os
import sys

IS_WINDOWS = sys.platform == "win32"

if not IS_WINDOWS:
    import fcntl
    import pty
    import signal
    import struct
    import termios


class PtyProcess:
    """A running child attached to a PTY. bytes in, bytes out."""

    def __init__(self, pid: int, fd: int):
        self.pid = pid
        self.fd = fd
        self._dead = False

    @classmethod
    def spawn(cls, argv, cwd=None, env=None):
        if IS_WINDOWS:
            raise NotImplementedError("Windows branch added in Task 12")
        pid, fd = pty.fork()
        if pid == 0:  # child
            try:
                if cwd:
                    os.chdir(cwd)
                os.execvpe(argv[0], argv, env or os.environ.copy())
            except Exception:
                os._exit(127)
        # parent
        os.set_blocking(fd, False)
        return cls(pid, fd)

    def read(self, size: int = 65536) -> bytes:
        try:
            return os.read(self.fd, size)
        except BlockingIOError:
            return b""

    def write(self, data: bytes) -> None:
        os.write(self.fd, data)

    def resize(self, cols: int, rows: int) -> None:
        winsize = struct.pack("HHHH", rows, cols, 0, 0)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, winsize)

    @property
    def alive(self) -> bool:
        if self._dead:
            return False
        try:
            pid, _ = os.waitpid(self.pid, os.WNOHANG)
        except ChildProcessError:
            self._dead = True
            return False
        if pid == self.pid:
            self._dead = True
            return False
        return True

    def terminate(self) -> None:
        try:
            os.kill(self.pid, signal.SIGTERM)
        except (ProcessLookupError, OSError):
            pass
        try:
            os.close(self.fd)
        except OSError:
            pass
        self._dead = True
