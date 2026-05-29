import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/widgets/animated_card.dart';

class IncomeExpenseBar extends StatelessWidget {
  final int monthlyIncome;
  final int monthlyExpense;

  const IncomeExpenseBar({
    super.key,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final income = monthlyIncome.abs() / 100.0;
    final expense = monthlyExpense.abs() / 100.0;
    final total = income + expense;

    final double incomeWeight = total > 0 ? (income / total) : 0.5;
    final double expenseWeight = total > 0 ? (expense / total) : 0.5;

    final formattedIncome =
        'R\$ ${income.toStringAsFixed(2).replaceAll('.', ',')}';
    final formattedExpense =
        'R\$ ${expense.toStringAsFixed(2).replaceAll('.', ',')}';

    final percentSpent = income > 0 ? (expense / income) * 100 : 0.0;

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPARATIVO MENSAL',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: 'Receitas',
                value: formattedIncome,
                color: cs.primary,
                cs: cs,
                tt: tt,
              ),
              _StatItem(
                label: 'Despesas',
                value: formattedExpense,
                color: cs.error,
                cs: cs,
                tt: tt,
                crossAxisAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Horizontal Proportional Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (total == 0)
                    Expanded(
                      child: Container(
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    )
                  else ...[
                    if (income > 0)
                      Expanded(
                        flex: (incomeWeight * 100).round(),
                        child: Container(color: cs.primary),
                      ),
                    if (expense > 0)
                      Expanded(
                        flex: (expenseWeight * 100).round(),
                        child: Container(color: cs.error),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (income > 0) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comprometimento da receita:',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${percentSpent.toStringAsFixed(1)}%',
                  style: tt.labelMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: percentSpent > 100
                            ? cs.error
                            : cs.onSurface,
                      )
                      .merge(AppTypography.monospace),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;
  final CrossAxisAlignment crossAxisAlignment;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
    required this.tt,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (crossAxisAlignment == CrossAxisAlignment.start) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            if (crossAxisAlignment == CrossAxisAlignment.end) ...[
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: tt.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface)
              .merge(AppTypography.monospace),
        ),
      ],
    );
  }
}
