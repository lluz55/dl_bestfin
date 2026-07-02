import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mnemonicCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _mnemonicCtrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(nostrSyncServiceProvider)
          .importIdentity(_mnemonicCtrl.text.trim());
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid mnemonic') || msg.contains('checksum')) {
      return 'Frase inválida. Verifique as 24 palavras e tente novamente.';
    }
    return 'Erro ao importar identidade. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Importar identidade'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.key_rounded, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'BestFin Sync',
                textAlign: TextAlign.center,
                style:
                    tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Insira suas 24 palavras para acessar sua identidade',
                textAlign: TextAlign.center,
                style:
                    tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _mnemonicCtrl,
                minLines: 4,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Frase de recuperação (24 palavras)',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 56),
                    child: Icon(Icons.article_outlined),
                  ),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  hintText: 'palavra1 palavra2 palavra3 ...',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Frase obrigatória';
                  }
                  final words = v.trim().split(RegExp(r'\s+'));
                  if (words.length != 24) {
                    return 'A frase deve ter 24 palavras (${words.length} encontradas)';
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
                onPressed: _loading ? null : _import,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Importar'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/sync/scan'),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Escanear QR de outro dispositivo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/sync/register'),
                child: const Text('Criar nova identidade'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
