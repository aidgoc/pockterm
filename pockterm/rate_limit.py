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
