from pockterm.session import Session, SessionPool


def test_spawn_and_list(fake_pty_factory):
    pool = SessionPool(proc_factory=fake_pty_factory)
    pool.spawn("work", ["/bin/sh"])
    assert pool.list_names() == ["work"]


def test_spawn_existing_name_returns_same(fake_pty_factory):
    pool = SessionPool(proc_factory=fake_pty_factory)
    a = pool.spawn("x", ["/bin/sh"])
    b = pool.spawn("x", ["/bin/sh"])
    assert a is b
    assert len(fake_pty_factory.created) == 1


def test_replay_accumulates_and_caps():
    s = Session("s", proc=None, replay_max=10)
    s.append_replay(b"12345")
    s.append_replay(b"678901")  # total 11 bytes -> keep last 10
    assert s.replay() == b"2345678901"


def test_kill_removes_and_terminates(fake_pty_factory):
    pool = SessionPool(proc_factory=fake_pty_factory)
    pool.spawn("k", ["/bin/sh"])
    proc = fake_pty_factory.created[0]
    pool.kill("k")
    assert pool.list_names() == []
    assert proc.alive is False


def test_reap_drops_dead(fake_pty_factory):
    pool = SessionPool(proc_factory=fake_pty_factory)
    pool.spawn("d", ["/bin/sh"])
    fake_pty_factory.created[0]._alive = False
    pool.reap()
    assert pool.list_names() == []
