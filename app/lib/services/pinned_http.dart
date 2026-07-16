import 'dart:io';
import 'package:crypto/crypto.dart';

/// Returns an HttpClient that accepts ONLY the cert whose SHA-256 fingerprint
/// matches [fingerprintHex] (lower-case hex). Anything else is rejected.
HttpClient pinnedHttpClient(String fingerprintHex) {
  final client = HttpClient();
  client.badCertificateCallback = (X509Certificate cert, String host, int port) {
    final fp = sha256.convert(cert.der).toString();
    return fp == fingerprintHex.toLowerCase();
  };
  return client;
}
