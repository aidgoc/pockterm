# Migrate off websockets.legacy — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve `/ws` through uvicorn's sans-io websockets implementation so the deprecated `websockets.legacy` path is no longer used, and guard against regression.

**Architecture:** Pockterm uses Starlette's `WebSocket` abstraction, so the protocol implementation is swappable via uvicorn config. Bump uvicorn to 0.51.0 and pass `ws="websockets-sansio"` at both the production entrypoint and the test server. A scoped `pytest` warning filter turns any future `websockets.legacy` deprecation into a hard failure. No server logic changes.

**Tech Stack:** Python, uvicorn, FastAPI/Starlette, pytest.

**Repo:** `~/pockterm`, branch `fix/3-websockets-sansio` (spec already committed).

---

## File Structure

| File | Change |
|---|---|
| `pytest.ini` | scoped `filterwarnings` making `websockets.legacy` deprecations errors |
| `requirements.txt` | `uvicorn[standard]==0.34.0` → `==0.51.0` |
| `pockterm/__main__.py` | `uvicorn.run(...)` gains `ws="websockets-sansio"` |
| `tests/test_ws.py` | `uvicorn.Config(...)` gains `ws="websockets-sansio"` |

No new files; no app/Flutter changes; no server logic changes.

---

## Task 1: Add the regression guard, migrate the ws implementation

**Files:**
- Modify: `pytest.ini`
- Modify: `requirements.txt`
- Modify: `pockterm/__main__.py`
- Modify: `tests/test_ws.py`

- [ ] **Step 1: Add the failing guard** — append a scoped `filterwarnings` to `pytest.ini`

Change `pytest.ini` from:
```ini
[pytest]
testpaths = tests
asyncio_mode = auto
asyncio_default_fixture_loop_scope = function
```
to:
```ini
[pytest]
testpaths = tests
asyncio_mode = auto
asyncio_default_fixture_loop_scope = function
filterwarnings =
    error:.*websockets\.legacy.*:DeprecationWarning
```

- [ ] **Step 2: Run — verify it now FAILS on the current (legacy) impl**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_ws.py -q`
Expected: FAILURES/errors — the running server emits a `websockets.legacy` DeprecationWarning which the filter has turned into an error. (This proves the guard actually catches the legacy path. If instead it passes, stop and report — the warning is not being surfaced and the guard is ineffective.)

- [ ] **Step 3: Bump uvicorn and install**

Change `requirements.txt` line:
```
uvicorn[standard]==0.34.0
```
to:
```
uvicorn[standard]==0.51.0
```
Then upgrade the venv:
```bash
cd /Users/harshwardhangokhale/pockterm && .venv/bin/pip install -q -r requirements.txt
```
Expected: uvicorn upgrades to 0.51.0 cleanly (websockets stays at 14.1). Verify:
`.venv/bin/python -c "import uvicorn; print(uvicorn.__version__)"` → `0.51.0`.

- [ ] **Step 4: Select the sans-io impl in the production entrypoint**

In `pockterm/__main__.py`, change:
```python
    uvicorn.run(rt.app, host="0.0.0.0", port=rt.port,
                ssl_certfile=rt.cert_path, ssl_keyfile=rt.key_path,
                log_level="warning")
```
to:
```python
    uvicorn.run(rt.app, host="0.0.0.0", port=rt.port,
                ssl_certfile=rt.cert_path, ssl_keyfile=rt.key_path,
                ws="websockets-sansio", log_level="warning")
```

- [ ] **Step 5: Select the sans-io impl in the test server**

In `tests/test_ws.py`, change:
```python
    config = uvicorn.Config(app, host="127.0.0.1", port=8799, log_level="warning")
```
to:
```python
    config = uvicorn.Config(app, host="127.0.0.1", port=8799,
                            ws="websockets-sansio", log_level="warning")
```

- [ ] **Step 6: Run — verify the guard now PASSES**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_ws.py -q`
Expected: all `test_ws.py` tests pass, no legacy-warning error.

- [ ] **Step 7: Run the whole suite**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest -q`
Expected: `28 passed, 1 skipped` (unchanged count). No `websockets.legacy` warnings.

- [ ] **Step 8: Confirm the sans-io path is actually what runs (belt-and-suspenders)**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && .venv/bin/python -W error::DeprecationWarning -c "from uvicorn.protocols.websockets.websockets_sansio_impl import WebSocketsSansIOProtocol; print('sansio import ok')"
```
Expected: `sansio import ok` (imports with no deprecation).

- [ ] **Step 9: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add pytest.ini requirements.txt pockterm/__main__.py tests/test_ws.py && git commit -m "refactor: serve ws via websockets-sansio; guard against legacy (#3)"
```

---

## Task 2: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Full suite is green and legacy-free**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest -q 2>&1 | tail -3`
Expected: `28 passed, 1 skipped`. Because the scoped filter promotes any `websockets.legacy` deprecation to an error, a green run *is* the proof the legacy path is gone.

- [ ] **Step 2: Manual TLS smoke — server still serves**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && POCKTERM_PORT=8422 .venv/bin/python -m pockterm &
sleep 3
curl -sk https://127.0.0.1:8422/health
echo
kill %1 2>/dev/null
```
Expected: a QR prints and curl returns `{"status":"ok","sessions":[]}`. (If backgrounding is awkward in the shell, start it, capture the PID, curl, then kill by PID.)

- [ ] **Step 3: Confirm scope — only backend config/deps changed**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && git diff --name-only main...HEAD -- app/ | grep . && echo "APP CHANGED — unexpected" || echo "app untouched"
```
Expected: `app untouched` (only `pockterm/`, `requirements.txt`, `pytest.ini`, `tests/`, `docs/` changed).

---

## Notes for the implementer

- Do NOT bump `websockets` — 14.1 is confirmed compatible with the sansio impl. Do NOT introduce `wsproto`.
- The `filterwarnings` entry is scoped by message regex (`.*websockets\.legacy.*`) so it only fails on legacy-websockets deprecations; unrelated ones (pytest-asyncio's `get_event_loop_policy`) stay as warnings and must NOT be added to the filter.
- CI (Linux + Windows/pywinpty + Flutter) re-verifies the uvicorn bump on all platforms after push; the Windows job runs on Python 3.13 (unchanged).
- Do not modify `server.py` — the `/ws` handler uses Starlette's `WebSocket` and is implementation-agnostic.
