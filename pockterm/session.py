from pockterm.pty_process import PtyProcess

REPLAY_MAX = 200_000


class Session:
    def __init__(self, name: str, proc, replay_max: int = REPLAY_MAX):
        self.name = name
        self.proc = proc
        self._replay = bytearray()
        self._replay_max = replay_max

    def append_replay(self, data: bytes) -> None:
        self._replay.extend(data)
        overflow = len(self._replay) - self._replay_max
        if overflow > 0:
            del self._replay[:overflow]

    def replay(self) -> bytes:
        return bytes(self._replay)


class SessionPool:
    def __init__(self, proc_factory=PtyProcess.spawn):
        self._proc_factory = proc_factory
        self._sessions: dict[str, Session] = {}

    def spawn(self, name: str, argv, cwd=None, env=None) -> Session:
        existing = self._sessions.get(name)
        if existing is not None:
            return existing
        proc = self._proc_factory(argv, cwd=cwd, env=env)
        session = Session(name, proc)
        self._sessions[name] = session
        return session

    def get(self, name: str) -> Session | None:
        return self._sessions.get(name)

    def list_names(self) -> list[str]:
        return list(self._sessions)

    def kill(self, name: str) -> None:
        session = self._sessions.pop(name, None)
        if session and session.proc is not None:
            session.proc.terminate()

    def reap(self) -> None:
        for name in list(self._sessions):
            proc = self._sessions[name].proc
            if proc is not None and not proc.alive:
                self._sessions.pop(name, None)
