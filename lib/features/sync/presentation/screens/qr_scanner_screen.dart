import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    String? mnemonic;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;
      mnemonic = E2ECryptoService.qrPayloadToMnemonic(raw);
      if (mnemonic != null) break;
    }
    if (mnemonic == null) {
      // Só sinaliza erro se algum código foi realmente lido — caso contrário é
      // apenas um frame sem QR e a câmera continua tentando.
      if (capture.barcodes.isNotEmpty && mounted && _error == null) {
        setState(
          () => _error =
              'Este QR não é um pareamento do BestFin. Gere o QR em '
              'Configurações › Sincronização no outro dispositivo.',
        );
      }
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });
    unawaited(_controller.stop());

    try {
      await ref.read(nostrSyncServiceProvider).importIdentity(mnemonic);
      if (mounted) context.go('/sync');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Falha ao importar a identidade deste QR. Tente novamente.';
        _processing = false;
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: Breakpoints.isCompact(context),
        title: const Text('Escanear QR', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () => _controller.toggleTorch(),
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, state, _) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Viewfinder overlay
          Center(
            child: CustomPaint(
              size: const Size(260, 260),
              painter: _ViewfinderPainter(cs.primary),
            ),
          ),
          // Instructions / status
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                if (_processing) ...[
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Importando identidade...',
                    style: tt.bodyMedium?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _error = null),
                    child: const Text(
                      'Tentar novamente',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ] else
                  Text(
                    'Aponte para o QR code gerado em outro dispositivo',
                    style: tt.bodyMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color color;
  const _ViewfinderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLen = 24.0;
    const r = 8.0;
    final w = size.width;
    final h = size.height;

    // top-left
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14, 1.57, false, paint);
    canvas.drawLine(const Offset(r, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, cornerLen), paint);

    // top-right
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2),
      4.71,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(Offset(w - cornerLen, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, cornerLen), paint);

    // bottom-left
    canvas.drawArc(
      Rect.fromLTWH(0, h - r * 2, r * 2, r * 2),
      1.57,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(Offset(0, h - cornerLen), Offset(0, h - r), paint);
    canvas.drawLine(Offset(r, h), Offset(cornerLen, h), paint);

    // bottom-right
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2),
      0,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(Offset(w, h - cornerLen), Offset(w, h - r), paint);
    canvas.drawLine(Offset(w - cornerLen, h), Offset(w - r, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
