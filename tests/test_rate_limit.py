from pockterm.rate_limit import RateLimiter


def test_under_limit_is_allowed():
    rl = RateLimiter(limit=3, window=60)
    assert rl.check("a", now=0) is False
    assert rl.check("a", now=1) is False
    assert rl.check("a", now=2) is False  # 3rd hit, still within limit


def test_over_limit_is_flagged():
    rl = RateLimiter(limit=3, window=60)
    for t in range(3):
        rl.check("a", now=t)
    assert rl.check("a", now=3) is True  # 4th in-window hit exceeds limit=3


def test_old_hits_are_pruned():
    rl = RateLimiter(limit=3, window=60)
    for t in range(3):
        rl.check("a", now=t)  # hits at 0,1,2
    assert rl.check("a", now=200) is False  # earlier three aged out


def test_idle_ips_are_evicted():
    rl = RateLimiter(limit=3, window=60)
    rl.check("a", now=0)
    assert rl.size() == 1
    rl.check("b", now=61)  # sweeps idle A
    assert rl.size() == 1  # only b remains


def test_active_ip_not_evicted():
    rl = RateLimiter(limit=3, window=60)
    rl.check("a", now=0)
    rl.check("a", now=61)   # a stays active across the sweep boundary
    rl.check("b", now=62)
    assert rl.size() == 2
