import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/profile_editor.dart';

/// Step opcional do onboarding para o usuário se apresentar (nome e foto).
/// Os campos gravam direto no `userProfileProvider`, então "Continuar" segue
/// adiante com ou sem preenchimento.
class ProfileStep extends StatelessWidget {
  const ProfileStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
                'Como podemos te chamar?',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              )
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 400))
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
                'Opcional: seu nome e foto aparecem na tela inicial. '
                'Dá para alterar depois nas configurações.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              )
              .animate(delay: const Duration(milliseconds: 150))
              .fadeIn(duration: const Duration(milliseconds: 400))
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 40),
          const ProfileEditor()
              .animate(delay: const Duration(milliseconds: 300))
              .fadeIn(duration: const Duration(milliseconds: 400))
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 40),
          AppButton(label: 'Continuar', expanded: true, onPressed: onNext)
              .animate(delay: const Duration(milliseconds: 450))
              .fadeIn()
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
