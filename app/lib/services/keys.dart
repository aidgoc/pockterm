/// Escape sequence for a named key, or the name unchanged if not special
/// (so literal symbols/digits pass through).
String keySequence(String name) {
  switch (name) {
    case 'up':
      return '\x1b[A';
    case 'down':
      return '\x1b[B';
    case 'right':
      return '\x1b[C';
    case 'left':
      return '\x1b[D';
    case 'esc':
      return '\x1b';
    case 'tab':
      return '\t';
    case 'shift-tab':
      return '\x1b[Z';
    case 'home':
      return '\x1b[H';
    case 'end':
      return '\x1b[F';
    case 'pgup':
      return '\x1b[5~';
    case 'pgdn':
      return '\x1b[6~';
    case 'enter':
      return '\r';
    default:
      return name;
  }
}

/// Apply armed modifiers to already-resolved key data.
/// shift → uppercase; ctrl → control byte for a single letter; alt → ESC prefix.
String applyModifiers(String data,
    {bool ctrl = false, bool alt = false, bool shift = false}) {
  var out = data;
  if (shift) {
    out = out.toUpperCase();
  }
  if (ctrl && out.length == 1) {
    final code = out.codeUnitAt(0);
    if (code >= 0x41 && code <= 0x5A) {
      out = String.fromCharCode(code - 0x40); // A-Z
    } else if (code >= 0x61 && code <= 0x7A) {
      out = String.fromCharCode(code - 0x60); // a-z
    }
  }
  if (alt) {
    out = '\x1b$out';
  }
  return out;
}
