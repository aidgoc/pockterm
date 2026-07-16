# Release-pinned, git-free installers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `install.sh` / `install.ps1` install a pinned GitHub Release via source tarball (no `git`), defaulting to the latest release with `POCKTERM_REF` to pin, and publish `v0.1.0`.

**Architecture:** Both installers resolve a release tag (env override or GitHub "latest release" API), download `…/archive/refs/tags/<ref>.tar.gz`, extract with `tar --strip-components=1`, build the venv, and run `python -m pockterm` (skippable via `POCKTERM_INSTALL_ONLY=1` for testing/deferred launch). A real GitHub Release `v0.1.0` gives the installers a target.

**Tech Stack:** bash, PowerShell, `curl`/`tar`, GitHub REST API, `gh` CLI.

**Repo:** `~/pockterm`, branch `fix/4-release-installers` (spec committed).

---

## File Structure

| File | Change |
|---|---|
| `install.sh` | Rewrite: resolve ref → tarball → tar-extract → venv → run/`INSTALL_ONLY` |
| `install.ps1` | Rewrite: same flow in PowerShell |
| `README.md` | Document latest-release default + version pinning + `tar` note |
| (GitHub) | New tag + Release `v0.1.0` at `main` |

No app/server/Flutter changes.

---

## Task 1: Cut the v0.1.0 release

**Files:** none in-repo (creates a GitHub tag + Release).

This is done first so the installer tests in later tasks hit a real release. `main`
is all-green and `pockterm/__init__.py` already declares `0.1.0`.

- [ ] **Step 1: Confirm the code version matches**

Run: `cd /Users/harshwardhangokhale/pockterm && grep __version__ pockterm/__init__.py`
Expected: `__version__ = "0.1.0"`.

- [ ] **Step 2: Create the tag + Release at main**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && gh release create v0.1.0 \
  --target main \
  --title "pockterm v0.1.0" \
  --notes "First release. Your computer's terminal, on your phone — LAN-only, QR-paired, pinned-TLS. macOS/Windows backend + Flutter (Android/iOS) app."
```
Expected: prints the release URL. GitHub auto-attaches the source tarball.

- [ ] **Step 3: Verify the API + tarball resolve**

Run:
```bash
curl -fsSL https://api.github.com/repos/aidgoc/pockterm/releases/latest | grep '"tag_name"'
curl -fsSL -o /dev/null -w "%{http_code}\n" https://github.com/aidgoc/pockterm/archive/refs/tags/v0.1.0.tar.gz
```
Expected: `"tag_name": "v0.1.0",` and `200`.

(No commit — this task only creates the remote release.)

---

## Task 2: Rewrite install.sh (tarball + latest-release + INSTALL_ONLY)

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Replace `install.sh` with:**

```bash
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
```

- [ ] **Step 2: Syntax check**

Run: `cd /Users/harshwardhangokhale/pockterm && bash -n install.sh && echo "syntax ok"`
Expected: `syntax ok`.

- [ ] **Step 3: End-to-end install-only test against the real release**

Run:
```bash
rm -rf /tmp/pt-e2e && POCKTERM_INSTALL_ONLY=1 POCKTERM_DIR=/tmp/pt-e2e bash /Users/harshwardhangokhale/pockterm/install.sh
```
Expected: prints "Installing pockterm v0.1.0 …" and "Installed … not launching"; exits 0. (Downloads the tarball + pip-installs deps — takes ~30s.)

- [ ] **Step 4: Assert the install landed and imports**

Run:
```bash
test -x /tmp/pt-e2e/.venv/bin/python && test -f /tmp/pt-e2e/pockterm/__main__.py \
  && /tmp/pt-e2e/.venv/bin/python -c "import pockterm; print('pockterm', pockterm.__version__)" \
  && echo "E2E OK"
```
Expected: `pockterm 0.1.0` then `E2E OK`. (No `.git` dir should exist: `test ! -d /tmp/pt-e2e/.git && echo "no git — good"`.)

- [ ] **Step 5: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add install.sh && git commit -m "feat: install.sh installs pinned release via tarball, no git (#4)"
```

---

## Task 3: Rewrite install.ps1 (mirror the bash flow)

**Files:**
- Modify: `install.ps1`

- [ ] **Step 1: Replace `install.ps1` with:**

```powershell
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = if ($env:POCKTERM_REPO) { $env:POCKTERM_REPO } else { "aidgoc/pockterm" }
$Dir  = if ($env:POCKTERM_DIR)  { $env:POCKTERM_DIR }  else { "$HOME\.pockterm-app" }

if ($env:POCKTERM_REF) {
  $Ref = $env:POCKTERM_REF
} else {
  try {
    $latest = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" `
      -Headers @{ "User-Agent" = "pockterm-installer" }
    $Ref = $latest.tag_name
  } catch {
    $Ref = $null
  }
  if (-not $Ref) {
    Write-Error "pockterm: could not resolve the latest release. Set `$env:POCKTERM_REF=vX.Y.Z and retry."
    exit 1
  }
}

Write-Host "-> Installing pockterm $Ref to $Dir"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Tmp = Join-Path $env:TEMP "pockterm-$Ref.tar.gz"
Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/tags/$Ref.tar.gz" `
  -OutFile $Tmp -Headers @{ "User-Agent" = "pockterm-installer" }
tar -xzf $Tmp -C $Dir --strip-components=1
Remove-Item $Tmp -Force

Set-Location $Dir
python -m venv .venv
& .\.venv\Scripts\pip.exe install -q -r requirements.txt
& .\.venv\Scripts\pip.exe install -q "pywinpty>=2.0.14"

if ($env:POCKTERM_INSTALL_ONLY -eq "1") {
  Write-Host "-> Installed to $Dir (POCKTERM_INSTALL_ONLY set); not launching."
  exit 0
}

Write-Host "-> Starting pockterm. Scan the QR with the pockterm app (same Wi-Fi)."
& .\.venv\Scripts\python.exe -m pockterm
```

- [ ] **Step 2: Sanity-check the script has no obvious errors**

Run: `cd /Users/harshwardhangokhale/pockterm && grep -c "Invoke-RestMethod\|tar -xzf\|POCKTERM_INSTALL_ONLY\|releases/latest" install.ps1`
Expected: `4` (each key line present once). (No `pwsh` on the dev Mac to parse-check; the logic mirrors the verified `install.sh`. Windows validation is deferred to a real Windows run.)

- [ ] **Step 3: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add install.ps1 && git commit -m "feat: install.ps1 installs pinned release via tarball, no git (#4)"
```

---

## Task 4: Document the release/pinning story in the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the note block after the install commands**

Change (README.md lines 18–21):
```markdown
It starts the server and prints a QR code.

> Windows needs **Python 3.11–3.13** — the `pywinpty` terminal backend has no
> Python 3.14 wheel yet. macOS/Linux run fine on 3.14.
```
to:
```markdown
It downloads the **latest release**, sets up a venv, and starts the server (printing
a QR code). No `git` required — only `curl`/`tar` (present by default on macOS and
Windows 10+).

**Pin a specific version** with `POCKTERM_REF`:

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/aidgoc/pockterm/main/install.sh | POCKTERM_REF=v0.1.0 bash
```
```powershell
# Windows
$env:POCKTERM_REF="v0.1.0"; irm https://raw.githubusercontent.com/aidgoc/pockterm/main/install.ps1 | iex
```

Set `POCKTERM_INSTALL_ONLY=1` to install without launching. Install location defaults
to `~/.pockterm-app` (`POCKTERM_DIR` to change it).

> Windows needs **Python 3.11–3.13** — the `pywinpty` terminal backend has no
> Python 3.14 wheel yet. macOS/Linux run fine on 3.14.
```

- [ ] **Step 2: Verify the README renders the fenced blocks correctly**

Run: `cd /Users/harshwardhangokhale/pockterm && grep -n "POCKTERM_REF\|POCKTERM_INSTALL_ONLY\|latest release" README.md`
Expected: shows the new lines (POCKTERM_REF in both bash + powershell examples, INSTALL_ONLY note, "latest release").

- [ ] **Step 3: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add README.md && git commit -m "docs: document release pinning + git-free install (#4)"
```

---

## Task 5: Final verification

**Files:** none.

- [ ] **Step 1: App/server code untouched**

Run:
```bash
cd /Users/harshwardhangokhale/pockterm && git diff --name-only main...HEAD | grep -E "^(pockterm/|app/|tests/)" && echo "CODE CHANGED — unexpected" || echo "only installers/docs changed"
```
Expected: `only installers/docs changed`.

- [ ] **Step 2: Re-run the E2E install once more, clean dir**

Run:
```bash
rm -rf /tmp/pt-e2e2 && POCKTERM_INSTALL_ONLY=1 POCKTERM_DIR=/tmp/pt-e2e2 bash /Users/harshwardhangokhale/pockterm/install.sh \
  && /tmp/pt-e2e2/.venv/bin/python -c "import pockterm; print('ok', pockterm.__version__)"
```
Expected: ends with `ok 0.1.0`.

- [ ] **Step 3: Confirm pinned install works too**

Run:
```bash
rm -rf /tmp/pt-pin && POCKTERM_REF=v0.1.0 POCKTERM_INSTALL_ONLY=1 POCKTERM_DIR=/tmp/pt-pin bash /Users/harshwardhangokhale/pockterm/install.sh \
  && echo "pinned install ok"
```
Expected: installs v0.1.0 without hitting the "latest" API; prints `pinned install ok`.

---

## Notes for the implementer

- `POCKTERM_REPO` is now `owner/repo` (e.g. `aidgoc/pockterm`), NOT a full URL — it feeds both the API and archive URLs. This is a deliberate change from the old installer.
- The `v0.1.0` source tarball contains the OLD (pre-#4) installer scripts — that's expected and harmless: users always fetch the installer fresh from `main`'s raw URL, and it resolves the latest release at run time.
- Do NOT reintroduce `git clone`. The whole point is a git-free install.
- Unauthenticated GitHub API allows 60 req/hr/IP — fine for occasional installs; `POCKTERM_REF` bypasses the API entirely.
- Follow-up (not this change): a CI job that runs `install.ps1` install-only on `windows-latest` to guard the PowerShell path.
