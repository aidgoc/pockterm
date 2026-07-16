# Terminal screen to match the Jarvis mini-app — Design

**Date**: 2026-07-17
**Status**: Approved (design), pending implementation plan

## Goal

Redesign the pockterm app's terminal screen to look and feel like the Jarvis Telegram
mini-app **Terminal tab** (`~/jarvis/web/static/terminal.html`): GitHub-dark theme, a
rich scrollable on-screen keyboard toolbar with sticky modifiers, pill session tabs, a
status bar, and proper safe-area margins. All existing behavior (pairing, reconnect,
replay, #2 expiry re-pair) is preserved.

## Reference (extracted from terminal.html)

- **Theme:** `--bg #0d1117`, `--surface #161b22`, `--border #30363d`, `--text #e6edf3`,
  `--text-dim #8b949e`, `--accent #58a6ff`, `--green #3fb950`, `--red #f85149`.
- **Vertical layout:** top bar → session tabs → terminal (flex, 2px pad) → keyboard
  toolbar → status bar. Safe-area padding on top (top bar), bottom (toolbar/status),
  and left/right (body).
- **Keyboard toolbar:** horizontal-scroll, keys grouped with divider lines; `kbtn`
  40×36 (wide 50); sticky Shift/Ctrl/Alt highlight accent when armed; `C-c` flashes red.

## Decisions (from brainstorming)

- **Paste only** — keep a client-side Paste (phone clipboard → send). Drop Find (no
  server search) and File (no upload) — not in pockterm's protocol.
- **Sticky modifiers + direct combos** — full fidelity.
- **Platform monospace font** — no bundled font asset.
- **Omit** the reference's ⤢ width-toggle (fixed-80 + pan); fit-to-screen stays default.

## Components (decomposed for focus + testability)

### `app/lib/theme/app_theme.dart`
GitHub-dark color constants (`AppColors`) + an xterm `TerminalTheme` (`terminalTheme`)
mapping those colors (background, foreground, cursor, the 16 ANSI colors).

### `app/lib/services/keys.dart` (pure, unit-tested)
- `String applyModifiers(String data, {bool ctrl, bool alt, bool shift})`:
  - `ctrl` + a letter `a`–`z`/`A`–`Z` → the control byte (`c` → `\x03`, i.e.
    `char.toLowerCase() - 96`); non-letters pass through unchanged.
  - `alt` → prefix each char with `\x1b` (ESC).
  - `shift` → uppercase letters.
  - Order: apply ctrl first (collapse to control byte), then alt prefix, then shift is
    a no-op once ctrl produced a control byte. For plain text: shift→upper, alt→esc.
- `String keySequence(String name)`: named keys → escape sequences:
  `up→\x1b[A`, `down→\x1b[B`, `right→\x1b[C`, `left→\x1b[D`, `esc→\x1b`, `tab→\t`,
  `shift-tab→\x1b[Z`, `home→\x1b[H`, `end→\x1b[F`, `pgup→\x1b[5~`, `pgdn→\x1b[6~`,
  `enter→\r`. Unknown → the name unchanged (so literal symbols like `|`, `~` pass
  through).

### `app/lib/widgets/key_toolbar.dart`
Stateless widget: takes the armed-modifier set + callbacks (`onSend(String named)`,
`onToggleMod(String mod)`, `onDismissKeyboard`, `onPaste`). Renders the grouped,
horizontally-scrollable toolbar. Groups, in order:
1. ⌨️ dismiss
2. ▲ ▼ ◀ ▶ (up/down/left/right)
3. Shift (sticky) · Tab · ⇧Tab
4. 1 2 3 4 5
5. C-c (danger)
6. Ctrl (sticky) · Alt (sticky)
7. C-d C-z C-l C-a C-r
8. Esc · Hom · End · PgU · PgD
9. `|` `~` `/` `-` `_` `` ` `` `$` `&`
10. Paste
`kbtn` styling: 40×36 (wide 50 for Esc/Tab/Shift/⇧Tab/Paste/⌨️), surface/border,
accent when a sticky mod is armed, red flash on C-c.

### `app/lib/screens/terminal_screen.dart` (rewrite of the chrome; behavior preserved)
- **Modifier state:** `bool _ctrl, _alt, _shift`.
- **One send path:** `_send(String data)` applies `applyModifiers` with the armed mods,
  calls `_client.input(_active, …)`, then clears the (non-locked) mods and `setState`.
  Both `Terminal.onOutput` (soft-keyboard input) and every toolbar key route through it.
  Named toolbar keys resolve via `keySequence` first, then go through `_send`.
- **Top bar:** custom `Container` (not `AppBar`) — status dot (green/red from connection
  status), server name, status text; actions `＋` (new session) and a `⋯` menu
  (Reconnect / Forget). Surface bg, bottom border.
- **Session tabs:** horizontal-scroll pills; active = accent.
- **Terminal:** `TerminalView(_terminal, theme: terminalTheme, padding: 4)` filling the
  middle; monospace text style; tap to focus/raise keyboard.
- **Status bar:** status text + "N sessions".
- **SafeArea** wraps the column (top/bottom/left/right).
- All current wiring stays: connect, `onAuthOk`→spawn+list, `onOutput`→write,
  `onSessions`, `onKilled`, `onClosed`→(4001 re-pair / backoff reconnect), dispose.

## Testing

- `app/test/keys_test.dart` (pure):
  - `applyModifiers("c", ctrl:true) == "\x03"`; `("C", ctrl:true) == "\x03"`.
  - `applyModifiers("x", alt:true) == "\x1bx"`.
  - `applyModifiers("a", shift:true) == "A"`; no mods → unchanged.
  - `keySequence("up") == "\x1b[A"`, `keySequence("esc") == "\x1b"`,
    `keySequence("|") == "|"` (passthrough).
- `flutter analyze` clean; existing `server_config` + `terminal_client` tests stay green.
- Rebuild `arm64-v8a` release APK; re-send via Jarvis for manual on-device comparison.

## Non-goals

- No backend/protocol changes.
- No width-toggle / horizontal-pan mode (future).
- No bundled fonts, no Find/File features.
