import asyncio
import json
import contextlib
import pytest
import uvicorn
import websockets
from pockterm.server import build_app
from pockterm.auth import Auth


@contextlib.asynccontextmanager
async def running_server():
    auth = Auth()
    app = build_app(auth)
    config = uvicorn.Config(app, host="127.0.0.1", port=8799, log_level="warning")
    server = uvicorn.Server(config)
    task = asyncio.create_task(server.serve())
    for _ in range(100):
        if server.started:
            break
        await asyncio.sleep(0.05)
    try:
        yield auth
    finally:
        server.should_exit = True
        await task


async def _recv_until(ws, wanted, timeout=3.0):
    async with asyncio.timeout(timeout):
        while True:
            msg = json.loads(await ws.recv())
            if msg.get("type") == wanted:
                return msg


@pytest.mark.asyncio
async def test_auth_rejects_bad_token():
    async with running_server():
        async with websockets.connect("ws://127.0.0.1:8799/ws") as ws:
            await ws.send(json.dumps({"type": "auth", "token": "nope"}))
            with pytest.raises(websockets.ConnectionClosed):
                await asyncio.wait_for(ws.recv(), timeout=3)


@pytest.mark.asyncio
async def test_spawn_input_output_roundtrip():
    async with running_server() as auth:
        token = auth.make_session_token()
        async with websockets.connect("ws://127.0.0.1:8799/ws") as ws:
            await ws.send(json.dumps({"type": "auth", "token": token}))
            await _recv_until(ws, "auth_ok")
            await ws.send(json.dumps({"type": "spawn", "session": "t"}))
            await _recv_until(ws, "spawned")
            await ws.send(json.dumps(
                {"type": "input", "session": "t", "data": "echo hi_there\n"}))
            got = ""
            async with asyncio.timeout(4):
                while "hi_there" not in got:
                    msg = json.loads(await ws.recv())
                    if msg.get("type") == "output":
                        got += msg["data"]
            assert "hi_there" in got


@pytest.mark.asyncio
async def test_attach_replays():
    async with running_server() as auth:
        token = auth.make_session_token()
        async with websockets.connect("ws://127.0.0.1:8799/ws") as ws:
            await ws.send(json.dumps({"type": "auth", "token": token}))
            await _recv_until(ws, "auth_ok")
            await ws.send(json.dumps({"type": "spawn", "session": "r"}))
            await _recv_until(ws, "spawned")
            await ws.send(json.dumps(
                {"type": "input", "session": "r", "data": "echo MARKER\n"}))
            await asyncio.sleep(0.6)
        async with websockets.connect("ws://127.0.0.1:8799/ws") as ws2:
            await ws2.send(json.dumps({"type": "auth", "token": token}))
            await _recv_until(ws2, "auth_ok")
            await ws2.send(json.dumps({"type": "attach", "session": "r"}))
            msg = await _recv_until(ws2, "attached")
            assert "MARKER" in msg.get("replay", "")
