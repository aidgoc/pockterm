# pockterm

Your computer's terminal, on your phone. LAN-only, paired by QR, encrypted with a
pinned self-signed certificate.

## Install (computer)

**macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/aidgoc/pockterm/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/aidgoc/pockterm/main/install.ps1 | iex
```

It starts the server and prints a QR code.

## App (phone)

Install the pockterm app (Android/iOS), open it, scan the QR. Your shell appears.
Phone and computer must be on the same Wi-Fi.

## ⚠️ Security

Anyone who can scan that QR gets a **full shell** on your machine. Do not screenshot
it into a chat or share it. The pairing token rotates every time you restart the
server; restart it to revoke all paired phones.

## Architecture

- Backend: cross-platform Python (macOS/Windows), in-process PTY sessions with
  scrollback replay (survive reconnects), FastAPI WebSocket over pinned TLS.
- App: Flutter (Android/iOS) — `xterm` terminal, QR pairing, session tabs.
- No tmux, no Telegram, no public tunnel. LAN + QR only.

See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the full design.
