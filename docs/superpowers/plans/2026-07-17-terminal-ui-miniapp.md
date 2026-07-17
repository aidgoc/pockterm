# Terminal UI (Jarvis mini-app match) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the app's terminal screen to match the Jarvis mini-app Terminal tab — GitHub-dark theme, rich sticky-modifier keyboard toolbar, pill session tabs, status bar, safe-area margins — preserving all pairing/reconnect/replay behavior.

**Architecture:** Extract theme + a pure key-sequence/modifier module + a keyboard-toolbar widget, then rewrite the terminal screen chrome to wire them. Soft-keyboard input and every toolbar key flow through one modifier-applying send path.

**Tech Stack:** Flutter, `xterm ^4.0.0`.

**Repo:** `~/pockterm`, branch `feat/terminal-ui-miniapp` (spec committed).

---

## File Structure

| File | Responsibility |
|---|---|
| `app/lib/theme/app_theme.dart` | GitHub-dark colors + xterm `TerminalTheme` |
| `app/lib/services/keys.dart` | pure `keySequence` + `applyModifiers` |
| `app/test/keys_test.dart` | unit tests for keys.dart |
| `app/lib/widgets/key_toolbar.dart` | grouped scrollable keyboard toolbar |
| `app/lib/screens/terminal_screen.dart` | rewired screen (top bar, tabs, terminal, toolbar, status bar, SafeArea) |

---

## Task 1: Theme

**Files:** Create `app/lib/theme/app_theme.dart`

- [ ] **Step 1: Create the theme**
```dart
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class AppColors {
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const border = Color(0xFF30363D);
  static const text = Color(0xFFE6EDF3);
  static const dim = Color(0xFF8B949E);
  static const accent = Color(0xFF58A6FF);
  static const green = Color(0xFF3FB950);
  static const red = Color(0xFFF85149);
  static const yellow = Color(0xFFD29922);
}

const terminalTheme = TerminalTheme(
  cursor: AppColors.accent,
  selection: Color(0x5558A6FF),
  foreground: AppColors.text,
  background: AppColors.bg,
  black: Color(0xFF484F58),
  red: Color(0xFFF85149),
  green: Color(0xFF3FB950),
  yellow: Color(0xFFD29922),
  blue: Color(0xFF58A6FF),
  magenta: Color(0xFFBC8CFF),
  cyan: Color(0xFF39C5CF),
  white: Color(0xFFB1BAC4),
  brightBlack: Color(0xFF6E7681),
  brightRed: Color(0xFFFFA198),
  brightGreen: Color(0xFF56D364),
  brightYellow: Color(0xFFE3B341),
  brightBlue: Color(0xFF79C0FF),
  brightMagenta: Color(0xFFD2A8FF),
  brightCyan: Color(0xFF56D4DD),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFD29922),
  searchHitBackgroundCurrent: Color(0xFF58A6FF),
  searchHitForeground: Color(0xFF0D1117),
);
```

- [ ] **Step 2: Analyze**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze lib/theme/app_theme.dart`
Expected: No issues. (If the analyzer rejects `AppColors.accent` inside the `const TerminalTheme` — it shouldn't, static-const refs are const — inline the literal `Color(0xFF58A6FF)` for `cursor` and re-run.)

- [ ] **Step 3: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add app/lib/theme/app_theme.dart && git commit -m "feat(app): GitHub-dark theme + xterm TerminalTheme"
```

---

## Task 2: Key sequences + modifiers (pure, TDD)

**Files:** Create `app/lib/services/keys.dart`, `app/test/keys_test.dart`

- [ ] **Step 1: Write failing tests** — `app/test/keys_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/keys.dart';

void main() {
  test('keySequence maps named keys', () {
    expect(keySequence('up'), '\x1b[A');
    expect(keySequence('down'), '\x1b[B');
    expect(keySequence('right'), '\x1b[C');
    expect(keySequence('left'), '\x1b[D');
    expect(keySequence('esc'), '\x1b');
    expect(keySequence('tab'), '\t');
    expect(keySequence('shift-tab'), '\x1b[Z');
    expect(keySequence('home'), '\x1b[H');
    expect(keySequence('end'), '\x1b[F');
    expect(keySequence('pgup'), '\x1b[5~');
    expect(keySequence('pgdn'), '\x1b[6~');
  });

  test('keySequence passes unknown/literal through', () {
    expect(keySequence('|'), '|');
    expect(keySequence('5'), '5');
  });

  test('ctrl maps letters to control bytes', () {
    expect(applyModifiers('c', ctrl: true), '\x03');
    expect(applyModifiers('C', ctrl: true), '\x03');
    expect(applyModifiers('a', ctrl: true), '\x01');
  });

  test('alt prefixes ESC', () {
    expect(applyModifiers('x', alt: true), '\x1bx');
  });

  test('shift uppercases', () {
    expect(applyModifiers('a', shift: true), 'A');
  });

  test('no modifiers is identity', () {
    expect(applyModifiers('a'), 'a');
    expect(applyModifiers('|'), '|');
  });
}
```

- [ ] **Step 2: Run — verify FAILS**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter test test/keys_test.dart`
Expected: compile error — `keys.dart` missing.

- [ ] **Step 3: Implement** — `app/lib/services/keys.dart`:
```dart
/// Escape sequence for a named key, or the name unchanged if not special
/// (so literal symbols/digits pass through).
String keySequence(String name) {
  switch (name) {
    case 'up':
      return '\x1b[A';
    case 'down':
      return '\x1b[B';
    case 'right':
      return '\x1b[C';
    case 'left':
      return '\x1b[D';
    case 'esc':
      return '\x1b';
    case 'tab':
      return '\t';
    case 'shift-tab':
      return '\x1b[Z';
    case 'home':
      return '\x1b[H';
    case 'end':
      return '\x1b[F';
    case 'pgup':
      return '\x1b[5~';
    case 'pgdn':
      return '\x1b[6~';
    case 'enter':
      return '\r';
    default:
      return name;
  }
}

/// Apply armed modifiers to already-resolved key data.
/// shift → uppercase; ctrl → control byte for a single letter; alt → ESC prefix.
String applyModifiers(String data,
    {bool ctrl = false, bool alt = false, bool shift = false}) {
  var out = data;
  if (shift) {
    out = out.toUpperCase();
  }
  if (ctrl && out.length == 1) {
    final code = out.codeUnitAt(0);
    if (code >= 0x41 && code <= 0x5A) {
      out = String.fromCharCode(code - 0x40); // A-Z
    } else if (code >= 0x61 && code <= 0x7A) {
      out = String.fromCharCode(code - 0x60); // a-z
    }
  }
  if (alt) {
    out = '\x1b$out';
  }
  return out;
}
```

- [ ] **Step 4: Run — verify PASSES** (6 tests)

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter test test/keys_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add app/lib/services/keys.dart app/test/keys_test.dart && git commit -m "feat(app): pure key-sequence + modifier helpers"
```

---

## Task 3: Keyboard toolbar widget

**Files:** Create `app/lib/widgets/key_toolbar.dart`

- [ ] **Step 1: Implement** — `app/lib/widgets/key_toolbar.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:app/theme/app_theme.dart';

/// Horizontal, grouped, scrollable key toolbar matching the Jarvis mini-app.
/// - onKey(name): a named key (arrows/esc/tab/home/…) or a literal (symbol/digit);
///   the screen resolves the escape sequence and applies armed modifiers.
/// - onCtrl(letter): a direct ctrl-combo (C-c … C-r), sent verbatim.
/// - onToggleMod('shift'|'ctrl'|'alt'): arm/disarm a sticky modifier.
class KeyToolbar extends StatelessWidget {
  final bool ctrl;
  final bool alt;
  final bool shift;
  final void Function(String name) onKey;
  final void Function(String letter) onCtrl;
  final void Function(String mod) onToggleMod;
  final VoidCallback onDismiss;
  final VoidCallback onPaste;

  const KeyToolbar({
    super.key,
    required this.ctrl,
    required this.alt,
    required this.shift,
    required this.onKey,
    required this.onCtrl,
    required this.onToggleMod,
    required this.onDismiss,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
            6, 4, 6, 4 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          _group([_btn('⌨', onDismiss, wide: true)]),
          _group([
            _btn('▲', () => onKey('up')),
            _btn('▼', () => onKey('down')),
            _btn('◀', () => onKey('left')),
            _btn('▶', () => onKey('right')),
          ]),
          _group([
            _btn('Shift', () => onToggleMod('shift'), active: shift, wide: true),
            _btn('Tab', () => onKey('tab'), wide: true),
            _btn('⇧Tab', () => onKey('shift-tab'), wide: true),
          ]),
          _group([for (final d in ['1', '2', '3', '4', '5']) _btn(d, () => onKey(d))]),
          _group([_btn('C-c', () => onCtrl('c'), danger: true)]),
          _group([
            _btn('Ctrl', () => onToggleMod('ctrl'), active: ctrl, wide: true),
            _btn('Alt', () => onToggleMod('alt'), active: alt, wide: true),
          ]),
          _group([for (final l in ['d', 'z', 'l', 'a', 'r']) _btn('C-$l', () => onCtrl(l))]),
          _group([
            _btn('Esc', () => onKey('esc'), wide: true),
            _btn('Hom', () => onKey('home')),
            _btn('End', () => onKey('end')),
            _btn('PgU', () => onKey('pgup')),
            _btn('PgD', () => onKey('pgdn')),
          ]),
          _group([
            for (final s in ['|', '~', '/', '-', '_', '`', r'$', '&'])
              _btn(s, () => onKey(s))
          ]),
          _group([_btn('Paste', onPaste, wide: true)]),
        ]),
      ),
    );
  }

  Widget _group(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Row(children: children),
      );

  Widget _btn(String label, VoidCallback onTap,
      {bool wide = false, bool active = false, bool danger = false}) {
    final bg = active ? AppColors.accent : AppColors.bg;
    final fg = active ? Colors.white : AppColors.dim;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: SizedBox(
        width: wide ? 50 : 40,
        height: 36,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: danger ? AppColors.red : fg,
            side: const BorderSide(color: AppColors.border),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
            textStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze lib/widgets/key_toolbar.dart`
Expected: No issues.

- [ ] **Step 3: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add app/lib/widgets/key_toolbar.dart && git commit -m "feat(app): grouped keyboard toolbar widget"
```

---

## Task 4: Rewire the terminal screen

**Files:** Modify `app/lib/screens/terminal_screen.dart` (full replacement below)

- [ ] **Step 1: Replace `app/lib/screens/terminal_screen.dart` entirely with:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:app/models/server_config.dart';
import 'package:app/services/terminal_client.dart';
import 'package:app/services/keys.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/key_toolbar.dart';

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

class _TerminalScreenState extends State<TerminalScreen> {
  static const _backoff = [1, 2, 4];
  late final Terminal _terminal;
  late final TerminalClient _client;
  String _active = 'main';
  List<String> _sessions = [];
  String _status = 'connecting…';
  bool _connected = false;
  bool _disposed = false;
  bool _reconnecting = false;
  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 5000);
    _terminal.onOutput = (data) => _send(data);
    _terminal.onResize = (w, h, pw, ph) => _client.resize(_active, w, h);
    _client = TerminalClient(widget.config)
      ..onAuthOk = _onReady
      ..onOutput = (s, d) {
        if (s == _active) _terminal.write(d);
      }
      ..onSessions = (list) => setState(() => _sessions = list)
      ..onKilled = (s) {
        if (s == _active) _terminal.write('\r\n[session ended]\r\n');
      }
      ..onClosed = (code) {
        if (_disposed) return;
        setState(() => _connected = false);
        switch (closeAction(code)) {
          case CloseAction.repair:
            widget.onExpired();
            break;
          case CloseAction.reconnect:
            _reconnectWithBackoff();
            break;
        }
      };
    _connect();
  }

  /// Single send path: apply armed modifiers, transmit, then clear them.
  void _send(String data) {
    final out = applyModifiers(data, ctrl: _ctrl, alt: _alt, shift: _shift);
    _client.input(_active, out);
    if (_ctrl || _alt || _shift) {
      setState(() {
        _ctrl = false;
        _alt = false;
        _shift = false;
      });
    }
  }

  void _onKey(String name) => _send(keySequence(name));

  void _onCtrl(String letter) =>
      _client.input(_active, applyModifiers(letter, ctrl: true));

  void _toggleMod(String mod) => setState(() {
        if (mod == 'ctrl') _ctrl = !_ctrl;
        if (mod == 'alt') _alt = !_alt;
        if (mod == 'shift') _shift = !_shift;
      });

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) _client.input(_active, text);
  }

  Future<void> _connect() async {
    setState(() => _status = 'connecting…');
    try {
      await _client.connect();
    } catch (e) {
      setState(() {
        _status = 'offline';
        _connected = false;
      });
    }
  }

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
        return;
      } catch (_) {}
    }
    _reconnecting = false;
    if (!_disposed) setState(() => _status = 'offline');
  }

  void _onReady() {
    setState(() {
      _status = 'connected';
      _connected = true;
    });
    _client.spawn(_active);
    _client.listSessions();
  }

  void _switch(String name) {
    setState(() => _active = name);
    _terminal.buffer.clear();
    _client.attach(name);
  }

  Future<void> _newSession() async {
    final controller =
        TextEditingController(text: 'shell${_sessions.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('New session', style: TextStyle(color: AppColors.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      setState(() => _active = name.trim());
      _terminal.buffer.clear();
      _client.spawn(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (_sessions.isNotEmpty) _sessionTabs(),
            Expanded(
              child: TerminalView(
                _terminal,
                theme: terminalTheme,
                textStyle: const TerminalStyle(fontSize: 13),
                padding: const EdgeInsets.all(4),
                autofocus: true,
              ),
            ),
            KeyToolbar(
              ctrl: _ctrl,
              alt: _alt,
              shift: _shift,
              onKey: _onKey,
              onCtrl: _onCtrl,
              onToggleMod: _toggleMod,
              onDismiss: () => FocusScope.of(context).unfocus(),
              onPaste: _paste,
            ),
            _statusBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connected ? AppColors.green : AppColors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.config.name,
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.dim, size: 20),
            onPressed: _newSession,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.dim, size: 20),
            color: AppColors.surface,
            onSelected: (v) {
              if (v == 'reconnect') _connect();
              if (v == 'forget') widget.onForget();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'reconnect',
                  child: Text('Reconnect', style: TextStyle(color: AppColors.text))),
              PopupMenuItem(
                  value: 'forget',
                  child: Text('Forget server',
                      style: TextStyle(color: AppColors.text))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionTabs() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        children: _sessions.map((s) {
          final active = s == _active;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _switch(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.white : AppColors.dim,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_status,
              style: const TextStyle(color: AppColors.dim, fontSize: 10)),
          Text('${_sessions.length} sessions',
              style: const TextStyle(color: AppColors.dim, fontSize: 10)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _client.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Analyze + full app tests**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze && flutter test`
Expected: `No issues found!`; all tests pass (`server_config` + `terminal_client` + the 6 new `keys` tests).

- [ ] **Step 3: Commit**
```bash
cd /Users/harshwardhangokhale/pockterm && git add app/lib/screens/terminal_screen.dart && git commit -m "feat(app): terminal screen matches the Jarvis mini-app UI"
```

---

## Task 5: Build + ship for on-device comparison

**Files:** none (build/deploy)

- [ ] **Step 1: Analyze + tests green**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter analyze && flutter test 2>&1 | tail -2`
Expected: no issues; all pass.

- [ ] **Step 2: Build the arm64 release APK**

Run: `cd /Users/harshwardhangokhale/pockterm/app && flutter build apk --release --split-per-abi 2>&1 | tail -4`
Expected: `✓ Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

- [ ] **Step 3: Send it via the Jarvis Telegram bot**

Run:
```bash
cd ~/jarvis && set -a && source ~/jarvis/.env && set +a && \
APK=~/pockterm/app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk && \
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
  -F chat_id="${OWNER_ID}" -F document=@"$APK" \
  -F caption="pockterm — new terminal UI (Jarvis mini-app style). Uninstall the old one first, then install this. Re-pair with the QR on the Mac." \
  | python3 -c "import sys,json; print('sent ok:', json.load(sys.stdin).get('ok'))"
```
Expected: `sent ok: True`.

---

## Notes for the implementer

- Preserve ALL existing behavior in `terminal_screen.dart`: connect, `_onReady` (spawn + list), output→write, sessions, killed, `onClosed` routing (4001→`onExpired`, else backoff reconnect), dispose-safety. The only additions are the modifier state, `_send` pipeline, and the new chrome.
- Every keystroke path (soft keyboard via `Terminal.onOutput`, and toolbar `onKey`) goes through `_send`, so sticky modifiers apply uniformly and clear after one key. Direct combos (`onCtrl`) bypass the armed mods intentionally.
- `xterm 4.0`: `TerminalView(terminal, {theme, textStyle, padding, autofocus})` — confirmed. If `padding` type isn't `EdgeInsets`, adapt to the real type; keep ~4px.
- Do not add Find/File/width-toggle. Paste reads the phone clipboard only.
- Android must be uninstalled before installing the new build if the signing key differs; it's the same debug key here, so an in-place update should work, but tell the user to reinstall if Android refuses.
