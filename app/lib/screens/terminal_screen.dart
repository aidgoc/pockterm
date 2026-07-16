import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:app/models/server_config.dart';
import 'package:app/services/terminal_client.dart';

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
  late final Terminal _terminal;
  late final TerminalClient _client;
  static const _backoff = [1, 2, 4]; // reconnect delays, seconds
  String _active = 'main';
  List<String> _sessions = [];
  String _status = 'connecting…';
  bool _disposed = false;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 5000);
    // xterm 4.x: onOutput fires when the terminal wants to send data to the
    // underlying program (user keystrokes via TerminalView).
    _terminal.onOutput = (data) => _client.input(_active, data);
    // onResize fires with (cols, rows, pixelWidth, pixelHeight).
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

  Future<void> _connect() async {
    setState(() => _status = 'connecting…');
    try {
      await _client.connect();
    } catch (e) {
      setState(() => _status = 'offline — tap menu to retry');
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

  void _onReady() {
    setState(() => _status = 'connected');
    _client.spawn(_active);
    _client.listSessions();
  }

  void _switch(String name) {
    setState(() => _active = name);
    // Clear the scrollback so the new session output starts fresh.
    _terminal.buffer.clear();
    _client.attach(name);
  }

  Future<void> _newSession() async {
    final controller =
        TextEditingController(text: 'shell${_sessions.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New session'),
        content: TextField(controller: controller, autofocus: true),
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

  void _sendKey(String data) => _client.input(_active, data);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.config.name} · $_status'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _newSession),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'forget') widget.onForget();
              if (v == 'reconnect') _connect();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reconnect', child: Text('Reconnect')),
              PopupMenuItem(value: 'forget', child: Text('Forget server')),
            ],
          ),
        ],
        bottom: _sessions.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _sessions
                        .map((s) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(s),
                                selected: s == _active,
                                onSelected: (_) => _switch(s),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(child: TerminalView(_terminal)),
          _KeyBar(onKey: _sendKey),
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

class _KeyBar extends StatelessWidget {
  final void Function(String) onKey;
  const _KeyBar({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = <String, String>{
      'Esc': '\x1b',
      'Tab': '\t',
      '^C': '\x03',
      '^D': '\x04',
      '←': '\x1b[D',
      '↑': '\x1b[A',
      '↓': '\x1b[B',
      '→': '\x1b[C',
      '|': '|',
      '~': '~',
      '/': '/',
    };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: keys.entries
            .map((e) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  child: OutlinedButton(
                    onPressed: () => onKey(e.value),
                    child: Text(e.key),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
