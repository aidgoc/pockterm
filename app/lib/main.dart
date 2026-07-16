import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/server_config.dart';
import 'package:app/screens/pair_screen.dart';
import 'package:app/screens/terminal_screen.dart';

void main() => runApp(const PockApp());

class PockApp extends StatefulWidget {
  const PockApp({super.key});
  @override
  State<PockApp> createState() => _PockAppState();
}

class _PockAppState extends State<PockApp> {
  ServerConfig? _config;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('server');
    setState(() {
      _config = raw == null
          ? null
          : ServerConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _loaded = true;
    });
  }

  Future<void> _save(ServerConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server', jsonEncode(cfg.toJson()));
    setState(() => _config = cfg);
  }

  Future<void> _forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server');
    setState(() => _config = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pockterm',
      theme: ThemeData.dark(useMaterial3: true),
      home: !_loaded
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _config == null
              ? PairScreen(onPaired: _save)
              : TerminalScreen(config: _config!, onForget: _forget),
    );
  }
}
