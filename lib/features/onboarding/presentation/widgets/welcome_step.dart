import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: context.primaryGradient,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 56,
                    color: cs.onPrimary,
                  ),
                )
                .animate()
                .scaleXY(
                  begin: 0.6,
                  end: 1.0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: const Duration(milliseconds: 400)),
            const SizedBox(height: 32),
            Text(
                  'Bem-vindo ao\nBestFin',
                  textAlign: TextAlign.center,
                  style: tt.headlineLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                )
                .animate(delay: const Duration(milliseconds: 200))
                .fadeIn(duration: const Duration(milliseconds: 400))
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 12),
            Text(
                  'Controle suas finanças de forma simples, visual e inteligente.',
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                )
                .animate(delay: const Duration(milliseconds: 350))
                .fadeIn(duration: const Duration(milliseconds: 400))
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 32),
            _FeatureRow(
                  icon: Icons.track_changes_rounded,
                  label: 'Acompanhe gastos em tempo real',
                  color: cs.primary,
                )
                .animate(delay: const Duration(milliseconds: 500))
                .fadeIn()
                .slideX(begin: -0.1, end: 0),
            const SizedBox(height: 12),
            _FeatureRow(
                  icon: Icons.pie_chart_rounded,
                  label: 'Visualize onde seu dinheiro vai',
                  color: cs.secondary,
                )
                .animate(delay: const Duration(milliseconds: 580))
                .fadeIn()
                .slideX(begin: -0.1, end: 0),
            const SizedBox(height: 12),
            _FeatureRow(
                  icon: Icons.flag_rounded,
                  label: 'Defina e alcance seus objetivos',
                  color: cs.tertiary,
                )
                .animate(delay: const Duration(milliseconds: 660))
                .fadeIn()
                .slideX(begin: -0.1, end: 0),
            const SizedBox(height: 32),
            FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Começar',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .animate(delay: const Duration(milliseconds: 750))
                .fadeIn()
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
            const SizedBox(height: 12),
            OutlinedButton(
                  onPressed: () => context.push('/sync/login'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Text(
                    'Sincronizar com dispositivo existente',
                    style: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .animate(delay: const Duration(milliseconds: 820))
                .fadeIn()
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
