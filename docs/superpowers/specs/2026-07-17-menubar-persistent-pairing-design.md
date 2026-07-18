# Persistent pairing + pockterm menu-bar app — Design

**Date**: 2026-07-17
**Status**: Approved (design), pending implementation plan

## Goal

Make connecting effortless: (1) a paired phone stays linked across server/PC restarts
until explicitly forgotten, and (2) a macOS menu-bar app runs the server and hands you
a scannable QR on click, letting you choose LAN or Tailscale each time.

## Motivation

Real-world pairing failed when the phone wasn't on the Mac's LAN (it reached the Mac
over Tailscale). And a fresh signing secret each server start meant every restart
re-locked paired phones. Both are addressed here.

## Part 1 — Pairing survives restarts (backend)

Currently `build_runtime` creates `Auth()` with a random secret each start (7-day TTL),
so session tokens die on restart.

- New `pockterm/secretstore.py`: `load_or_create_secret(path: str) -> bytes` — returns
  the 32-byte signing secret at `path`, creating it (mode 0600) on first call;
  idempotent thereafter (like `ensure_cert`).
- `pockterm/__main__.py::build_runtime`: `secret = load_or_create_secret(
  <state_dir>/secret)`, `auth = Auth(secret=secret, ttl=SESSION_TTL)` where
  `SESSION_TTL = 3650 * 24 * 3600` (~10 years).
- Effect: session tokens survive restarts/reboots and effectively don't expire → the
  phone stays linked until the user taps **Forget server**. The pairing token still
  rotates each start (only affects *new* scans).

## Part 2 — Reachable-host detection

- New `pockterm/hosts.py`:
  - `Host` = a small dataclass `(label: str, ip: str)`.
  - `reachable_hosts() -> list[Host]`: always includes `Host("LAN", lan_ip())`; appends
    `Host("Tailscale", <ip>)` when `tailscale ip -4` succeeds and returns an address in
    `100.64.0.0/10`. Never raises (missing/oﬄine Tailscale → LAN only).

## Part 3 — QR image helper

- New `pockterm/qrimage.py`: `write_qr_png(payload: str, path: str) -> None` — renders
  `payload` to a PNG at `path` via `qrcode` + Pillow.

## Part 4 — Menu-bar app (macOS, rumps)

- New `pockterm/menubar.py` (`python -m pockterm.menubar`):
  - On launch: `rt = build_runtime()`; start uvicorn in a **daemon thread**
    (`uvicorn.Server` with `config.install_signal_handlers = False`, TLS from `rt`,
    `ws="websockets-sansio"`), holding `rt` (auth token, fingerprint, port).
  - `rumps.App` menu:
    - **Connect via ▸** submenu — one item per `reachable_hosts()` entry
      (`"LAN 192.168.10.127"`, `"Tailscale 100.92.232.15"`). Selecting one builds the
      payload `qr_payload(host.ip, rt.port, rt.auth.pairing_token, rt.fingerprint,
      name)`, writes `~/.pockterm/qr-<label>.png`, and opens it (`open` on macOS).
    - **Restart server** — rotates the pairing token (`rt.auth.rotate_pairing()`); the
      TLS server keeps running (token change is in-memory).
    - **Open /pair page** — opens `https://<first host>:<port>/pair`.
    - **Quit** — stops the server thread and exits.
  - Title shows a status dot (● when serving).

## Part 5 — Auto-start + install

- New `install-menubar.sh` (macOS): writes
  `~/Library/LaunchAgents/com.pockterm.menubar.plist` with the **literal absolute
  path** to the installed venv Python and `-m pockterm.menubar` (computed at install
  time — never `$HOME` in the plist), then `launchctl unload`/`load`s it. Idempotent.
- New `requirements-macos.txt`: `rumps`, `qrcode`, `pillow`.
- New `docs/MENUBAR.md`: install (`bash install-menubar.sh`), usage, and the note that
  it and `python -m pockterm` must not run on the same port simultaneously.

## Testing

- `tests/test_secretstore.py`: `load_or_create_secret` returns 32 bytes, is idempotent,
  writes mode 0600; **cross-run proof** — a token from `Auth(secret=s)` verifies under a
  second `Auth(secret=s)` (simulated restart), and does NOT under a different secret.
- `tests/test_hosts.py`: `reachable_hosts()` includes LAN; includes Tailscale when a
  faked `tailscale ip -4` returns `100.x`; LAN-only when it fails (monkeypatched
  `subprocess`).
- `tests/test_qrimage.py`: `write_qr_png` creates a non-empty PNG (magic bytes).
- `menubar.py`: import/smoke only (construct the app object without running the run
  loop), guarded to macOS; full menu behavior is manual.
- Existing suite stays green; the `SESSION_TTL`/persisted-secret change must not break
  `test_entrypoint`/`test_ws`.

## Non-goals

- No Windows tray app (future).
- No change to the Flutter app, the wire protocol, or the pinning model.
- The menu-bar app does not manage multiple servers/ports — one instance, one port.
