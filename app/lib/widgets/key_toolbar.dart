import 'package:flutter/material.dart';
import 'package:app/theme/app_theme.dart';

/// Horizontal, grouped, scrollable key toolbar matching the Jarvis mini-app.
/// - onKey(name): a named key (arrows/esc/tab/home/…) or a literal (symbol/digit);
///   the screen resolves the escape sequence and applies armed modifiers.
/// - onCtrl(letter): a direct ctrl-combo (C-c … C-r), sent verbatim.
/// - onToggleMod('shift'|'ctrl'|'alt'): arm/disarm a sticky modifier.
class KeyToolbar extends StatelessWidget {
  final bool ctrl;
  final bool alt;
  final bool shift;
  final void Function(String name) onKey;
  final void Function(String letter) onCtrl;
  final void Function(String mod) onToggleMod;
  final VoidCallback onDismiss;
  final VoidCallback onPaste;

  const KeyToolbar({
    super.key,
    required this.ctrl,
    required this.alt,
    required this.shift,
    required this.onKey,
    required this.onCtrl,
    required this.onToggleMod,
    required this.onDismiss,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
            6, 4, 6, 4 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          _group([_btn('⌨', onDismiss, wide: true)]),
          _group([
            _btn('▲', () => onKey('up')),
            _btn('▼', () => onKey('down')),
            _btn('◀', () => onKey('left')),
            _btn('▶', () => onKey('right')),
          ]),
          _group([
            _btn('Shift', () => onToggleMod('shift'), active: shift, wide: true),
            _btn('Tab', () => onKey('tab'), wide: true),
            _btn('⇧Tab', () => onKey('shift-tab'), wide: true),
          ]),
          _group([for (final d in ['1', '2', '3', '4', '5']) _btn(d, () => onKey(d))]),
          _group([_btn('C-c', () => onCtrl('c'), danger: true)]),
          _group([
            _btn('Ctrl', () => onToggleMod('ctrl'), active: ctrl, wide: true),
            _btn('Alt', () => onToggleMod('alt'), active: alt, wide: true),
          ]),
          _group([for (final l in ['d', 'z', 'l', 'a', 'r']) _btn('C-$l', () => onCtrl(l))]),
          _group([
            _btn('Esc', () => onKey('esc'), wide: true),
            _btn('Hom', () => onKey('home')),
            _btn('End', () => onKey('end')),
            _btn('PgU', () => onKey('pgup')),
            _btn('PgD', () => onKey('pgdn')),
          ]),
          _group([
            for (final s in ['|', '~', '/', '-', '_', '`', r'$', '&'])
              _btn(s, () => onKey(s))
          ]),
          _group([_btn('Paste', onPaste, wide: true)]),
        ]),
      ),
    );
  }

  Widget _group(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Row(children: children),
      );

  Widget _btn(String label, VoidCallback onTap,
      {bool wide = false, bool active = false, bool danger = false}) {
    final bg = active ? AppColors.accent : AppColors.bg;
    final fg = active ? Colors.white : AppColors.dim;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: SizedBox(
        width: wide ? 50 : 40,
        height: 36,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: danger ? AppColors.red : fg,
            side: const BorderSide(color: AppColors.border),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5)),
            textStyle: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
