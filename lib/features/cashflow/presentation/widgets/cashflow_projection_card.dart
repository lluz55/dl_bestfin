import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/cashflow/presentation/providers/cashflow_provider.dart';

class CashFlowProjectionCard extends ConsumerWidget {
  const CashFlowProjectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final projectionAsync = ref.watch(cashFlowProjectionProvider);

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      onTap: () => context.push('/cashflow'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROJEÇÃO DE CAIXA',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 20),
          projectionAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: AppLoadingIndicator()),
            ),
            error: (e, _) => Text(
              'Sem dados disponíveis',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            data: (projection) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo atual',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatCents(projection.currentBalance),
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: projection.currentBalance >= 0
                        ? cs.onSurface
                        : cs.error,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _ProjectionChip(
                      label: '30 dias',
                      amount: projection.projectedBalance30d,
                      baseline: projection.currentBalance,
                      cs: cs,
                      tt: tt,
                    ),
                    const SizedBox(width: 8),
                    _ProjectionChip(
                      label: '60 dias',
                      amount: projection.projectedBalance60d,
                      baseline: projection.currentBalance,
                      cs: cs,
                      tt: tt,
                    ),
                    const SizedBox(width: 8),
                    _ProjectionChip(
                      label: '90 dias',
                      amount: projection.projectedBalance90d,
                      baseline: projection.currentBalance,
                      cs: cs,
                      tt: tt,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionChip extends StatelessWidget {
  final String label;
  final int amount;
  final int baseline;
  final ColorScheme cs;
  final TextTheme tt;

  const _ProjectionChip({
    required this.label,
    required this.amount,
    required this.baseline,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final delta = amount - baseline;
    final isPositive = delta >= 0;
    final color = amount < 0
        ? cs.error
        : (isPositive ? const Color(0xFF4CAF50) : cs.error);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.formatCents(amount),
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (delta != 0) ...[
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '+' : ''}${CurrencyFormatter.formatCents(delta)}',
                style: tt.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
