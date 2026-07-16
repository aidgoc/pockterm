import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/terminal_client.dart';

void main() {
  test('handleMessage routes output to onOutput', () {
    String? gotSession;
    String? gotData;
    final c = TerminalClient.forTest();
    c.onOutput = (s, d) {
      gotSession = s;
      gotData = d;
    };
    c.handleMessage('{"type":"output","session":"a","data":"hi"}');
    expect(gotSession, 'a');
    expect(gotData, 'hi');
  });

  test('handleMessage updates session list', () {
    final c = TerminalClient.forTest();
    c.handleMessage('{"type":"sessions","sessions":["a","b"]}');
    expect(c.sessions, ['a', 'b']);
  });

  test('encodes input frame', () {
    final c = TerminalClient.forTest();
    expect(c.encodeInput('a', 'x'),
        '{"type":"input","session":"a","data":"x"}');
  });
}
