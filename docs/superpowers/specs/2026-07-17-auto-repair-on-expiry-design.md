# Auto Re-pair on Session Expiry — Design

**Date**: 2026-07-17
**Issue**: [#2](https://github.com/aidgoc/pockterm/issues/2)
**Status**: Approved (design), pending implementation plan

## Problem

When `/ws` closes with code **4001** (the server sends this for an invalid/expired
session token — the pairing token rotates on every server restart), the app leaves
the terminal showing "offline — tap menu to retry". The only recovery is *Forget
server* + rescan. Token expiry should instead route the user straight to a rescan.

Separately, an ordinary mid-session network drop (Wi-Fi blip, server briefly down)
currently has no handling at all beyond the initial connect-failure catch. It should
auto-reconnect, not send the user to rescan.

## Key facts

- The WebSocket close code is currently discarded — `onDone` only nulls the socket.
  `WebSocket.closeCode` holds it.
- The persisted `ServerConfig` stores `host/port/fingerprint/name/sessionToken` but
  **not** the pairing token, and the pairing token rotates on server restart. So
  "re-pair" cannot be silent — it means **rescanning the QR** for a fresh session
  token. The cert fingerprint is stable across restarts, so it is the same trusted
  server; only the token is refreshed.
- The server already sends 4001 correctly (`pockterm/server.py`). **No backend
  changes.**

## Behavior

Close/failure is classified by close code:

```
WS closes / connect fails
        │
        ├─ closeCode == 4001 (auth/expired)  ──►  RE-PAIR
        │      nav to Pair screen + "Session expired — scan to reconnect" banner;
        │      rescan QR → fresh session token → back into the terminal.
        │
        └─ any other close / connect throws  ──►  AUTO-RECONNECT
               3 attempts, backoff 1s / 2s / 4s, status "reconnecting…";
               all fail → "offline — tap to retry" (existing manual path).
```

An **intentional** close (leaving the screen / `dispose`) triggers neither path,
guarded by a `_disposed` flag.

## Components & files

### `app/lib/services/terminal_client.dart` (keep it a thin protocol wrapper)
- Add `void Function(int? code)? onClosed;` and `bool _disposed = false;`.
- Add a pure top-level helper `bool isAuthExpiry(int? code) => code == 4001;`.
- Add a testable seam `void handleClose(int? code)` that calls `onClosed?.call(code)`
  unless `_disposed`. Mirrors the existing directly-tested `handleMessage`.
- `connect()`'s `onDone` calls `handleClose(_socket?.closeCode)` (reading the code
  before nulling the socket).
- `dispose()` sets `_disposed = true` before closing.
- `connect()` remains re-callable (already reassigns `_socket`), so reconnect is just
  another `connect()`.

### `app/lib/screens/terminal_screen.dart`
- Wire `onClosed`: if `isAuthExpiry(code)` → `widget.onExpired()`; else →
  `_reconnectWithBackoff()`.
- `_reconnectWithBackoff()`: iterate `const _backoff = [1, 2, 4]` seconds; set status
  "reconnecting…"; `await Future.delayed`, then `await _client.connect()`. Stop on the
  first success (auth_ok resets status via existing `_onReady`) or if `_disposed`.
  After all attempts fail, set status "offline — tap to retry".
- Track a `bool _reconnecting` / disposal flag so a reconnect loop stops when the
  screen is torn down, and so overlapping loops don't stack.
- New required constructor param `onExpired` (VoidCallback).

### `app/lib/main.dart`
- Add `bool _expired = false`.
- Pass `onExpired: _repair` to `TerminalScreen`, where `_repair()` does
  `setState(() { _config = null; _expired = true; })` (routes to `PairScreen`).
- `PairScreen` is built with `expired: _expired`; successful `_save(newCfg)` also sets
  `_expired = false`.

### `app/lib/screens/pair_screen.dart`
- Add `final bool expired;` (default `false`). When true, render a banner
  "Session expired — scan to reconnect" above the scanner. Normal first-run copy is
  unchanged when false.

## Testing

- `app/test/terminal_client_test.dart` (extend, same direct-call style):
  - `handleClose(4001)` → `onClosed` receives `4001`.
  - `handleClose(1006)` → `onClosed` receives `1006`.
  - after `dispose()`, `handleClose(4001)` does **not** invoke `onClosed` (guard).
  - `isAuthExpiry(4001)` is true; `isAuthExpiry(1006)`, `isAuthExpiry(null)` false.
- Widget test (`app/test/terminal_screen_expiry_test.dart`): build `TerminalScreen`
  with an `onExpired` spy and a `TerminalClient` whose `connect()` is not called;
  invoke `client.handleClose(4001)` and assert the spy fired. (Construct the client,
  assign it into the widget via the existing wiring; if the widget owns client
  creation, expose the client for the test or drive through the public seam.)
- Existing `server_config` + `terminal_client` tests must stay green; `flutter
  analyze` clean.

## Non-goals

- No change to the pairing/token protocol or the server.
- No persistent reconnect beyond 3 attempts (YAGNI; manual retry remains).
- No silent re-pair (impossible without a live pairing token).
