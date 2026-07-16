#!/usr/bin/env bash
set -euo pipefail

# owner/repo (NOT a full URL). Override to install from a fork.
REPO="${POCKTERM_REPO:-aidgoc/pockterm}"
DIR="${POCKTERM_DIR:-$HOME/.pockterm-app}"

resolve_ref() {
  if [ -n "${POCKTERM_REF:-}" ]; then
    printf '%s' "$POCKTERM_REF"
    return
  fi
  local tag
  tag="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)"
  if [ -z "$tag" ]; then
    echo "pockterm: could not resolve the latest release. Set POCKTERM_REF=vX.Y.Z and retry." >&2
    exit 1
  fi
  printf '%s' "$tag"
}

REF="$(resolve_ref)"
echo "→ Installing pockterm ${REF} to ${DIR}"

mkdir -p "$DIR"
curl -fsSL "https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz" \
  | tar -xz -C "$DIR" --strip-components=1

cd "$DIR"
python3 -m venv .venv
./.venv/bin/pip install -q -r requirements.txt

if [ "${POCKTERM_INSTALL_ONLY:-}" = "1" ]; then
  echo "→ Installed to ${DIR} (POCKTERM_INSTALL_ONLY set); not launching."
  exit 0
fi

echo "→ Starting pockterm. Scan the QR with the pockterm app (same Wi-Fi)."
exec ./.venv/bin/python -m pockterm
