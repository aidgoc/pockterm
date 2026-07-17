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
