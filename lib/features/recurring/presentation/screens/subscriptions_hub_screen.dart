import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_form_modal_provider.dart';
import 'package:bestfin/features/recurring/presentation/widgets/recurring_card.dart';
import 'package:bestfin/features/recurring/presentation/widgets/recurring_form_modal_overlay.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

/// Hub de assinaturas: visão centralizada de recorrentes com total mensal.
class SubscriptionsHubScreen extends ConsumerWidget {
  const SubscriptionsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    ref.watch(valuesHiddenProvider);

    final asyncRules = ref.watch(activeRecurringProvider);
    final statsValue = ref.watch(recurringStatsProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: cs.surface,
          appBar: AppPageAppBar(
            title: 'Hub de Assinaturas',
            showVisibilityToggle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Nova recorrência',
                onPressed: () =>
                    ref.read(recurringFormModalProvider.notifier).open(),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Stats card com total mensal
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primaryContainer, cs.secondaryContainer],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.subscriptions_rounded,
                          color: cs.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statsValue
                                    .whenData(
                                      (s) => CurrencyFormatter.formatCents(
                                        s.totalMonthlyInCents.round(),
                                      ),
                                    )
                                    .value ??
                                '—',
                            style: tt.headlineMedium?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'total mensal em recorrentes',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Breakdown por categoria
              if (statsValue.hasValue &&
                  statsValue.value!.breakdownByCategory.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Por categoria',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CategoryBreakdown(
                          stats: statsValue.value!,
                          total: statsValue.value!.totalMonthlyInCents,
                        ),
                      ],
                    ),
                  ),
                ),

              // Lista de recorrentes ativas
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Recorrências ativas',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              asyncRules.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: AppLoadingIndicator()),
                ),
                error: (e, _) =>
                    SliverToBoxAdapter(child: Center(child: Text('Erro: $e'))),
                data: (rules) {
                  if (rules.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.subscriptions_outlined,
                              size: 56,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma assinatura ativa',
                              style: tt.titleMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Adicione serviços de streaming, planos e contas fixas para controlar seus gastos.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final rule = rules[index];
                      return RecurringCard(rule: rule);
                    }, childCount: rules.length),
                  );
                },
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                ref.read(recurringFormModalProvider.notifier).open(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova recorrência'),
          ),
        ),
        const RecurringFormModalOverlay(),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final RecurringStats stats;
  final double total;

  const _CategoryBreakdown({required this.stats, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final entries = stats.breakdownByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.error,
      cs.primaryContainer,
      cs.secondaryContainer,
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Barra de progresso empilhada
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: entries.asMap().entries.map((e) {
                    final fraction = e.value.value / total;
                    return Flexible(
                      flex: (fraction * 1000).round(),
                      child: Container(color: colors[e.key % colors.length]),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Legenda
          ...entries.asMap().entries.map((e) {
            final color = colors[e.key % colors.length];
            final pct = total > 0 ? (e.value.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value.key,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    CurrencyFormatter.formatCents(e.value.value.round()),
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
