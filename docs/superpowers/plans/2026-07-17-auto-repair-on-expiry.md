# Auto Re-pair on Session Expiry — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the terminal WebSocket closes with code 4001 (expired session token), send the user back to the QR-scan screen with a "session expired" banner; for any other drop, auto-reconnect a few times before showing offline.

**Architecture:** Surface the WS `closeCode` through a testable `handleClose` seam on `TerminalClient` and a pure `closeAction(code)` classifier. `TerminalScreen` routes 4001 → `onExpired` (which `main.dart` turns into a route back to `PairScreen`) and other closes → a bounded backoff reconnect loop. `PairScreen` gains an optional expired banner. Backend unchanged.

**Tech Stack:** Flutter/Dart, package `app`. Tests via `flutter test`.

**Repo:** `~/pockterm`, branch `fix/2-auto-repair-on-expiry` (spec already committed).

---

## File Structure

| File | Change |
|---|---|
| `app/lib/services/terminal_client.dart` | Add `onClosed` callback, `_disposed` guard, `handleClose(code)` seam, `onDone` wiring, and top-level `isAuthExpiry` / `CloseAction` / `closeAction` |
| `app/test/terminal_client_test.dart` | Add close-code + classifier tests |
| `app/lib/screens/pair_screen.dart` | Optional `expired` banner |
| `app/lib/screens/terminal_screen.dart` | Wire `onClosed` → re-pair / reconnect; new `onExpired` param; disposal-safe backoff loop |
| `app/lib/main.dart` | `_expired` state + `_repair`; pass `onExpired` / `expired` |

**Decision on testing the screen glue:** the routing decision (4001 → re-pair, else reconnect) is extracted into the pure `closeAction(code)` function and unit-tested at the client layer. The screen/`main` wiring is thin glue verified by `flutter analyze` + `flutter test` (existing suite stays green) rather than a network-bound widget test — this is more robust than driving a live socket in a test and covers the actual decision logic.

---

## Task 1: Close-code seam + classifier on TerminalClient

**Files:**
- Modify: `app/lib/services/terminal_client.dart`
- Modify: `app/test/terminal_client_test.dart`

- [ ] **Step 1: Add failing tests** to `app/test/terminal_client_test.dart`

Append these three tests inside the existing `main()` block (after the existing tests, before the closing `}` of `main`):
```dart
  test('handleClose forwards the close code to onClosed', () {
    final c = TerminalClient.forTest();
    int? got = -1;
    c.onClosed = (code) => got = code;
    c.handleClose(4001);
    expect(got, 4001);
    c.handleClose(1006);
    expect(got, 1006);
  });

  test('handleClose is suppressed after dispose', () {
    final c = TerminalClient.forTest();
    int? got = -1;
    c.onClosed = (code) => got = code;
    c.dispose();
    c.handleClose(4001);
    expect(got, -1);
  });

  test('closeAction classifies auth expiry vs reconnect', () {
    expect(isAuthExpiry(4001), true);
    expect(isAuthExpiry(1006), false);
    expect(isAuthExpiry(null), false);
    expect(closeAction(4001), CloseAction.repair);
    expect(closeAction(1006), CloseAction.reconnect);
    expect(closeAction(null), CloseAction.reconnect);
  });
```

- [ ] **Step 2: Run — verify FAILS**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter test test/terminal_client_test.dart`
Expected: compile/analyzer failure — `isAuthExpiry`, `closeAction`, `CloseAction`, `onClosed`, `handleClose` are undefined.

- [ ] **Step 3: Implement** in `app/lib/services/terminal_client.dart`

(a) Add these top-level declarations directly below the existing `typedef` lines (after `typedef SessionsCb = ...;`):
```dart
/// A 4001 close means the session token is invalid/expired (the server rotates
/// the pairing token on every restart) — the app must re-pair by rescanning.
bool isAuthExpiry(int? code) => code == 4001;

enum CloseAction { repair, reconnect }

CloseAction closeAction(int? code) =>
    isAuthExpiry(code) ? CloseAction.repair : CloseAction.reconnect;
```

(b) Inside `class TerminalClient`, add the field and flag next to the other callbacks (after `void Function(String session)? onKilled;`):
```dart
  void Function(int? code)? onClosed;
  bool _disposed = false;
```

(c) Change the `onDone` in `connect()` from:
```dart
    _socket!.listen(
      (event) => handleMessage(event as String),
      onDone: () => _socket = null,
    );
```
to (read the close code before nulling the socket):
```dart
    _socket!.listen(
      (event) => handleMessage(event as String),
      onDone: () {
        final code = _socket?.closeCode;
        _socket = null;
        handleClose(code);
      },
    );
```

(d) Add the `handleClose` method (place it right after `handleMessage`):
```dart
  void handleClose(int? code) {
    if (_disposed) return;
    onClosed?.call(code);
  }
```

(e) Change `dispose()` from:
```dart
  void dispose() => _socket?.close();
```
to:
```dart
  void dispose() {
    _disposed = true;
    _socket?.close();
  }
```

- [ ] **Step 4: Run — verify PASSES**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter test test/terminal_client_test.dart`
Expected: all pass (3 existing + 3 new = 6).

- [ ] **Step 5: Analyze**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze lib/services`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add app/lib/services/terminal_client.dart app/test/terminal_client_test.dart && git commit -m "feat(app): surface WS close code + auth-expiry classifier (#2)"
```

---

## Task 2: Expired banner on PairScreen

**Files:**
- Modify: `app/lib/screens/pair_screen.dart`

- [ ] **Step 1: Add the `expired` param and banner**

Change the widget declaration from:
```dart
class PairScreen extends StatefulWidget {
  final void Function(ServerConfig) onPaired;
  const PairScreen({super.key, required this.onPaired});
  @override
  State<PairScreen> createState() => _PairScreenState();
}
```
to:
```dart
class PairScreen extends StatefulWidget {
  final void Function(ServerConfig) onPaired;
  final bool expired;
  const PairScreen(
      {super.key, required this.onPaired, this.expired = false});
  @override
  State<PairScreen> createState() => _PairScreenState();
}
```

Then, in `build`, insert an expired banner as the first child of the `Column` (above the `Expanded`/`MobileScanner`). Change:
```dart
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
```
to:
```dart
      body: Column(
        children: [
          if (widget.expired)
            Container(
              width: double.infinity,
              color: Colors.orange.shade900,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Session expired — scan to reconnect',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: MobileScanner(
```

- [ ] **Step 2: Analyze + existing tests still green**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze lib/screens/pair_screen.dart && flutter test`
Expected: analyze clean; all tests pass (banner is additive, default `expired: false` keeps first-run behavior).

- [ ] **Step 3: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add app/lib/screens/pair_screen.dart && git commit -m "feat(app): optional 'session expired' banner on PairScreen (#2)"
```

---

## Task 3: Wire re-pair + reconnect in TerminalScreen and main

**Files:**
- Modify: `app/lib/screens/terminal_screen.dart`
- Modify: `app/lib/main.dart`

These two change together: `TerminalScreen` gains a required `onExpired` param, so `main.dart` must pass it for the app to compile.

- [ ] **Step 1: Add `onExpired` to TerminalScreen and the reconnect/close wiring**

In `app/lib/screens/terminal_screen.dart`:

(a) Change the widget declaration from:
```dart
class TerminalScreen extends StatefulWidget {
  final ServerConfig config;
  final VoidCallback onForget;
  const TerminalScreen(
      {super.key, required this.config, required this.onForget});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}
```
to:
```dart
class TerminalScreen extends StatefulWidget {
  final ServerConfig config;
  final VoidCallback onForget;
  final VoidCallback onExpired;
  const TerminalScreen(
      {super.key,
      required this.config,
      required this.onForget,
      required this.onExpired});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}
```

(b) Add state fields. Change:
```dart
  String _active = 'main';
  List<String> _sessions = [];
  String _status = 'connecting…';
```
to:
```dart
  static const _backoff = [1, 2, 4]; // reconnect delays, seconds
  String _active = 'main';
  List<String> _sessions = [];
  String _status = 'connecting…';
  bool _disposed = false;
  bool _reconnecting = false;
```

(c) Wire `onClosed` into the client. In `initState`, the client is built with a
cascade ending in `..onKilled = ...;`. Add an `onClosed` handler to that cascade —
change:
```dart
      ..onKilled = (s) {
        if (s == _active) _terminal.write('\r\n[session ended]\r\n');
      };
```
to:
```dart
      ..onKilled = (s) {
        if (s == _active) _terminal.write('\r\n[session ended]\r\n');
      }
      ..onClosed = (code) {
        if (_disposed) return;
        switch (closeAction(code)) {
          case CloseAction.repair:
            widget.onExpired();
            break;
          case CloseAction.reconnect:
            _reconnectWithBackoff();
            break;
        }
      };
```
(`closeAction` / `CloseAction` come from `terminal_client.dart`, already imported.)

(d) Add the reconnect loop. Insert this method right after `_connect()`:
```dart
  Future<void> _reconnectWithBackoff() async {
    if (_reconnecting) return;
    _reconnecting = true;
    for (final secs in _backoff) {
      if (_disposed) break;
      setState(() => _status = 'reconnecting…');
      await Future.delayed(Duration(seconds: secs));
      if (_disposed) break;
      try {
        await _client.connect();
        _reconnecting = false;
        return; // _onReady resets the status on auth_ok
      } catch (_) {
        // fall through to the next backoff interval
      }
    }
    _reconnecting = false;
    if (!_disposed) {
      setState(() => _status = 'offline — tap menu to retry');
    }
  }
```

(e) Make disposal stop the loop. Change:
```dart
  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
```
to:
```dart
  @override
  void dispose() {
    _disposed = true;
    _client.dispose();
    super.dispose();
  }
```

- [ ] **Step 2: Wire `main.dart`**

In `app/lib/main.dart`:

(a) Add `_expired` state. Change:
```dart
  ServerConfig? _config;
  bool _loaded = false;
```
to:
```dart
  ServerConfig? _config;
  bool _loaded = false;
  bool _expired = false;
```

(b) Clear `_expired` on successful save. Change:
```dart
    await prefs.setString('server', jsonEncode(cfg.toJson()));
    setState(() => _config = cfg);
```
to:
```dart
    await prefs.setString('server', jsonEncode(cfg.toJson()));
    setState(() {
      _config = cfg;
      _expired = false;
    });
```

(c) Add the `_repair` handler right after `_forget`:
```dart
  void _repair() {
    setState(() {
      _config = null;
      _expired = true;
    });
  }
```

(d) Pass the new params in `build`. Change:
```dart
          : _config == null
              ? PairScreen(onPaired: _save)
              : TerminalScreen(config: _config!, onForget: _forget),
```
to:
```dart
          : _config == null
              ? PairScreen(onPaired: _save, expired: _expired)
              : TerminalScreen(
                  config: _config!,
                  onForget: _forget,
                  onExpired: _repair,
                ),
```

- [ ] **Step 3: Analyze + full test suite**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze && flutter test`
Expected: analyze — no issues; tests — all pass (`server_config` + `terminal_client` incl. the 3 new).

- [ ] **Step 4: Commit**

```bash
cd /Users/harshwardhangokhale/pockterm && git add app/lib/screens/terminal_screen.dart app/lib/main.dart && git commit -m "feat(app): auto re-pair on 4001, backoff reconnect otherwise (#2)"
```

---

## Task 4: Final verification

- [ ] **Step 1: Full app suite + analyze**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze && flutter test`
Expected: no issues; all tests pass.

- [ ] **Step 2: Confirm backend untouched**

Run: `cd /Users/harshwardhangokhale/pockterm && git diff --name-only main...HEAD -- pockterm/ | grep . && echo "BACKEND CHANGED — unexpected" || echo "backend clean"`
Expected: `backend clean` (only `app/` and `docs/` changed).

---

## Notes for the implementer

- Do NOT make the reconnect loop infinite — 3 tries then manual retry (YAGNI, matches spec).
- The client's `_disposed` (in `terminal_client.dart`) and the screen's `_disposed` (in `terminal_screen.dart`) are separate flags on separate classes — both are needed and do not conflict.
- Re-pair cannot be silent: the persisted config has no pairing token and the server rotates it, so `onExpired` must route to a rescan, not a background `/api/pair` call.
- Manual E2E (device, later): pair, restart the pockterm server (rotates the token) → the app should drop to the Pair screen with the orange banner; rescanning the new QR returns to a live shell.
