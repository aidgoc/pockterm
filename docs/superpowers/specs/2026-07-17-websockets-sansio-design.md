# Migrate off websockets.legacy — Design

**Date**: 2026-07-17
**Issue**: [#3](https://github.com/aidgoc/pockterm/issues/3)
**Status**: Approved (design), pending implementation plan

## Problem

uvicorn 0.34.0 serves our `/ws` endpoint through its `websockets` implementation,
which imports the deprecated `websockets.legacy` module — the source of ~119
`DeprecationWarning`s during `pytest`. The library will eventually remove the legacy
code path.

## Approach

Bump uvicorn and select its **sans-io** websockets implementation. Pockterm's code
only uses Starlette's `WebSocket` abstraction, so the underlying protocol
implementation is swappable transparently — this is a dependency + config change,
**no server logic changes**.

Verified: uvicorn **0.51.0** exposes `websockets-sansio` in `WS_PROTOCOLS`, and it
imports with zero deprecation against our pinned `websockets==14.1`.

## Changes

1. `requirements.txt`: `uvicorn[standard]==0.34.0` → `uvicorn[standard]==0.51.0`.
   Keep `websockets==14.1` (compatible with the sansio impl — confirmed).
2. `pockterm/__main__.py`: the `uvicorn.run(...)` call gains `ws="websockets-sansio"`.
3. `tests/test_ws.py`: the `uvicorn.Config(...)` gains `ws="websockets-sansio"` so the
   test server exercises the same path production uses.
4. `pytest.ini`: add a **scoped** regression guard:
   ```ini
   filterwarnings =
       error:.*websockets\.legacy.*:DeprecationWarning
   ```
   This turns *only* `websockets.legacy` deprecations into test failures, so a future
   regression fails CI. Unrelated deprecations (e.g. pytest-asyncio's
   `get_event_loop_policy`) are untouched.

## Verification

- `pytest -q` passes **and** the scoped filter guarantees no `websockets.legacy`
  warning survives (any such warning becomes a hard error).
- Manual TLS smoke: `python -m pockterm` serves; `curl -k https://127.0.0.1:8422/health`
  returns ok; QR renders.
- CI matrix (Linux backend + Windows/pywinpty backend + Flutter) green — the uvicorn
  bump is re-verified on every platform.

## Non-goals / risk

- No `websockets` version bump; no `wsproto`; no app/Flutter changes; no server logic
  changes.
- Only real risk is the uvicorn 0.34→0.51 bump; it is independent of FastAPI 0.115 and
  covered by CI on all three targets.
