---
name: pockterm
description: "Context for pockterm — a standalone public 'terminal on your phone' product (Python PTY/WebSocket backend + Flutter app, QR-paired, pinned TLS, LAN/Tailscale). How to run, pair, ship, and its security/history constraints."
---

# pockterm

Standalone **public** product: your computer's shell on your phone. QR-paired, pinned self-signed TLS, LAN or Tailscale only. Spun off from Jarvis's "terminal on Telegram" feature but fully independent — no Jarvis/internal wiring.

- Repo: `github.com/aidgoc/pockterm` (**PUBLIC**) · local `~/pockterm` · venv `~/pockterm/.venv/`

## Architecture

- **Backend** (Python, `pockterm/`): FastAPI WebSocket `/ws` over pinned self-signed TLS; in-process PTY sessions (`pty_process.py`) with scrollback replay so reconnects/backgrounding resume in place. Helpers: `auth.py`, `session.py`, `rate_limit.py`, `hosts.py`, `secretstore.py`, `pairing.py`, `shells.py`, `qrimage.py`. Server: `server.py`; entry `__main__.py`.
- **App** (Flutter, `app/`): `xterm` rendering, GitHub-dark UI, sticky-modifier key toolbar, QR pairing (host/port/token/cert-fingerprint), session tabs, pinch-zoom, resume-on-resume.
- Package: `pyproject.toml` → scripts `pockterm`, `pockterm-menubar`; `[menubar]` extra (macOS); `pywinpty` on Windows only. Version in `pockterm/__init__.py` (0.1.2).

## Run it

- Menu-bar (macOS): `python -m pockterm.menubar` → "Connect via ▸ LAN/Tailscale" → QR. `install-menubar.sh` = LaunchAgent.
- Package: `pockterm` starts server + prints QR. `pockterm[menubar]` adds the tray app.
- Installers (git-free, pull pinned release tarball): `install.sh` (mac/linux), `install.ps1` (windows); `POCKTERM_REF=vX.Y.Z` to pin.

## Pairing / networking

- Phone reaches Mac over **Tailscale** in practice (LAN pairing failed on CGNAT tailnet). QR must point at tailnet IP `100.92.232.15`.
- Pairing is **persistent**: secret at `~/.pockterm/secret` (0600) ~10y TTL → survives restarts/reboots until "Forget server". Cert persisted in `~/.pockterm/`.
- "Can't reconnect" ≈ **phone off the tailnet** — check `tailscale status | grep oneplus` first. Health: `curl -sk https://100.92.232.15:8422/health`.

## Ship

- **APK → GitHub release assets, split-per-abi** (arm64-v8a ~24MB; unsplit ~66MB exceeds Telegram's 50MB): `cd app && flutter build apk --release --split-per-abi` then `gh release upload vX.Y.Z <apk>#pockterm.apk`.
- **PyPI**: `publish.yml` Trusted-Publisher workflow, blocked until pypi.org pending-publisher + GitHub `pypi` env hand-off (`docs/RELEASE.md` §8). Fails on every release until then. `pipx install git+https://github.com/aidgoc/pockterm` meanwhile.
- Keep dep lists synced across `pyproject.toml` + `requirements.txt`.

## Security / history — DO NOT UNDO

- **Public repo.** No secrets/PII/private business data, ever. None were committed; keep it so.
- **`docs/superpowers/` is gitignored — NEVER commit.** History was rewritten (`git-filter-repo` + force-push) to purge internal docs. Backups: `~/pockterm-internal-docs/`, `~/pockterm-prewrite-backup.bundle`.
- Windows needs Python ≤3.13 (no pywinpty 3.14 wheel).

## Next scoped feature

- **⤢ fixed 80/100/120-cols + horizontal-pan** toggle for full-screen TUIs (claude/vim/htop) that mangle in portrait (~40–50 cols). Client-only; server needs nothing. Mirrors the Jarvis mini-app `terminal.html` fix.
