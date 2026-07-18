#!/usr/bin/env bash
set -euo pipefail
DIR="${POCKTERM_DIR:-$HOME/.pockterm-app}"
PY="$DIR/.venv/bin/python"
PIP="$DIR/.venv/bin/pip"
PLIST="$HOME/Library/LaunchAgents/com.pockterm.menubar.plist"

[ -x "$PY" ] || { echo "pockterm not installed at $DIR — run install.sh first."; exit 1; }
"$PIP" install -q -r "$DIR/requirements-macos.txt"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.pockterm.menubar</string>
  <key>ProgramArguments</key>
  <array>
    <string>$PY</string>
    <string>-m</string>
    <string>pockterm.menubar</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/pockterm-menubar.log</string>
  <key>StandardErrorPath</key><string>/tmp/pockterm-menubar.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "✓ pockterm menu bar installed & started — look for '● pockterm' in the menu bar."
