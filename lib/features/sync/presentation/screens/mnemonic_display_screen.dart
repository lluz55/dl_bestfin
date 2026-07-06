import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/utils/secure_clipboard.dart';
import 'package:bestfin/core/utils/secure_screen.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';

class MnemonicDisplayScreen extends StatefulWidget {
  final String mnemonic;

  const MnemonicDisplayScreen({super.key, required this.mnemonic});

  @override
  State<MnemonicDisplayScreen> createState() => _MnemonicDisplayScreenState();
}

class _MnemonicDisplayScreenState extends State<MnemonicDisplayScreen> {
  bool _confirmed = false;
  bool _copied = false;

  List<String> get _words => widget.mnemonic.split(' ');

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  Future<void> _copy() async {
    await SecureClipboard.copyTemporarily(widget.mnemonic);
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: const AppPageAppBar(title: 'Frase de recuperação'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.key_rounded, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                'Guarde suas 24 palavras',
                textAlign: TextAlign.center,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Esta frase é a única forma de recuperar seus dados se você esquecer a senha. '
                'Anote em papel e guarde em local seguro. Não compartilhe com ninguém.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.8,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _words.length,
                      itemBuilder: (context, i) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.5),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${i + 1}.',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  _words[i],
                                  style: tt.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy_outlined,
                        size: 18,
                      ),
                      label: Text(_copied ? 'Copiado!' : 'Copiar frase'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: cs.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se perder esta frase e esquecer a senha, seus dados não poderão ser recuperados.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: Text(
                  'Confirmo que salvei minha frase de recuperação em local seguro.',
                  style: tt.bodyMedium,
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Continuar',
                expanded: true,
                onPressed: _confirmed
                    ? () {
                        context.pop();
                        context.pop();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
