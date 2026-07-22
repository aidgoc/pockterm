#!/bin/zsh
# Launch the macOS menu-bar app from the project venv.
# Then use the tray: "Connect via ▸ LAN/Tailscale" → shows the pairing QR.
# For a persistent install (LaunchAgent), run the repo's install-menubar.sh instead.
set -euo pipefail
cd "${0:A:h}/../.." && exec .venv/bin/python -m pockterm.menubar
