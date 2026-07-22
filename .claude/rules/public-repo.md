# Public Repo Discipline

`github.com/aidgoc/pockterm` is **PUBLIC**. Everything committed is world-readable.

- **Never commit `docs/superpowers/`** — internal design docs, gitignored. History was already rewritten with `git-filter-repo` + force-pushed to purge them; do not reintroduce. Backups: `~/pockterm-internal-docs/`, `~/pockterm-prewrite-backup.bundle`.
- **Never commit `.claude/memory/`** — gitignored, local-only. No project memory ships to this repo.
- **No secrets ever**: `.env`, `*.pem`, `*.key`, `*.jks`/`*.keystore`, `**/key.properties` are all gitignored — keep it that way. No keys/tokens were ever committed; preserve that.
- **No private business data or PII** in code, docs, tests, or fixtures. This product is standalone and unconnected to Jarvis/internal systems — keep it that way in anything you add.
- Check `git diff` before every commit. If a secret or internal doc slips in: do NOT just delete in a new commit — rotate if it's a secret and rewrite history before it's pushed.
