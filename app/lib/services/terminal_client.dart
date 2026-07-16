import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/models/server_config.dart';
import 'package:app/services/pinned_http.dart';

typedef OutputCb = void Function(String session, String data);
typedef SessionsCb = void Function(List<String> sessions);

class TerminalClient {
  final ServerConfig? config;
  WebSocket? _socket;
  OutputCb? onOutput;
  SessionsCb? onSessions;
  void Function()? onAuthOk;
  void Function(String session)? onKilled;

  List<String> sessions = [];

  TerminalClient(this.config);
  TerminalClient.forTest() : config = null;

  Future<void> connect() async {
    final cfg = config!;
    final httpClient = pinnedHttpClient(cfg.fingerprint);
    _socket = await WebSocket.connect(cfg.wsUrl, customClient: httpClient);
    _socket!.listen(
      (event) => handleMessage(event as String),
      onDone: () => _socket = null,
    );
    _send({'type': 'auth', 'token': cfg.sessionToken});
  }

  void handleMessage(String raw) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'auth_ok':
        onAuthOk?.call();
        break;
      case 'ping':
        _send({'type': 'pong'});
        break;
      case 'output':
        onOutput?.call(msg['session'] as String, msg['data'] as String);
        break;
      case 'attached':
        onOutput?.call(msg['session'] as String,
            (msg['replay'] as String?) ?? '');
        sessions = List<String>.from(msg['sessions'] as List? ?? sessions);
        onSessions?.call(sessions);
        break;
      case 'spawned':
      case 'sessions':
        sessions = List<String>.from(msg['sessions'] as List? ?? const []);
        onSessions?.call(sessions);
        break;
      case 'killed':
        sessions = List<String>.from(msg['sessions'] as List? ?? const []);
        onKilled?.call(msg['session'] as String);
        onSessions?.call(sessions);
        break;
    }
  }

  String encodeInput(String session, String data) =>
      jsonEncode({'type': 'input', 'session': session, 'data': data});

  void _send(Map<String, dynamic> m) => _socket?.add(jsonEncode(m));

  void listSessions() => _send({'type': 'list_sessions'});
  void spawn(String name) => _send({'type': 'spawn', 'session': name});
  void attach(String name) => _send({'type': 'attach', 'session': name});
  void input(String session, String data) =>
      _send({'type': 'input', 'session': session, 'data': data});
  void resize(String session, int cols, int rows) =>
      _send({'type': 'resize', 'session': session, 'cols': cols, 'rows': rows});
  void kill(String name) => _send({'type': 'kill', 'session': name});

  void dispose() => _socket?.close();
}
