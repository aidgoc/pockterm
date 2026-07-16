import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:app/models/server_config.dart';
import 'package:app/services/pairing.dart';

class PairScreen extends StatefulWidget {
  final void Function(ServerConfig) onPaired;
  const PairScreen({super.key, required this.onPaired});
  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _handleQr(String raw) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scanned = ServerConfig.fromQr(raw);
      final paired = await pair(scanned);
      widget.onPaired(paired);
    } catch (e) {
      setState(() {
        _error = 'Pairing failed: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with your computer')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (capture.barcodes.isEmpty) return;
                final code = capture.barcodes.first.rawValue;
                if (code != null) _handleQr(code);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _busy
                  ? 'Pairing…'
                  : _error ?? 'Run the pockterm installer on your computer, '
                      'then scan the QR it shows.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
