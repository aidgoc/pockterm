# Persistent Pairing + Menu-bar App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paired phones stay linked across restarts, and a macOS menu-bar app runs the server and shows an on-demand QR (LAN or Tailscale).

**Architecture:** Persist the HMAC signing secret (long TTL) so session tokens survive restarts. Add small pure helpers (host detection, QR-PNG). A rumps menu-bar app owns a uvicorn server in a daemon thread and renders a QR for a chosen host on click. A LaunchAgent installer auto-starts it.

**Tech Stack:** Python, uvicorn, rumps (macOS), qrcode + Pillow.

**Repo:** `~/pockterm`, branch `feat/menubar-persistent-pairing` (spec committed). Backend venv: `~/pockterm/.venv`.

---

## File Structure

| File | Responsibility |
|---|---|
| `pockterm/secretstore.py` | persist/load the 32-byte signing secret |
| `pockterm/hosts.py` | `reachable_hosts()` (LAN + Tailscale) |
| `pockterm/qrimage.py` | `write_qr_png(payload, path)` |
| `pockterm/menubar.py` | rumps app owning a threaded uvicorn server |
| `pockterm/__main__.py` | use persisted secret + long TTL in `build_runtime` |
| `requirements-macos.txt` | rumps, pillow |
| `install-menubar.sh`, `docs/MENUBAR.md` | LaunchAgent installer + docs |
| `tests/test_secretstore.py`, `tests/test_hosts.py`, `tests/test_qrimage.py`, `tests/test_menubar.py` | tests |

---

## Task 1: Persist the signing secret (TDD)

**Files:** Create `pockterm/secretstore.py`, `tests/test_secretstore.py`

- [ ] **Step 1: Failing tests** — `tests/test_secretstore.py`:
```python
import os
from pockterm.secretstore import load_or_create_secret
from pockterm.auth import Auth


def test_creates_and_is_idempotent(tmp_path):
    p = str(tmp_path / "secret")
    s1 = load_or_create_secret(p)
    assert len(s1) == 32
    assert os.path.exists(p)
    assert load_or_create_secret(p) == s1  # same on second call


def test_mode_is_600(tmp_path):
    p = str(tmp_path / "secret")
    load_or_create_secret(p)
    assert (os.stat(p).st_mode & 0o777) == 0o600


def test_token_survives_simulated_restart(tmp_path):
    p = str(tmp_path / "secret")
    s = load_or_create_secret(p)
    tok = Auth(secret=s).make_session_token()
    s2 = load_or_create_secret(p)  # "restart": reload same secret
    assert Auth(secret=s2).verify_session_token(tok)
    assert not Auth(secret=os.urandom(32)).verify_session_token(tok)
```

- [ ] **Step 2: Run — FAIL**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_secretstore.py -v`
Expected: `ModuleNotFoundError`.

- [ ] **Step 3: Implement** — `pockterm/secretstore.py`:
```python
import os


def load_or_create_secret(path: str) -> bytes:
    """Return the persisted 32-byte signing secret, creating it (0600) if absent."""
    if os.path.exists(path):
        with open(path, "rb") as f:
            data = f.read()
        if len(data) == 32:
            return data
    secret = os.urandom(32)
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "wb") as f:
        f.write(secret)
    os.chmod(path, 0o600)
    return secret
```

- [ ] **Step 4: Run — PASS (3)**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_secretstore.py -v`

- [ ] **Step 5: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add pockterm/secretstore.py tests/test_secretstore.py && git commit -m "feat: persistent signing secret store (#pairing)"
```

---

## Task 2: Use the persisted secret + long TTL in build_runtime

**Files:** Modify `pockterm/__main__.py`

- [ ] **Step 1: Add import + constant.** In `pockterm/__main__.py`, add under the existing imports:
```python
from pockterm.secretstore import load_or_create_secret
```
and below `DEFAULT_PORT = 8422` add:
```python
SESSION_TTL = 3650 * 24 * 3600  # ~10 years — pairing persists until "Forget"
```

- [ ] **Step 2: Wire it.** In `build_runtime`, change:
```python
    auth = Auth()
```
to:
```python
    secret = load_or_create_secret(os.path.join(state_dir, "secret"))
    auth = Auth(secret=secret, ttl=SESSION_TTL)
```

- [ ] **Step 3: Prove persistence across a fresh build_runtime**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && .venv/bin/python -c "
import tempfile, os
from pockterm.__main__ import build_runtime
d = tempfile.mkdtemp()
r1 = build_runtime(port=8500, state_dir=d)
tok = r1.auth.make_session_token()
r2 = build_runtime(port=8500, state_dir=d)   # simulated restart
assert r2.auth.verify_session_token(tok), 'token should survive restart'
print('persistence OK')
"
```
Expected: `persistence OK`.

- [ ] **Step 4: Full suite still green**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest -q`
Expected: all pass (unchanged count + the 3 new secretstore tests). `test_entrypoint`/`test_ws` unaffected.

- [ ] **Step 5: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add pockterm/__main__.py && git commit -m "feat: pairing persists across restarts (persisted secret + long TTL)"
```

---

## Task 3: Reachable-host detection (TDD)

**Files:** Create `pockterm/hosts.py`, `tests/test_hosts.py`

- [ ] **Step 1: Failing tests** — `tests/test_hosts.py`:
```python
import pockterm.hosts as hosts


class _Result:
    def __init__(self, code, out):
        self.returncode = code
        self.stdout = out


def test_lan_only_when_no_tailscale(monkeypatch):
    monkeypatch.setattr(hosts, "lan_ip", lambda: "192.168.1.5")

    def boom(*a, **k):
        raise FileNotFoundError()

    monkeypatch.setattr(hosts.subprocess, "run", boom)
    hs = hosts.reachable_hosts()
    assert len(hs) == 1
    assert hs[0].label == "LAN" and hs[0].ip == "192.168.1.5"


def test_tailscale_added_for_cgnat(monkeypatch):
    monkeypatch.setattr(hosts, "lan_ip", lambda: "192.168.1.5")
    monkeypatch.setattr(hosts.subprocess, "run",
                        lambda *a, **k: _Result(0, "100.92.232.15\n"))
    hs = hosts.reachable_hosts()
    assert any(h.label == "Tailscale" and h.ip == "100.92.232.15" for h in hs)


def test_non_cgnat_ip_ignored(monkeypatch):
    monkeypatch.setattr(hosts, "lan_ip", lambda: "192.168.1.5")
    monkeypatch.setattr(hosts.subprocess, "run",
                        lambda *a, **k: _Result(0, "10.0.0.5\n"))
    assert len(hosts.reachable_hosts()) == 1  # 10.x is not the tailnet range
```

- [ ] **Step 2: Run — FAIL**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_hosts.py -v`

- [ ] **Step 3: Implement** — `pockterm/hosts.py`:
```python
import ipaddress
import subprocess
from dataclasses import dataclass

from pockterm.pairing import lan_ip

_CGNAT = ipaddress.ip_network("100.64.0.0/10")


@dataclass
class Host:
    label: str
    ip: str


def _tailscale_ip() -> str | None:
    try:
        result = subprocess.run(["tailscale", "ip", "-4"],
                                capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    for token in result.stdout.split():
        try:
            addr = ipaddress.ip_address(token.strip())
        except ValueError:
            continue
        if addr in _CGNAT:
            return str(addr)
    return None


def reachable_hosts() -> list[Host]:
    hosts = [Host("LAN", lan_ip())]
    ts = _tailscale_ip()
    if ts:
        hosts.append(Host("Tailscale", ts))
    return hosts
```

- [ ] **Step 4: Run — PASS (3)**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_hosts.py -v`

- [ ] **Step 5: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add pockterm/hosts.py tests/test_hosts.py && git commit -m "feat: reachable-host detection (LAN + Tailscale)"
```

---

## Task 4: QR-PNG helper (TDD, PIL-guarded)

**Files:** Create `pockterm/qrimage.py`, `tests/test_qrimage.py`

- [ ] **Step 1: Ensure Pillow is in the dev venv** (needed for PNG output)

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/python -c "import PIL" 2>/dev/null || .venv/bin/pip install -q pillow`

- [ ] **Step 2: Failing test** — `tests/test_qrimage.py`:
```python
import pytest

pytest.importorskip("PIL")  # PNG output needs Pillow; skip where absent (CI backend)

from pockterm.qrimage import write_qr_png


def test_writes_a_png(tmp_path):
    p = str(tmp_path / "qr.png")
    write_qr_png('{"h":"1.2.3.4","p":8422,"t":"x","fp":"y","n":"z"}', p)
    with open(p, "rb") as f:
        head = f.read(8)
    assert head == b"\x89PNG\r\n\x1a\n"
```

- [ ] **Step 3: Run — FAIL**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_qrimage.py -v`

- [ ] **Step 4: Implement** — `pockterm/qrimage.py`:
```python
import qrcode


def write_qr_png(payload: str, path: str) -> None:
    """Render payload to a scannable PNG at path (requires Pillow)."""
    qrcode.make(payload).save(path)
```

- [ ] **Step 5: Run — PASS (1)**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_qrimage.py -v`

- [ ] **Step 6: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add pockterm/qrimage.py tests/test_qrimage.py && git commit -m "feat: QR PNG helper"
```

---

## Task 5: Menu-bar app + macOS deps

**Files:** Create `pockterm/menubar.py`, `requirements-macos.txt`, `tests/test_menubar.py`

- [ ] **Step 1: Implement** — `pockterm/menubar.py`:
```python
import os
import socket
import subprocess
import threading

import uvicorn

from pockterm.__main__ import DEFAULT_PORT, build_runtime
from pockterm.hosts import reachable_hosts
from pockterm.pairing import qr_payload
from pockterm.qrimage import write_qr_png

STATE_DIR = os.path.expanduser("~/.pockterm")


class PocktermMenuBar:
    """A macOS menu-bar app that owns a threaded pockterm server and shows QRs.

    `rumps` is imported lazily so this module imports on any platform (tests,
    CI); only constructing the app requires rumps + a display.
    """

    def __init__(self, port: int | None = None):
        import rumps

        self._rumps = rumps
        self.port = port or int(os.environ.get("POCKTERM_PORT", DEFAULT_PORT))
        self.rt = build_runtime(port=self.port)
        self.name = socket.gethostname()
        self.app = rumps.App("pockterm", title="● pockterm")
        self._server: uvicorn.Server | None = None
        self._build_menu()
        self._start_server()

    def _build_menu(self) -> None:
        rumps = self._rumps
        connect = rumps.MenuItem("Connect via")
        for host in reachable_hosts():
            connect.add(rumps.MenuItem(f"{host.label} {host.ip}",
                                       callback=self._qr_callback(host)))
        self.app.menu = [
            connect,
            None,
            rumps.MenuItem("Open /pair page", callback=self._open_pair),
            rumps.MenuItem("Restart server (new QR token)", callback=self._restart),
            None,
            rumps.MenuItem("Quit", callback=self._quit),
        ]

    def _qr_callback(self, host):
        def cb(_):
            payload = qr_payload(host.ip, self.port, self.rt.auth.pairing_token,
                                 self.rt.fingerprint, self.name)
            path = os.path.join(STATE_DIR, f"qr-{host.label}.png")
            write_qr_png(payload, path)
            subprocess.run(["open", path])
        return cb

    def _open_pair(self, _):
        hosts = reachable_hosts()
        if hosts:
            subprocess.run(["open", f"https://{hosts[0].ip}:{self.port}/pair"])

    def _restart(self, _):
        self.rt.auth.rotate_pairing()
        self._rumps.notification("pockterm", "Pairing token rotated",
                                 "Previous QR codes are no longer valid.")

    def _start_server(self) -> None:
        config = uvicorn.Config(
            self.rt.app, host="0.0.0.0", port=self.port,
            ssl_certfile=self.rt.cert_path, ssl_keyfile=self.rt.key_path,
            ws="websockets-sansio", log_level="warning")
        self._server = uvicorn.Server(config)
        # uvicorn skips signal handlers automatically off the main thread.
        threading.Thread(target=self._server.run, daemon=True).start()

    def _quit(self, _):
        if self._server:
            self._server.should_exit = True
        self._rumps.quit_application()

    def run(self) -> None:
        self.app.run()


def main() -> None:
    PocktermMenuBar().run()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: macOS deps** — `requirements-macos.txt`:
```
rumps==0.4.0
pillow>=10
```

- [ ] **Step 3: Import smoke test** — `tests/test_menubar.py`:
```python
import pockterm.menubar as menubar


def test_module_imports_without_rumps():
    # Module import must not require rumps/a display (lazy import in __init__).
    assert hasattr(menubar, "PocktermMenuBar")
    assert callable(menubar.main)
```

- [ ] **Step 4: Run the import smoke + confirm the server-owning path works**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest tests/test_menubar.py -v`
Expected: 1 passed.

Then verify the app actually owns/serves (needs rumps in the venv):
```bash
cd /Users/harshwardhangokhale/pockterm && .venv/bin/pip install -q rumps pillow 2>/dev/null; \
.venv/bin/python -c "
import time, urllib.request, ssl
try:
    from pockterm.menubar import PocktermMenuBar
    mb = PocktermMenuBar(port=8533)
except Exception as e:
    print('SKIP (rumps unavailable here):', e); raise SystemExit(0)
time.sleep(2)
ctx = ssl._create_unverified_context()
print(urllib.request.urlopen('https://127.0.0.1:8533/health', context=ctx, timeout=5).read().decode())
mb._server.should_exit = True
"
```
Expected: prints `{"status":"ok",...}` (server owned by the app is live). If rumps can't init a menu bar in this environment it prints `SKIP …` and exits 0 — acceptable; the import test is the gate, GUI is manual.

- [ ] **Step 5: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add pockterm/menubar.py requirements-macos.txt tests/test_menubar.py && git commit -m "feat: macOS menu-bar app owning a threaded server + on-demand QR"
```

---

## Task 6: LaunchAgent installer + docs

**Files:** Create `install-menubar.sh`, `docs/MENUBAR.md`

- [ ] **Step 1: `install-menubar.sh`:**
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="${POCKTERM_DIR:-$HOME/.pockterm-app}"
PY="$DIR/.venv/bin/python"
PIP="$DIR/.venv/bin/pip"
PLIST="$HOME/Library/LaunchAgents/com.pockterm.menubar.plist"

[ -x "$PY" ] || { echo "pockterm not installed at $DIR — run install.sh first."; exit 1; }
"$PIP" install -q -r "$DIR/requirements-macos.txt"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.pockterm.menubar</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PY</string>
    <string>-m</string>
    <string>pockterm.menubar</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/pockterm-menubar.log</string>
  <key>StandardErrorPath</key><string>/tmp/pockterm-menubar.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "✓ pockterm menu bar installed & started — look for '● pockterm' in the menu bar."
```
(The plist gets the **literal absolute** venv-python path via `$PY`, resolved at install time — no `$HOME` inside the plist.)

- [ ] **Step 2: `docs/MENUBAR.md`:**
```markdown
# pockterm menu bar (macOS)

A menu-bar app that runs the pockterm server and gives you a scannable QR on click.

## Install
```bash
bash ~/.pockterm-app/install-menubar.sh
```
This installs the macOS extras (`rumps`, `pillow`), writes a LaunchAgent, and starts
`● pockterm` in your menu bar (auto-starts at login thereafter).

## Use
- **Connect via ▸** → pick **LAN** or **Tailscale** → a QR opens; scan it with the app.
  Use Tailscale when your phone isn't on the same Wi-Fi as the Mac.
- **Restart server (new QR token)** — invalidates old QRs.
- **Quit** — stops the server and the menu-bar app.

Pairing persists across restarts/reboots (the signing secret is saved in
`~/.pockterm/`), so a paired phone stays linked until you tap **Forget server** in the
app.

## Notes
- Don't run `python -m pockterm` and the menu-bar app at the same time — they'd fight
  over port 8422.
- Logs: `/tmp/pockterm-menubar.log`. Uninstall: `launchctl unload
  ~/Library/LaunchAgents/com.pockterm.menubar.plist && rm "$_"`.
```

- [ ] **Step 3: Syntax check + commit**
```bash
cd /Users/harshwardhangokhale/pockterm && chmod +x install-menubar.sh && bash -n install-menubar.sh && echo "ok" && git add install-menubar.sh docs/MENUBAR.md && git commit -m "feat: menu-bar LaunchAgent installer + docs"
```

---

## Task 7: Final verification

**Files:** none.

- [ ] **Step 1: Full backend suite**

Run: `cd /Users/harshwardhangokhale/pockterm && .venv/bin/pytest -q 2>&1 | tail -3`
Expected: all pass (prior + secretstore(3) + hosts(3) + qrimage(1) + menubar(1)); qrimage/menubar may show as passed locally (Pillow/rumps present) — that's fine.

- [ ] **Step 2: No Flutter/protocol changes**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && git diff --name-only main...HEAD | grep -E "^app/|server\.py|terminal_client" && echo "UNEXPECTED" || echo "app + protocol untouched"
```
Expected: `app + protocol untouched`.

- [ ] **Step 3: Manual (user, macOS GUI):** `~/.pockterm-app/install-menubar.sh` → click **Connect via ▸ Tailscale** → scan → confirm the phone pairs and *stays* paired after quitting/reopening the app.

---

## Notes for the implementer

- Keep `import rumps` lazy (inside `PocktermMenuBar.__init__`) so `pockterm/menubar.py` imports on Linux/CI without rumps.
- Do NOT change the wire protocol, `server.py`, `auth.py`, or the Flutter app.
- The persisted secret lives in `~/.pockterm/secret` (0600) — never commit it; it's covered by not being in the repo, but confirm `git status` shows no `secret` file staged.
- uvicorn in a daemon thread skips signal handlers automatically (thread ≠ main), so no extra config is needed.
- `SESSION_TTL` is intentionally ~10 years; "Forget server" in the app remains the revoke path (plus rotating the pairing token only blocks *new* pairings).
