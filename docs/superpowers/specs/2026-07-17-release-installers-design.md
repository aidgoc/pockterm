# Release-pinned, git-free installers — Design

**Date**: 2026-07-17
**Issue**: [#4](https://github.com/aidgoc/pockterm/issues/4)
**Status**: Approved (design), pending implementation plan

## Problem

`install.sh` / `install.ps1` currently `git clone --depth 1 … main` — a moving target
that requires `git` and can break when `main` moves. We want reproducible, git-free
self-service installs pinned to a published release, with a documented way to pin an
exact version.

## Decisions

- **Default ref:** resolve the **latest published GitHub Release** at install time;
  `POCKTERM_REF` overrides to pin an exact tag. Always a released snapshot, no
  per-release edits to the installer.
- **Fetch:** download the release **source tarball** and extract with `tar` (drops the
  `git` dependency). `tar` ships on macOS and Windows 10+.
- **Cut `v0.1.0` now:** tag current `main` and publish a GitHub Release so the
  installers have a real target.

## Installer flow (both `install.sh` and `install.ps1`)

1. **Resolve ref.** If `POCKTERM_REF` is set → use it. Else GET
   `https://api.github.com/repos/aidgoc/pockterm/releases/latest` and read
   `tag_name`. On failure (offline / no release / rate limit) → exit with a clear
   message telling the user to set `POCKTERM_REF`.
2. **Download + extract (no git).** From
   `https://github.com/aidgoc/pockterm/archive/refs/tags/<ref>.tar.gz` into `$DIR`
   via `tar -xz --strip-components=1` (strips the `pockterm-<ver>/` top-level dir).
3. **venv + deps.** `python -m venv .venv` (idempotent), then
   `pip install -r requirements.txt` (plus `pywinpty>=2.0.14` on Windows).
4. **Run.** `exec python -m pockterm` — **unless** `POCKTERM_INSTALL_ONLY=1`, which
   installs and exits 0 (makes the installer testable end-to-end and lets a user
   install now, run later).

Re-running installs the resolved ref's source over `$DIR`, refreshes deps, and keeps
the existing venv. Minor known limitation: a source file removed between versions can
linger in `$DIR` (acceptable for v1).

Env vars: `POCKTERM_REF` (version), `POCKTERM_DIR` (install dir, default
`~/.pockterm-app`), `POCKTERM_REPO` (owner/repo base, default `aidgoc/pockterm`),
`POCKTERM_INSTALL_ONLY` (skip the run step).

## Release

- Tag `v0.1.0` at current `main` (all CI green) + a GitHub Release. GitHub
  auto-attaches the source tarball; no manual asset upload.
- `pockterm/__init__.py` already declares `0.1.0`, so the tag matches the code version.

## Docs (README)

- Default one-liner installs the **latest release**.
- Document pinning:
  - macOS/Linux: `curl -fsSL …/install.sh | POCKTERM_REF=v0.1.0 bash`
  - Windows: `$env:POCKTERM_REF="v0.1.0"; irm …/install.ps1 | iex`
- Note the `tar` requirement (present by default on macOS and Windows 10+).

## Testing

- `bash -n install.sh` — syntax check.
- **End-to-end (after `v0.1.0` exists):**
  `POCKTERM_INSTALL_ONLY=1 POCKTERM_DIR=/tmp/pt-e2e bash install.sh` → assert
  `$DIR/.venv/bin/python` and `$DIR/pockterm/__main__.py` exist and
  `$DIR/.venv/bin/python -c "import pockterm"` succeeds. Exercises the real
  tarball → venv path.
- `install.ps1` mirrors the same logic; verified by inspection (no `pwsh` on the dev
  Mac).

## Sequencing

Cut `v0.1.0` **first** so installer tests hit a real release; then rewrite installers +
docs and test against it; then merge. The v0.1.0 app snapshot and the main-branch
installer script are intentionally decoupled — users always fetch the installer fresh
from `main`'s raw URL, which resolves the latest release at run time.

## Non-goals

- No signed binaries / packaged double-click installers (separate concern).
- No CI installer-smoke job (worthwhile follow-up, not this change).
- No change to the app, server, or Flutter code.
