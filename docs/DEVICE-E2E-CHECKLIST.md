# Pockterm — Device E2E Checklist

Manual acceptance test that CI can't run. Needs: a Mac/Windows computer running the
backend and a real Android/iOS phone with the pockterm app, **on the same Wi-Fi**.

Mark each step pass/fail. Expected result is in _italics_.

## Setup
- [ ] `python -m pockterm` on the computer → _a QR code prints; "pockterm on https://<lan-ip>:8422"_.
- [ ] Open the pockterm app on the phone → _Pair screen with camera + instructions_.

## Pairing (pinned TLS)
- [ ] Scan the QR → _app pairs and shows a live shell prompt within a couple seconds_.
- [ ] (Optional) Point the app at a wrong/self-signed server → _connection refused (cert pin mismatch)_.

## Shell
- [ ] Type `ls` / `echo hi` → _output streams back correctly_.
- [ ] Run something long (`ping -c 5 8.8.8.8` / `for i in 1 2 3; do echo $i; sleep 1; done`) → _output arrives incrementally, not all at once_.

## Sessions
- [ ] Tap **+** → create a second session → _new tab appears, fresh prompt_.
- [ ] Switch between tabs → _each shows its own scrollback_.
- [ ] Kill a session from the menu → _tab disappears; "[session ended]" if it was active_.

## Key bar
- [ ] `Esc`, `Tab` → _behave in a TUI (e.g. `vi`, tab-completion)_.
- [ ] `^C` interrupts a running command → _returns to prompt_.
- [ ] Arrows → _command history / cursor movement_.
- [ ] `|`, `/`, `~` → _typed literally_.

## Resize / fit
- [ ] Rotate the phone / resize → _the terminal reflows; `tput cols` reflects the new width_.

## Reconnect
- [ ] Background the app ~30s, then foreground → _session resumes with replayed scrollback; status returns to "connected"_.
- [ ] Toggle Wi-Fi off/on briefly → _status shows "reconnecting…" then "connected" (up to 3 tries)_.

## Expiry re-pair (issue #2)
- [ ] Restart the backend (`Ctrl-C`, re-run `python -m pockterm`) → this rotates the pairing token.
- [ ] On the phone → _within a few seconds the app returns to the Pair screen with an orange "Session expired — scan to reconnect" banner_.
- [ ] Rescan the new QR → _back to a live shell_.

## Security spot-check
- [ ] From a **second** phone that never scanned the QR, try to reach `https://<lan-ip>:8422` → _no shell; pairing requires the QR token_.

---
Record device model, OS version, and app/backend versions with the run.
