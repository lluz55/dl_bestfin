import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

// Recovery in the Nostr model = importing the mnemonic (the mnemonic IS the identity).
class MnemonicRecoveryScreen extends ConsumerStatefulWidget {
  const MnemonicRecoveryScreen({super.key});

  @override
  ConsumerState<MnemonicRecoveryScreen> createState() =>
      _MnemonicRecoveryScreenState();
}

class _MnemonicRecoveryScreenState
    extends ConsumerState<MnemonicRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mnemonicCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _mnemonicCtrl.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(nostrSyncServiceProvider)
          .importIdentity(_mnemonicCtrl.text.trim());
      if (mounted) context.go('/sync');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      String friendly;
      if (msg.contains('invalid mnemonic') || msg.contains('checksum')) {
        friendly = 'Frase inválida. Verifique as 24 palavras.';
      } else {
        friendly = 'Erro ao recuperar identidade. Tente novamente.';
      }
      setState(() => _error = friendly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Recuperar identidade'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.restore_rounded, size: 56, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                'Insira suas 24 palavras de recuperação para restaurar sua identidade.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _mnemonicCtrl,
                minLines: 3,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Frase de recuperação (24 palavras)',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.key_outlined),
                  ),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText: 'palavra1 palavra2 palavra3 ...',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Frase obrigatória';
                  final words = v.trim().split(RegExp(r'\s+'));
                  if (words.length != 24) {
                    return 'A frase deve ter exatamente 24 palavras '
                        '(${words.length} encontradas)';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: tt.bodySmall?.copyWith(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _recover,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppLoadingIndicator(strokeWidth: 2),
                      )
                    : const Text('Recuperar identidade'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
