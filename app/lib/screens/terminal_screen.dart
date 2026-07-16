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
      ..onSessions = (list) {
        setState(() => _sessions = list);
      }
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
