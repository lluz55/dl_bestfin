import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bestfin/core/utils/secure_clipboard.dart';
import 'package:bestfin/core/utils/secure_screen.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';

class IdentityQrScreen extends StatefulWidget {
  final List<int> masterKey;

  const IdentityQrScreen({super.key, required this.masterKey});

  @override
  State<IdentityQrScreen> createState() => _IdentityQrScreenState();
}

class _IdentityQrScreenState extends State<IdentityQrScreen> {
  bool _revealed = false;
  bool _copied = false;
  late final String _mnemonic;

  @override
  void initState() {
    super.initState();
    _mnemonic = E2ECryptoService.masterKeyToMnemonic(widget.masterKey);
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  Future<void> _copy() async {
    await SecureClipboard.copyTemporarily(_mnemonic);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'QR da identidade'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este QR dá acesso completo à sua identidade. '
                      'Use apenas em locais privados e com dispositivos confiáveis.',
                      style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: _mnemonic,
                      version: QrVersions.auto,
                      size: 240,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  if (!_revealed)
                    GestureDetector(
                      onTap: () => setState(() => _revealed = true),
                      child: Container(
                        width: 272,
                        height: 272,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.95,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.visibility_off_rounded,
                              size: 40,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toque para revelar',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Dispositivo em mãos? Escaneie o QR acima com o app BestFin '
              'para importar sua identidade automaticamente.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(_copied ? 'Mnemônico copiado!' : 'Copiar mnemônico'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
