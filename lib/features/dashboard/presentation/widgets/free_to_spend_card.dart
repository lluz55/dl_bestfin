import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/color_schemes.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/balance_card.dart';

class FreeToSpendCard extends StatelessWidget {
  final int amountInCents;
  final double percentage;

  const FreeToSpendCard({
    super.key,
    required this.amountInCents,
    required this.percentage,
  });

  Color _ringColor(CustomColors custom) {
    if (percentage >= 0.50) return custom.income;
    if (percentage >= 0.20) return custom.warning;
    return custom.expense;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final custom = context.customColors;
    final ringColor = _ringColor(custom);

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVRE PARA GASTAR',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCounter(
                      value: amountInCents,
                      style: tt.headlineMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saldo seguro para gastar até o fim do mês, descontadas as despesas pendentes e metas de poupança.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: percentage),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        backgroundColor: cs.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                    ),
                  ),
                  Icon(Icons.wallet_outlined, color: ringColor, size: 24),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
