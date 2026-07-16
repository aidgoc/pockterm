import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/server_config.dart';

void main() {
  test('parses QR payload', () {
    final cfg = ServerConfig.fromQr(
        '{"h":"192.168.1.5","p":8422,"t":"tok","fp":"abcd","n":"Mac"}');
    expect(cfg.host, '192.168.1.5');
    expect(cfg.port, 8422);
    expect(cfg.pairingToken, 'tok');
    expect(cfg.fingerprint, 'abcd');
    expect(cfg.name, 'Mac');
  });

  test('round-trips through json', () {
    final cfg = ServerConfig(
        host: 'h', port: 1, sessionToken: 's', fingerprint: 'f', name: 'n');
    final back = ServerConfig.fromJson(cfg.toJson());
    expect(back.host, 'h');
    expect(back.sessionToken, 's');
  });
}
