import asyncio
import json
import logging
import re
import time
from collections import defaultdict, deque

log = logging.getLogger("pockterm.server")

from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, JSONResponse

from pockterm.auth import Auth
from pockterm.session import SessionPool
from pockterm.shells import default_shell, home_dir

_NAME_RE = re.compile(r"[^a-zA-Z0-9_.-]")


def _sanitize_name(name: str) -> str:
    return _NAME_RE.sub("", (name or "").strip())[:64]


def build_app(auth: Auth, pool: SessionPool | None = None,
              pair_config: dict | None = None) -> FastAPI:
    app = FastAPI()
    app.state.auth = auth
    app.state.pool = pool or SessionPool()
    app.state.pair_config = pair_config or {}
    app.state.pair_hits: dict[str, deque] = defaultdict(deque)

    @app.get("/health")
    async def health():
        return {"status": "ok", "sessions": app.state.pool.list_names()}

    @app.websocket("/ws")
    async def ws(websocket: WebSocket):
        await websocket.accept()
        try:
            raw = await asyncio.wait_for(websocket.receive_text(), timeout=10)
            msg = json.loads(raw)
            if msg.get("type") != "auth" or not auth.verify_session_token(
                    msg.get("token", "")):
                await websocket.close(code=4001, reason="Unauthorized")
                return
        except Exception:
            await websocket.close(code=4001, reason="Auth timeout")
            return
        await websocket.send_json({"type": "auth_ok"})
        await _serve_terminal(websocket, app.state.pool)

    def _rate_limited(ip: str, limit: int = 10, window: float = 60.0) -> bool:
        now = time.time()
        hits = app.state.pair_hits[ip]
        while hits and hits[0] < now - window:
            hits.popleft()
        hits.append(now)
        return len(hits) > limit

    @app.post("/api/pair")
    async def pair(request: Request):
        ip = (request.headers.get("x-forwarded-for", "").split(",")[0].strip()
              or (request.client.host if request.client else "?"))
        if _rate_limited(ip):
            return JSONResponse({"error": "rate limited"}, status_code=429)
        try:
            body = await request.json()
        except Exception:
            return JSONResponse({"error": "bad json"}, status_code=400)
        if not auth.verify_pairing(body.get("token", "")):
            return JSONResponse({"error": "unauthorized"}, status_code=401)
        return {"token": auth.make_session_token(),
                "name": app.state.pair_config.get("name", "pockterm")}

    @app.get("/pair", response_class=HTMLResponse)
    async def pair_page():
        cfg = app.state.pair_config
        return (
            "<!doctype html><html><head><meta charset=utf-8>"
            "<title>pockterm pairing</title>"
            "<meta name=viewport content='width=device-width,initial-scale=1'>"
            "<style>body{font-family:system-ui;background:#111;color:#eee;"
            "text-align:center;padding:2rem}code{color:#6cf}</style></head>"
            "<body><h1>pockterm</h1><p>Scan the QR shown in your terminal with "
            f"the pockterm app.</p><p>Server: <code>{cfg.get('host')}:"
            f"{cfg.get('port')}</code></p></body></html>"
        )

    return app


async def _serve_terminal(websocket: WebSocket, pool: SessionPool):
    reader_tasks: dict[str, asyncio.Task] = {}
    loop = asyncio.get_running_loop()

    async def pump(name: str):
        session = pool.get(name)
        if session is None:
            return
        while True:
            proc = session.proc
            if proc is None or not proc.alive:
                await _safe_send(websocket, {
                    "type": "killed", "session": name,
                    "sessions": pool.list_names()})
                pool.kill(name)
                return
            # proc.read is non-blocking (returns b"" immediately when no data),
            # so a cancelled pump never leaves a thread stuck in the executor.
            data = await loop.run_in_executor(None, proc.read, 65536)
            if data:
                session.append_replay(data)
                await _safe_send(websocket, {
                    "type": "output", "session": name,
                    "data": data.decode("utf-8", errors="replace")})
            else:
                await asyncio.sleep(0.02)

    async def ping():
        while True:
            await asyncio.sleep(20)
            if not await _safe_send(websocket, {"type": "ping"}):
                return

    ping_task = asyncio.create_task(ping())
    try:
        while True:
            msg = json.loads(await websocket.receive_text())
            t = msg.get("type")
            if t == "pong":
                continue
            elif t == "list_sessions":
                await websocket.send_json({
                    "type": "sessions", "sessions": pool.list_names()})
            elif t == "spawn":
                name = _sanitize_name(msg.get("session", ""))
                if not name:
                    await websocket.send_json(
                        {"type": "error", "message": "bad session name"})
                    continue
                pool.spawn(name, default_shell(), cwd=home_dir())
                await websocket.send_json({
                    "type": "spawned", "session": name,
                    "sessions": pool.list_names()})
                if name not in reader_tasks:
                    reader_tasks[name] = asyncio.create_task(pump(name))
            elif t == "attach":
                name = _sanitize_name(msg.get("session", ""))
                session = pool.get(name)
                if session is None:
                    await websocket.send_json({
                        "type": "error", "message": "no such session"})
                    continue
                await websocket.send_json({
                    "type": "attached", "session": name,
                    "sessions": pool.list_names(),
                    "replay": session.replay().decode("utf-8", errors="replace")})
                if name not in reader_tasks:
                    reader_tasks[name] = asyncio.create_task(pump(name))
            elif t == "input":
                session = pool.get(_sanitize_name(msg.get("session", "")))
                if session and session.proc:
                    session.proc.write(msg.get("data", "").encode("utf-8"))
            elif t == "resize":
                session = pool.get(_sanitize_name(msg.get("session", "")))
                if session and session.proc:
                    session.proc.resize(
                        int(msg.get("cols", 80)), int(msg.get("rows", 24)))
            elif t == "kill":
                name = _sanitize_name(msg.get("session", ""))
                pool.kill(name)
                task = reader_tasks.pop(name, None)
                if task:
                    task.cancel()
                await websocket.send_json({
                    "type": "killed", "session": name,
                    "sessions": pool.list_names()})
    except WebSocketDisconnect:
        pass
    except Exception:
        log.exception("ws terminal loop error")
    finally:
        ping_task.cancel()
        for task in reader_tasks.values():
            task.cancel()
        await asyncio.gather(*reader_tasks.values(), ping_task,
                             return_exceptions=True)
        # NOTE: PTY sessions are NOT killed on disconnect — only explicit "kill"
        # frames terminate sessions. Reconnecting clients can attach and replay.


async def _safe_send(websocket: WebSocket, payload: dict) -> bool:
    try:
        await websocket.send_json(payload)
        return True
    except Exception:
        return False
