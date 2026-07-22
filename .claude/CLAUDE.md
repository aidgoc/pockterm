# pockterm — Project Context

**pockterm** = a standalone, **PUBLIC** product (`github.com/aidgoc/pockterm`, local `~/pockterm`, venv `~/pockterm/.venv/`). Puts your computer's shell on your phone: QR-paired, pinned self-signed TLS, LAN or Tailscale only. Spun off (2026-07-16→20) from Jarvis's "terminal on Telegram" feature; **not connected to Jarvis or any internal system** — safe to share.

## ⚠️ Public repo — read first

- This is a **public** repo. Never commit secrets, PII, or private business data.
- **`docs/superpowers/` is gitignored — NEVER commit it.** It holds internal design docs; repo history was already rewritten with `git-filter-repo` + force-pushed to purge them. Backups: `~/pockterm-internal-docs/`, bundle `~/pockterm-prewrite-backup.bundle`.
- `.claude/memory/` is gitignored too (this file's siblings under `memory/` stay local-only).

## Stack

- **Backend**: cross-platform Python — in-process PTY sessions (`pty_process.py`) with scrollback replay, FastAPI WebSocket `/ws` over pinned self-signed TLS. Pure helpers: `auth.py`, `session.py`, `rate_limit.py` (bounded), `hosts.py`, `secretstore.py`, `pairing.py`, `shells.py`, `qrimage.py`. Entrypoint `pockterm/__main__.py` (`main()`), server `pockterm/server.py`.
- **App**: Flutter (`app/`, Android/iOS) — `xterm` rendering, GitHub-dark UI, sticky-modifier key toolbar, QR pairing, session tabs.
- No tmux, no Telegram, no public tunnel. QR carries host/port/pairing-token/cert-fingerprint.
- Package: `pyproject.toml`, console scripts `pockterm` + `pockterm-menubar`, `[menubar]` extra (rumps+pillow, darwin only), `pywinpty` via `sys_platform=="win32"` marker, MIT license, current version **0.1.2** (`pockterm/__init__.py`).

## Networking (important gotcha)

- Phone reaches the Mac over **Tailscale**, not LAN, in practice — LAN pairing failed here (phone on `100.x` CGNAT/tailnet, Mac LAN `192.168.10.x`). QR must point at the Mac's **tailnet IP** (`100.92.232.15`). `reachable_hosts()` offers both LAN + Tailscale.
- **Persistent pairing**: signing secret at `~/.pockterm/secret` (0600) + ~10y TTL → a paired phone stays linked across restarts/reboots until "Forget server". Cert also persisted in `~/.pockterm/`.
- **"Can't reconnect" is almost always the phone off the tailnet** — check `tailscale status | grep oneplus` for the peer being offline before touching the server. Pairing survives all restarts, so a rescan is never the fix. Server health: `curl -sk https://100.92.232.15:8422/health`.

## Run it

- Menu-bar app (macOS): `python -m pockterm.menubar` (rumps; "Connect via ▸ LAN/Tailscale" → QR). `install-menubar.sh` adds a LaunchAgent.
- Package: `pockterm` (starts server + prints QR); `pockterm-menubar` for the tray app.
- One-liner installers pull a pinned release tarball (git-free): `install.sh` (mac/linux), `install.ps1` (windows). `POCKTERM_REF=vX.Y.Z` pins a version.
- See `.claude/tools/` for local run + health + tailnet-check helpers.

## Ship / release

- **APK distribution = GitHub release assets.** Build `cd app && flutter build apk --release --split-per-abi`, upload arm64-v8a (~24MB): `gh release upload vX.Y.Z <apk>#pockterm.apk`. Full unsplit APK is ~66MB (over Telegram's 50MB bot limit) — always split.
- Releases: **v0.1.2** current. v0.1.0 was deleted (contained internal docs).
- **PyPI**: Trusted-Publisher workflow `.github/workflows/publish.yml` fires on release but **fails until a one-time hand-off is done** (create pypi.org pending publisher: project `pockterm`, owner `aidgoc`, workflow `publish.yml`, env `pypi`; + GitHub `pypi` environment — steps in `docs/RELEASE.md` §8). Until then `pipx install git+https://github.com/aidgoc/pockterm` works. After setup, re-run with `gh run rerun <run-id>`.
- **Dep lists are duplicated** in `pyproject.toml` and `requirements.txt` (CI/installers use the latter) — keep them in sync when bumping.

## CI

- Matrix: backend Linux + backend Windows (pywinpty) + Flutter (`.github/workflows/ci.yml`). Windows needs Python **≤3.13** (no pywinpty 3.14 wheel) and skips POSIX-mode test assertions. mac/linux run on 3.14.

## Mobile UX facts (feat merged 2026-07-21)

- Pinch-to-zoom = raw `Listener` two-pointer distance (never enters the gesture arena, so xterm drag-scroll/selection keep working); font 8–28pt persisted in SharedPreferences; scrollback 10k lines + "⌄ bottom" pill; kill = long-press tab or ⋯ menu, auto-switch to survivor. xterm 4.0 only snaps to bottom on **user input**, not output. Scroll-to-top complaints = the caps (10k lines app-side, ~200KB server replay), not a bug.
- Resume: no background permissions by design (work runs on the PC, tmux model). App reattaches on lifecycle resume (`WidgetsBindingObserver`), replays scrollback via spawn(idempotent)+buffer.clear()+attach.

## Known limitation / next feature

- Full-screen TUIs (claude, vim, htop) wrap/mangle in portrait because ~40–50 cols < the 80+ they expect. Solution (next scoped feature, client-only, server needs nothing): a **⤢ fixed 80/100/120-cols + horizontal-pan** toggle, same as the Jarvis mini-app's `terminal.html`. Workarounds today: pinch to 8pt (~60–70 cols) or landscape.

## Gaps

- No pockterm context skill existed in `~/.claude/skills/` — `.claude/skills/pockterm/SKILL.md` here was distilled from the `pockterm-product` global memory + README.
- Local repo has no git tags (history rewritten; releases live on GitHub only).
