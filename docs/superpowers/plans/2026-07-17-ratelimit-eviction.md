# Rate-limit Map Eviction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unbounded `pair_hits` dict with a self-contained `RateLimiter` that evicts idle IPs, keeping the `/api/pair` limiter bounded — with identical HTTP behavior.

**Architecture:** Extract a `RateLimiter` class (sliding window + periodic idle-IP sweep, injected clock for testability) into `pockterm/rate_limit.py`, then wire it into `build_app`, deleting the in-closure dict.

**Tech Stack:** Python, pytest.

**Repo:** `~/pockterm`, branch `fix/5-ratelimit-eviction` (spec committed).

---

## File Structure

| File | Change |
|---|---|
| `pockterm/rate_limit.py` | New — `RateLimiter` (check/sweep/size) |
| `tests/test_rate_limit.py` | New — unit tests (injected clock) |
| `pockterm/server.py` | Swap the `pair_hits` dict + `_rate_limited` closure for `RateLimiter` |

No app/Flutter changes.

---

## Task 1: RateLimiter unit

**Files:**
- Create: `pockterm/rate_limit.py`
- Create: `tests/test_rate_limit.py`

- [ ] **Step 1: Write failing tests** — `tests/test_rate_limit.py`:
```python
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
    # a hit well past the window: the earlier three have aged out
    assert rl.check("a", now=200) is False


def test_idle_ips_are_evicted():
    rl = RateLimiter(limit=3, window=60)
    rl.check("a", now=0)
    assert rl.size() == 1
    # A different IP hitting after a full window triggers the sweep of idle A.
    rl.check("b", now=61)
    assert rl.size() == 1  # only b remains; a evicted


def test_active_ip_not_evicted():
    rl = RateLimiter(limit=3, window=60)
    rl.check("a", now=0)
    rl.check("a", now=61)   # a stays active across the sweep boundary
    rl.check("b", now=62)
    assert rl.size() == 2
```

- [ ] **Step 2: Run — verify FAILS**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_rate_limit.py -v`
Expected: `ModuleNotFoundError: pockterm.rate_limit`.

- [ ] **Step 3: Implement** — `pockterm/rate_limit.py`:
```python
from collections import defaultdict, deque


class RateLimiter:
    """Sliding-window per-IP limiter that evicts idle IPs to stay bounded."""

    def __init__(self, limit: int = 10, window: float = 60.0):
        self.limit = limit
        self.window = window
        self._hits: dict[str, deque] = defaultdict(deque)
        self._last_sweep = 0.0

    def check(self, ip: str, now: float) -> bool:
        """Record a hit from ip at time now; return True if ip is over the limit."""
        dq = self._hits[ip]
        while dq and dq[0] < now - self.window:
            dq.popleft()
        dq.append(now)
        if now - self._last_sweep >= self.window:
            self._sweep(now)
            self._last_sweep = now
        return len(dq) > self.limit

    def _sweep(self, now: float) -> None:
        stale = [ip for ip, d in self._hits.items()
                 if not d or d[-1] < now - self.window]
        for ip in stale:
            del self._hits[ip]

    def size(self) -> int:
        return len(self._hits)
```

- [ ] **Step 4: Run — verify PASSES**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_rate_limit.py -v`
Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add pockterm/rate_limit.py tests/test_rate_limit.py && git commit -m "feat: bounded RateLimiter with idle-IP eviction (#5)"
```

---

## Task 2: Wire RateLimiter into the server

**Files:**
- Modify: `pockterm/server.py`

- [ ] **Step 1: Swap the import**

At the top of `pockterm/server.py`, remove the now-unused collections import:
```python
from collections import defaultdict, deque
```
(Delete that entire line.) Then add, next to the other `from pockterm...` imports:
```python
from pockterm.rate_limit import RateLimiter
```

- [ ] **Step 2: Replace the state field**

In `build_app`, change:
```python
    app.state.pair_hits: dict[str, deque] = defaultdict(deque)
```
to:
```python
    app.state.limiter = RateLimiter()
```

- [ ] **Step 3: Delete the closure, call the limiter**

Delete the entire `_rate_limited` closure:
```python
    def _rate_limited(ip: str, limit: int = 10, window: float = 60.0) -> bool:
        now = time.time()
        hits = app.state.pair_hits[ip]
        while hits and hits[0] < now - window:
            hits.popleft()
        hits.append(now)
        return len(hits) > limit
```
Then in the `/api/pair` handler change:
```python
        if _rate_limited(ip):
```
to:
```python
        if app.state.limiter.check(ip, time.time()):
```
(Leave `import time` in place — it is still used here.)

- [ ] **Step 4: Run the pair-endpoint tests (HTTP behavior unchanged)**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_pair_endpoint.py -v`
Expected: 4 passed — including `test_pair_rate_limited_after_many_bad` (12 bad → a 429 appears), proving identical behavior.

- [ ] **Step 5: Run the whole suite**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest -q`
Expected: `33 passed, 1 skipped` (28 prior + 5 new rate-limit tests).

- [ ] **Step 6: Confirm no stale references remain**

Run: `cd /Users/harshwardhangokhale/pockterm && grep -n "pair_hits\|_rate_limited\|defaultdict\|deque" pockterm/server.py || echo "clean"`
Expected: `clean` (no leftover references to the old limiter in server.py).

- [ ] **Step 7: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add pockterm/server.py && git commit -m "refactor: use bounded RateLimiter for /api/pair (#5)"
```

---

## Task 3: Final verification

**Files:** none.

- [ ] **Step 1: Full suite green + scope check**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest -q 2>&1 | tail -2
git diff --name-only main...HEAD | grep -E "^app/" && echo "APP CHANGED — unexpected" || echo "app untouched"
```
Expected: `33 passed, 1 skipped`; then `app untouched`.

---

## Notes for the implementer

- The sweep is gated by `_last_sweep` so it runs at most once per `window` — do not sweep on every call (O(n) per request). The just-hit IP always has a `now` entry so it is never swept.
- Keep the default `RateLimiter()` values (limit=10, window=60) so the `/api/pair`
  behavior is byte-for-byte the same as before.
- `time` stays imported in `server.py` (used by `check(ip, time.time())` and possibly elsewhere); only the `collections` import is removed.
- Do not change the `x-forwarded-for` IP parsing or the 429 response shape.
