import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/budgets/presentation/providers/budgets_provider.dart';

class BudgetsOverviewCard extends ConsumerWidget {
  const BudgetsOverviewCard({super.key});

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final budgetsAsync = ref.watch(currentPeriodBudgetsProvider);

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      onTap: () => context.push('/budgets'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORÇAMENTO',
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
          budgetsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: AppLoadingIndicator()),
            ),
            error: (e, _) => Text(
              'Sem dados disponíveis',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            data: (budgets) {
              if (budgets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nenhum orçamento criado.',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Planeje seus gastos por categoria.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => context.push('/budgets'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Criar'),
                      ),
                    ],
                  ),
                );
              }

              final totalBudget = budgets.fold<int>(
                0,
                (s, b) => s + b.totalBudget,
              );
              final totalSpent = budgets.fold<int>(0, (s, b) => s + b.spent);
              final totalPending = budgets.fold<int>(
                0,
                (s, b) => s + b.pending,
              );
              final progress = totalBudget == 0
                  ? 0.0
                  : (totalSpent / totalBudget).clamp(0.0, 1.0);
              final projectedProgress = totalBudget == 0
                  ? 0.0
                  : ((totalSpent + totalPending) / totalBudget).clamp(0.0, 1.0);
              final overBudget = budgets.where((b) => b.isOverBudget).length;
              final progressColor = overBudget > 0
                  ? cs.error
                  : (progress >= 0.75
                        ? context.customColors.warning
                        : cs.primary);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.formatCents(totalSpent),
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: progressColor,
                            ),
                          ),
                          Text(
                            'de ${CurrencyFormatter.formatCents(totalBudget)} planejados',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (totalPending > 0)
                            Text(
                              '+ ${CurrencyFormatter.formatCents(totalPending)} previsto',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      if (overBudget > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$overBudget no limite',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        // Camada clara: gasto confirmado + previsto.
                        LinearProgressIndicator(
                          value: projectedProgress,
                          minHeight: 8,
                          backgroundColor: cs.surfaceContainerHigh,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor.withValues(alpha: 0.35),
                          ),
                        ),
                        // Camada sólida: só o gasto confirmado.
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: budgets.take(4).map((b) {
                      final color = _parseColor(b.categoryColor, cs.primary);
                      final bProgress = b.progress.clamp(0.0, 1.0);
                      final bColor = b.isOverBudget
                          ? cs.error
                          : (bProgress >= 0.75
                                ? context.customColors.warning
                                : color);

                      return Chip(
                        label: Text(
                          '${b.name} ${(bProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: bColor,
                          ),
                        ),
                        backgroundColor: bColor.withValues(alpha: 0.08),
                        side: BorderSide(color: bColor.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        labelPadding: const EdgeInsets.only(right: 4),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
