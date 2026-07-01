import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final backend = ref.read(backendSyncServiceProvider);
      await backend.signUpWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
      if (mounted) {
        unawaited(showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.hourglass_top_rounded, size: 48),
            title: const Text('Conta criada!'),
            content: const Text(
              'Sua conta foi criada com sucesso. Aguarde a aprovação do administrador para acessar.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pop();
                },
                child: const Text('Voltar ao login'),
              ),
            ],
          ),
        ));
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already registered') || msg.contains('duplicate')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (msg.contains('account_pending_approval')) {
      return 'Conta pendente de aprovação. Aguarde o administrador liberar seu acesso.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Sem conexão com a internet.';
    }
    if (msg.contains('too many requests')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    return 'Erro ao criar conta. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Criar conta'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: 16),
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
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                decoration: const InputDecoration(
                  labelText: 'Confirmar senha',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v != _passwordCtrl.text ? 'Senhas não conferem' : null,
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
                onPressed: _loading ? null : _register,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar conta'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Já tenho uma conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
