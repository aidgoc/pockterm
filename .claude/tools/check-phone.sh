#!/bin/zsh
# "Can't reconnect" is almost always the phone being off the tailnet, not the server.
# Check the peer's online state BEFORE touching pockterm. Pairing survives restarts,
# so a QR rescan is never the fix.
# Usage: check-phone.sh [peer-name]   (default: oneplus)
set -euo pipefail
PEER="${1:-oneplus}"
tailscale status | grep -i "$PEER" || echo "peer '$PEER' not found in tailscale status"
