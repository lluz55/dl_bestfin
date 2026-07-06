import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/expressive_fab.dart';
import 'package:bestfin/core/widgets/modal_overlay_wrapper.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/features/investments/presentation/providers/investments_provider.dart';
import 'package:bestfin/features/investments/presentation/providers/investment_form_modal_provider.dart';
import 'package:bestfin/features/investments/presentation/widgets/investment_form_modal_overlay.dart';
import 'package:bestfin/features/investments/domain/models/investment.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final cs = context.colorScheme;
    ref.watch(valuesHiddenProvider);
    final investmentsAsync = ref.watch(investmentsStreamProvider);
    final summary = ref.watch(portfolioSummaryProvider);

    return ModalOverlayWrapper(
      overlay: const InvestmentFormModalOverlay(),
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: const AppPageAppBar(
          title: 'Meus Investimentos',
          showVisibilityToggle: true,
        ),
        floatingActionButton: ExpressiveFAB.extended(
          onPressed: () =>
              ref.read(investmentFormModalProvider.notifier).open(),
          icon: Icons.add_chart_rounded,
          label: 'Novo Ativo',
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(investmentsStreamProvider);
          },
          child: investmentsAsync.when(
            data: (investmentsList) {
              if (investmentsList.isEmpty) {
                return Center(
                  child: EmptyState(
                    title: 'Nenhum Investimento',
                    description:
                        'Acompanhe seus investimentos em Renda Fixa, Ações, FIIs, Cripto e mais.',
                    icon: Icons.trending_up_rounded,
                    actionLabel: 'Adicionar Investimento',
                    onAction: () =>
                        ref.read(investmentFormModalProvider.notifier).open(),
                  ),
                );
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Portfolio Header Card
                  SliverToBoxAdapter(
                    child: _PortfolioHeaderCard(summary: summary)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                  ),

                  // Donut Chart Allocation
                  if (summary.totalValue > 0)
                    SliverToBoxAdapter(
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alocação por Tipo',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _AllocationDonutChart(summary: summary),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    ),

                  // Section title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'Meus Ativos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),

                  // Assets list
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final inv = investmentsList[index];
                      return _InvestmentAssetCard(
                        investment: inv,
                        onTap: () => context.push('/investments/${inv.id}'),
                      ).animate().fadeIn(
                        duration: 300.ms,
                        delay: Duration(milliseconds: index * 50),
                      );
                    }, childCount: investmentsList.length),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
            loading: () => Center(child: AppLoadingIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
        ),
      ),
    );
  }
}

class _PortfolioHeaderCard extends StatelessWidget {
  final PortfolioSummary summary;

  const _PortfolioHeaderCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final double valueAmt = summary.totalValue / 100.0;

    final isPositive = summary.totalYield >= 0;
    final color = isPositive
        ? context.customColors.income
        : context.customColors.expense;
    final sign = isPositive ? '+' : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer,
            cs.tertiaryContainer.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.03),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VALOR TOTAL ATUAL',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.6),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'R\$ ${valueAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: tt.headlineLarge
                        ?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w900,
                        )
                        .merge(AppTypography.monospace),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Valor Aplicado',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onPrimaryContainer.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'R\$ ${(summary.totalInvested / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
                              style: tt.titleMedium
                                  ?.copyWith(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  )
                                  .merge(AppTypography.monospace),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rendimento Geral',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onPrimaryContainer.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '$sign${summary.yieldPercentage.toStringAsFixed(2)}%',
                                    style: tt.titleMedium
                                        ?.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                        )
                                        .merge(AppTypography.monospace),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationDonutChart extends StatelessWidget {
  final PortfolioSummary summary;

  const _AllocationDonutChart({required this.summary});

  static const _colors = [
    Color(0xFF6750A4),
    Color(0xFF0288D1),
    Color(0xFFE65100),
    Color(0xFF2E7D32),
    Color(0xFFFBC02D),
    Color(0xFF6A1B9A),
    Color(0xFFC62828),
  ];

  Color _colorForIndex(int idx) => _colors[idx % _colors.length];

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final keys = summary.allocationPercentages.keys.toList();

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(keys.length, (idx) {
                final pct = summary.allocationPercentages[keys[idx]] ?? 0.0;
                return PieChartSectionData(
                  color: _colorForIndex(idx),
                  value: pct * 100,
                  radius: 20,
                  showTitle: false,
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(keys.length, (idx) {
              final type = keys[idx];
              final pct = summary.allocationPercentages[type] ?? 0.0;
              final typeLabel = _typeLabel(type);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorForIndex(idx),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        typeLabel,
                        style: tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}%',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'fixed_income':
        return 'Renda Fixa';
      case 'stocks':
        return 'Ações';
      case 'fiis':
        return 'FIIs';
      case 'crypto':
        return 'Criptomoedas';
      case 'savings':
        return 'Poupança';
      case 'cdb':
        return 'CDB';
      case 'tesouro':
        return 'Tesouro';
      default:
        return 'Outros';
    }
  }
}

class _InvestmentAssetCard extends StatelessWidget {
  final Investment investment;
  final VoidCallback onTap;

  const _InvestmentAssetCard({required this.investment, required this.onTap});

  IconData _iconForType(String type) {
    switch (type) {
      case 'fixed_income':
        return Icons.trending_up_rounded;
      case 'stocks':
        return Icons.show_chart_rounded;
      case 'fiis':
        return Icons.domain_rounded;
      case 'crypto':
        return Icons.currency_bitcoin_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'cdb':
        return Icons.account_balance_rounded;
      case 'tesouro':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.insert_chart_outlined_rounded;
    }
  }

  Color _colorForType(String type, ColorScheme cs) {
    switch (type) {
      case 'fixed_income':
        return cs.primary;
      case 'stocks':
        return cs.secondary;
      case 'fiis':
        return cs.tertiary;
      case 'crypto':
        return Colors.orange.shade700;
      case 'savings':
        return Colors.teal.shade700;
      case 'cdb':
        return Colors.blue.shade700;
      case 'tesouro':
        return Colors.deepPurple.shade700;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final custom = context.customColors;

    final double totalAmt = investment.totalValue / 100.0;
    final double yieldPct = investment.yieldPercentage;
    final isPositive = investment.currentYield >= 0;

    final yieldColor = isPositive ? custom.income : custom.expense;
    final yieldSign = isPositive ? '+' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _colorForType(investment.type, cs).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconForType(investment.type),
            color: _colorForType(investment.type, cs),
          ),
        ),
        title: Text(
          investment.name,
          style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            investment.typeLabel,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'R\$ ${totalAmt.toStringAsFixed(2).replaceAll('.', ',')}',
              style: tt.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold)
                  .merge(AppTypography.monospace),
            ),
            const SizedBox(height: 4),
            Text(
              '$yieldSign${yieldPct.toStringAsFixed(2)}%',
              style: tt.bodySmall
                  ?.copyWith(color: yieldColor, fontWeight: FontWeight.bold)
                  .merge(AppTypography.monospace),
            ),
          ],
        ),
      ),
    );
  }
}
