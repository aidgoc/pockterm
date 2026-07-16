# Pockterm — Design

**Date**: 2026-07-16
**Status**: Approved (design), pending implementation plan

## What it is

A self-service product that puts your computer's terminal on your phone. You share
it with anyone: they run a one-line installer on their Mac or Windows machine, scan
a QR code with the phone app, and get a full shell — multi-session, persistent
across reconnects, resized to the phone screen.

Extracted and cleaned from the Jarvis "terminal on Telegram" feature, with all
Telegram/agent/tunnel coupling removed.

## Product surface

Two artifacts plus an installer:

1. **Backend server** — cross-platform Python (macOS + Windows), installed via a
   one-line script, runs a WebSocket + PTY server, shows a QR code for LAN pairing.
2. **Flutter app** — Android + iOS, scans the QR, connects over LAN, renders the
   terminal, manages multiple sessions.

### Non-goals (v1)

- No server-restart persistence (tmux dropped — see below).
- No public/internet access — **LAN only** (same Wi-Fi). Remote-access tunnel is a
  possible v2.
- No multi-user accounts — single owner per machine, gated by the pairing token.
- No agent picker, MCP, per-agent cwd, chat, dashboard (all dropped from origin).

## Architecture

```
┌─────────────────┐     LAN WebSocket over pinned TLS (token-authed)   ┌──────────────────┐
│  Flutter app    │ ◀────────────────────────────────────────────────▶ │  Backend server  │
│  (Android/iOS)  │   wss://<lan-ip>:<port>  JSON frames                │  (Mac / Windows) │
│                 │                                                     │                  │
│  • QR scanner   │  ── scan QR: {h,p,t,fp,n} ──▶                       │  • FastAPI + WS  │
│  • xterm view   │  ◀── output / replay ──                             │  • PTY abstraction│
│  • session tabs │  ── input / resize / spawn / attach ──▶             │  • session pool  │
└─────────────────┘                                                     │  • QR pairing    │
                                                                        └──────────────────┘
```

### Session persistence backend — the key decision

The origin uses **tmux**, which does not exist on Windows (nor does Unix `pty`).
For a cross-platform product we **drop tmux entirely** and hold sessions in the
server process:

- A **Session** = one PTY + an in-memory scrollback ring buffer.
- Works identically on macOS (`pty`) and Windows (`pywinpty`/ConPTY) behind one
  small abstraction.
- Survives **client** reconnects (app backgrounded, network blip) — the real mobile
  need — by replaying the scrollback buffer on attach.
- Does **not** survive a **server** restart. Accepted trade: tmux
  persistence-across-reboot is a power-user feature that would cost Windows support
  and a permanently divergent codepath.

## Backend components (new standalone repo `pockterm`, Python)

| File | Responsibility |
|---|---|
| `pty_process.py` | Cross-platform PTY: `spawn(cmd, cwd, env)`, `read()`, `write()`, `resize(cols,rows)`, `alive`. macOS branch = `pty`/`fcntl`/`termios`; Windows branch = `pywinpty`. **Only OS-specific file.** |
| `session.py` | `Session` (PtyProcess + replay ring buffer); `SessionPool` (spawn/list/attach/kill by name). |
| `auth.py` | Pairing token + HMAC session tokens (with expiry). No Telegram code. |
| `pairing.py` | Pick LAN IP, generate pairing token, self-signed TLS cert + fingerprint, render QR (terminal + `/pair` page). |
| `server.py` | FastAPI: `/ws`, `/api/pair`, `/health`. No cloudflared, bot, agents, `/app`, chat. |
| `install.sh` / `install.ps1` | Create venv, install deps, launch, print QR. |

Default shell: `$SHELL` on macOS, `powershell.exe` (fallback `cmd.exe`) on Windows.
`spawn` with no cwd → user home.

## Flutter app components (`app/` in the same repo)

- `xterm` (Dart terminal emulator + widget) — mobile equivalent of xterm.js.
- `web_socket_channel` — the WS transport.
- `mobile_scanner` — QR scanning.
- `shared_preferences` — store paired server `{host, port, sessionToken, name, fp}`
  for auto-reconnect.
- Screens:
  - **Pair** — scan QR, or manual host/port/token entry.
  - **Terminal** — xterm view + on-screen key bar (Esc / Tab / Ctrl / arrows / pipe /
    common keys — essential on mobile).
  - **Sessions** — tab strip: list / switch / new / kill.

## Pairing flow

1. Backend starts → picks LAN IP, generates a random **pairing token** (32-byte
   base64url), generates/loads a self-signed TLS cert, computes its SHA-256
   fingerprint, prints a QR to the terminal, and serves it at
   `https://<lan-ip>:<port>/pair`.
2. QR payload (compact JSON):
   `{"h":"192.168.1.42","p":8422,"t":"<pairing-token>","fp":"<cert-sha256>","n":"Harsh's Mac"}`.
3. App scans → `POST /api/pair {token}` → server verifies against the live pairing
   token, returns a signed **session token** (HMAC + expiry). App stores the server
   record.
4. Reconnects use the stored session token directly. New scan needed only when the
   token expires or the server restarts (pairing token rotates on every start).

## WebSocket protocol (`/ws`, JSON frames)

Kept close to the origin so server logic ports directly.

**Client → server**

| type | fields | meaning |
|---|---|---|
| `auth` | `token` | first frame; session token. Bad → close 4001 |
| `list_sessions` | — | → `sessions` |
| `spawn` | `session` | new named shell → `spawned`, starts streaming |
| `attach` | `session` | attach existing; replays scrollback → `attached` |
| `input` | `session`, `data` | keystrokes to PTY |
| `resize` | `session`, `cols`, `rows` | PTY winsize |
| `kill` | `session` | terminate |
| `pong` | — | reply to server ping |

**Server → client**

| type | fields |
|---|---|
| `auth_ok` / close 4001 | — |
| `sessions` | `sessions[]` |
| `spawned` / `attached` | `session`, `sessions[]`; `attached` includes `replay` blob |
| `output` | `session`, `data` |
| `killed` | `session`, `sessions[]` |
| `error` | `message` |
| `ping` | — (20s keepalive) |

## Security model (LAN, v1)

- **Pinned TLS.** Server generates a self-signed cert on first run; QR carries the
  cert SHA-256 fingerprint (`fp`). App pins it. Encrypts traffic even on a hostile
  shared network, with no CA/cert-warning friction because the fingerprint came from
  the scanned QR. `wss://` throughout.
- **Token required** on `/ws` and `/api/pair`. Pairing token rotates on every server
  start; session tokens are HMAC-signed with an expiry.
- **Per-IP rate-limit** on `/api/pair` (brute-force protection on the pairing token).
- This is a full shell over the network — the QR + token **is** the credential.
  Docs must warn: anyone with the QR gets the shell; do not screenshot it into a
  chat.

## Testing

- **Backend units**: `SessionPool` (spawn/attach/kill/replay) with a fake
  PtyProcess; `auth` (token verify/expiry); pairing rate-limit.
- **PTY abstraction**: real `echo`/shell round-trip, run per-OS.
- **Protocol**: a headless Python WS client driving spawn→input→output→resize→kill
  against a live server; CI on macOS + Windows runners.
- **Flutter**: widget tests for the pair + terminal screens; manual smoke checklist
  for the on-screen key bar.

## Build order (each a runnable vertical slice)

1. **Backend core** — PtyProcess (macOS) + SessionPool + `/ws` + `auth` (hardcoded
   token, no pairing yet). Prove with the headless client.
2. **Pairing + QR** — LAN IP, pairing token, self-signed cert + fingerprint,
   `/api/pair`, QR to terminal + `/pair` page.
3. **Flutter MVP** — pair screen (manual entry first), single terminal via `xterm`,
   input/output against the step-1 backend.
4. **Multi-session + reconnect** — session tabs, attach/replay, auto-reconnect with
   stored token.
5. **QR scan** — `mobile_scanner`, wired to the pairing payload (incl. `fp` pinning).
6. **Windows PtyProcess** — `pywinpty` branch; run protocol tests on Windows.
7. **Install scripts + docs** — `install.sh` / `install.ps1`, README with the
   security warning.
