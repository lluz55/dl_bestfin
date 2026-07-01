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
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final backend = ref.read(backendSyncServiceProvider);
      await backend.signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('account_pending_approval')) {
      return 'Conta pendente de aprovação. Aguarde o administrador liberar seu acesso.';
    }
    if (msg.contains('account_rejected')) {
      return 'Conta rejeitada. Entre em contato com o administrador.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Sem conexão com a internet.';
    }
    if (msg.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    return 'Erro ao entrar. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Entrar'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.cloud_sync_rounded, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'BestFin Sync',
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Sincronize seus dados entre dispositivos',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || !v.contains('@') ? 'E-mail inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
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
                onPressed: _loading ? null : _signIn,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.push('/sync/register'),
                child: const Text('Criar conta'),
              ),
              TextButton(
                onPressed: () => context.push('/sync/recover'),
                child: Text(
                  'Esqueceu a senha? Recuperar com frase',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
