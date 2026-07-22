# Release & Ship Discipline

- **Bump version in one place**: `pockterm/__init__.py` `__version__` (pyproject reads it dynamically). Current: 0.1.2.
- **Keep dep lists in sync**: `pyproject.toml` `dependencies` AND `requirements.txt` (CI + one-liner installers use `requirements.txt`). Update both when bumping a dep.
- **APKs go to GitHub release assets, split-per-abi.** Full unsplit APK (~66MB) exceeds Telegram's 50MB bot limit — always build `--split-per-abi` and upload arm64-v8a (~24MB):
  `cd app && flutter build apk --release --split-per-abi`
  `gh release upload vX.Y.Z <arm64-apk>#pockterm.apk`
- **Never publish an APK/tarball built off a tree containing internal docs.** v0.1.0 was deleted for exactly this — verify `docs/superpowers/` is not bundled.
- **Windows constraint**: `pywinpty` has no 3.14 wheel → Windows CI + users need Python ≤3.13. Don't add code that assumes 3.14 on Windows.
- **PyPI publish is blocked until hand-off**: the `publish.yml` Trusted-Publisher workflow fails on every release until the pypi.org pending publisher + GitHub `pypi` environment are created (`docs/RELEASE.md` §8). Expected failure — not a regression. Meanwhile `pipx install git+https://github.com/aidgoc/pockterm` works.
- Installers fetch the pinned release tarball (git-free) — a release must be published for `install.sh`/`install.ps1` to work.
