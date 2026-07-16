# Bound the /api/pair rate-limit map — Design

**Date**: 2026-07-17
**Issue**: [#5](https://github.com/aidgoc/pockterm/issues/5)
**Status**: Approved (design), pending implementation plan

## Problem

`app.state.pair_hits` (`defaultdict(deque)`) in `pockterm/server.py` keeps one `deque`
per source IP that ever hits `/api/pair`, and never removes idle IPs — the map grows
unbounded. Immaterial on a LAN, but a real (if small) leak.

## Approach

Extract the limiter into a small, self-contained, testable unit
`pockterm/rate_limit.py` and replace the in-closure dict. A standalone class with an
injected clock lets us unit-test the acceptance criterion — that the map is bounded —
which the current closure cannot express.

## Component: `pockterm/rate_limit.py`

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

- `check` prunes the calling IP's window, records the hit, and — at most once per
  `window` (gated by `_last_sweep`) — sweeps every IP whose most recent hit is older
  than `window`, deleting those keys. Amortized O(n) at most once per window; the
  just-hit IP is never swept (its newest entry is `now`).
- Injected `now` makes all behavior deterministic and unit-testable without sleeping.

## Wiring in `pockterm/server.py`

- Remove `from collections import defaultdict, deque` (no longer used there) and add
  `from pockterm.rate_limit import RateLimiter`.
- In `build_app`: replace `app.state.pair_hits: dict[str, deque] = defaultdict(deque)`
  with `app.state.limiter = RateLimiter()`.
- Delete the `_rate_limited` closure; in the `/api/pair` handler replace
  `if _rate_limited(ip):` with `if app.state.limiter.check(ip, time.time()):`.
- Everything else (`x-forwarded-for` parsing, 429 body, pairing logic) is unchanged.

## Testing

`tests/test_rate_limit.py` (pure, injected `now`, no sleeps):
- **under limit** → `check` returns False for the first `limit` hits.
- **over limit** → the `limit + 1`-th in-window hit returns True.
- **window prune** → hits at `t=0` don't count against a hit at `t=window+1` (that
  later hit returns False even though `limit+1` total hits were recorded).
- **eviction** → hit IP-A at `t=0`; a hit from IP-B at `t=window+1` triggers a sweep
  that removes A → `size() == 1`.

The existing `tests/test_pair_endpoint.py::test_pair_rate_limited_after_many_bad`
(12 bad requests → a 429 appears) continues to pass unchanged, confirming the HTTP
behavior is identical.

## Non-goals

- No change to the limit/window values, the 429 response, or the pairing flow.
- No shared/persistent store (in-process is correct for a single-owner LAN server).
- No app/Flutter changes.
