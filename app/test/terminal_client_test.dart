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
}
