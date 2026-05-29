import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';

class LimitBarWidget extends StatelessWidget {
  final CreditCardModel card;

  const LimitBarWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;

    final double total = card.limitAmount / 100.0;
    final double used = card.usedLimit / 100.0;
    final double available = card.availableLimit / 100.0;

    final double ratio = total > 0 ? (used / total) : 0.0;
    final String formattedUsed =
        'R\$ ${used.toStringAsFixed(2).replaceAll('.', ',')}';
    final String formattedAvailable =
        'R\$ ${available.toStringAsFixed(2).replaceAll('.', ',')}';
    final String formattedTotal =
        'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}';

    // Se aproximando do limite: cor de alerta (vermelho) acima de 85%
    final Color barColor = ratio > 0.85 ? colors.expense : cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Limite Utilizado',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Limite Disponível',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formattedUsed,
              style: tt.titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ratio > 0.85 ? colors.expense : cs.onSurface,
                  )
                  .merge(AppTypography.monospace),
            ),
            Text(
              formattedAvailable,
              style: tt.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: colors.income)
                  .merge(AppTypography.monospace),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Linear Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            width: double.infinity,
            color: cs.outlineVariant.withValues(alpha: 0.3),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(color: barColor),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(ratio * 100).toStringAsFixed(0)}% Utilizado',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Limite total: $formattedTotal',
              style: tt.labelSmall
                  ?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  )
                  .merge(AppTypography.monospace),
            ),
          ],
        ),
      ],
    );
  }
}
