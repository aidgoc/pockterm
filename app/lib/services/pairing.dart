import 'dart:convert';
import 'dart:io';
import 'package:app/models/server_config.dart';
import 'package:app/services/pinned_http.dart';

/// Exchanges the pairing token for a durable session token.
Future<ServerConfig> pair(ServerConfig scanned) async {
  final client = pinnedHttpClient(scanned.fingerprint);
  try {
    final req = await client.postUrl(Uri.parse('${scanned.baseUrl}/api/pair'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'token': scanned.pairingToken}));
    final resp = await req.close();
    final bodyStr = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      throw Exception('Pairing failed (${resp.statusCode})');
    }
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    return scanned.withSessionToken(body['token'] as String);
  } finally {
    client.close();
  }
}
