import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class AppColors {
  static const bg = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const border = Color(0xFF30363D);
  static const text = Color(0xFFE6EDF3);
  static const dim = Color(0xFF8B949E);
  static const accent = Color(0xFF58A6FF);
  static const green = Color(0xFF3FB950);
  static const red = Color(0xFFF85149);
  static const yellow = Color(0xFFD29922);
}

const terminalTheme = TerminalTheme(
  cursor: AppColors.accent,
  selection: Color(0x5558A6FF),
  foreground: AppColors.text,
  background: AppColors.bg,
  black: Color(0xFF484F58),
  red: Color(0xFFF85149),
  green: Color(0xFF3FB950),
  yellow: Color(0xFFD29922),
  blue: Color(0xFF58A6FF),
  magenta: Color(0xFFBC8CFF),
  cyan: Color(0xFF39C5CF),
  white: Color(0xFFB1BAC4),
  brightBlack: Color(0xFF6E7681),
  brightRed: Color(0xFFFFA198),
  brightGreen: Color(0xFF56D364),
  brightYellow: Color(0xFFE3B341),
  brightBlue: Color(0xFF79C0FF),
  brightMagenta: Color(0xFFD2A8FF),
  brightCyan: Color(0xFF56D4DD),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFD29922),
  searchHitBackgroundCurrent: Color(0xFF58A6FF),
  searchHitForeground: Color(0xFF0D1117),
);
