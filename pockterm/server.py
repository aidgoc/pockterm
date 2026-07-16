import asyncio
import json
import logging
import re

log = logging.getLogger("pockterm.server")

from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from pockterm.auth import Auth
from pockterm.session import SessionPool
from pockterm.shells import default_shell, home_dir

_NAME_RE = re.compile(r"[^a-zA-Z0-9_.-]")


def _sanitize_name(name: str) -> str:
    return _NAME_RE.sub("", (name or "").strip())[:64]


def build_app(auth: Auth, pool: SessionPool | None = None) -> FastAPI:
    app = FastAPI()
    app.state.auth = auth
    app.state.pool = pool or SessionPool()

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
