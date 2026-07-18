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
