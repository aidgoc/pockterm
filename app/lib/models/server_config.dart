import 'dart:convert';

class ServerConfig {
  final String host;
  final int port;
  final String fingerprint;
  final String name;
  final String? pairingToken;
  final String? sessionToken;

  ServerConfig({
    required this.host,
    required this.port,
    required this.fingerprint,
    required this.name,
    this.pairingToken,
    this.sessionToken,
  });

  factory ServerConfig.fromQr(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return ServerConfig(
      host: m['h'] as String,
      port: m['p'] as int,
      pairingToken: m['t'] as String,
      fingerprint: m['fp'] as String,
      name: m['n'] as String? ?? 'pockterm',
    );
  }

  ServerConfig withSessionToken(String token) => ServerConfig(
        host: host,
        port: port,
        fingerprint: fingerprint,
        name: name,
        sessionToken: token,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'fingerprint': fingerprint,
        'name': name,
        'sessionToken': sessionToken,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> m) => ServerConfig(
        host: m['host'] as String,
        port: m['port'] as int,
        fingerprint: m['fingerprint'] as String,
        name: m['name'] as String,
        sessionToken: m['sessionToken'] as String?,
      );

  String get baseUrl => 'https://$host:$port';
  String get wsUrl => 'wss://$host:$port/ws';
}
