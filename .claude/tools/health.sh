#!/bin/zsh
# Check the pockterm server's /health over pinned-TLS (self-signed → -k).
# Usage: health.sh [host] [port]   (defaults to the Mac's tailnet IP + 8422)
set -euo pipefail
HOST="${1:-100.92.232.15}"; PORT="${2:-8422}"
curl -sk "https://$HOST:$PORT/health" && echo
