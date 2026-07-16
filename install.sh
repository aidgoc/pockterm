#!/usr/bin/env bash
set -euo pipefail
REPO="${POCKTERM_REPO:-https://github.com/aidgoc/pockterm}"
DIR="${POCKTERM_DIR:-$HOME/.pockterm-app}"
echo "→ Installing pockterm to $DIR"
if [ ! -d "$DIR/.git" ]; then
  git clone --depth 1 "$REPO" "$DIR"
else
  git -C "$DIR" pull --ff-only
fi
cd "$DIR"
python3 -m venv .venv
./.venv/bin/pip install -q -r requirements.txt
echo "→ Starting pockterm. Scan the QR with the pockterm app (same Wi-Fi)."
exec ./.venv/bin/python -m pockterm
