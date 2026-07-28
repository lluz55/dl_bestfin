import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/modal_overlay_wrapper.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/features/financing/presentation/providers/financing_provider.dart';
import 'package:bestfin/features/financing/presentation/providers/financing_form_modal_provider.dart';
import 'package:bestfin/features/financing/presentation/widgets/financing_form_modal_overlay.dart';
import 'package:bestfin/features/financing/domain/models/financing.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

class FinancingListScreen extends ConsumerWidget {
  const FinancingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final cs = context.colorScheme;
    ref.watch(valuesHiddenProvider);
    final financingsAsync = ref.watch(financingsStreamProvider);
    final summary = ref.watch(financingSummaryProvider);

    return ModalOverlayWrapper(
      overlay: const FinancingFormModalOverlay(),
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppPageAppBar(
          title: 'Financiamentos',
          showVisibilityToggle: true,
          infoDescription: 'Controle seus financiamentos com tabela Price. Acompanhe saldo devedor, parcelas pagas, taxa de juros e projeções.',
          infoFeatures: const [
            'Saldo devedor total consolidado',
            'Tabela Price com parcelas detalhadas',
            'Projeção de amortização',
            'Acompanhamento de parcelas pagas',
          ],
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Novo contrato',
              onPressed: () =>
                  ref.read(financingFormModalProvider.notifier).open(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(financingsStreamProvider);
          },
          child: financingsAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: EmptyState(
                    title: 'Nenhum Financiamento',
                    description:
                        'Acompanhe seus financiamentos de imóveis ou veículos com tabela de amortização e simulador.',
                    icon: Icons.home_work_rounded,
                    actionLabel: 'Adicionar Financiamento',
                    onAction: () =>
                        ref.read(financingFormModalProvider.notifier).open(),
                  ),
                );
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Consolidated Summary Header Card
                  SliverToBoxAdapter(
                    child: _FinancingSummaryCard(summary: summary)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'Meus Contratos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),

                  // Financing contracts list
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, idx) {
                      final financing = list[idx];
                      return _FinancingContractCard(
                        financing: financing,
                        onTap: () => context.push('/financing/${financing.id}'),
                      ).animate().fadeIn(
                        duration: 350.ms,
                        delay: Duration(milliseconds: idx * 60),
                      );
                    }, childCount: list.length),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
        ),
      ),
    );
  }
}

class _FinancingSummaryCard extends StatelessWidget {
  final FinancingSummary summary;

  const _FinancingSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final double totalBalanceAmt = summary.totalOutstandingBalance / 100.0;
    final double originalAmt = summary.totalOriginalAmount / 100.0;
    final double paidAmt =
        (summary.totalOriginalAmount - summary.totalOutstandingBalance) / 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.secondary],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SALDO DEVEDOR TOTAL',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.65),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.home_work_outlined,
                  color: cs.onPrimary.withValues(alpha: 0.8),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'R\$ ${totalBalanceAmt.toStringAsFixed(2).replaceAll('.', ',')}',
              style: tt.headlineLarge
                  ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w900)
                  .merge(AppTypography.monospace),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Financiado',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'R\$ ${originalAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: tt.titleMedium
                            ?.copyWith(
                              color: cs.onPrimary,
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
                  color: cs.onPrimary.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amortizado',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'R\$ ${paidAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: tt.titleMedium
                            ?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                            )
                            .merge(AppTypography.monospace),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amortização Geral',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${summary.paidProgressPercentage.toStringAsFixed(1)}% Pago',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.paidProgressPercentage / 100,
                backgroundColor: cs.onPrimary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancingContractCard extends ConsumerWidget {
  final Financing financing;
  final VoidCallback onTap;

  const _FinancingContractCard({required this.financing, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final installmentsAsync = ref.watch(
      financingInstallmentsProvider(financing.id),
    );

    final double originalAmt = financing.totalAmount / 100.0;
    final double outstandingAmt = financing.outstandingBalance / 100.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      financing.name,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      financing.systemLabel,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo Devedor',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'R\$ ${outstandingAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold)
                            .merge(AppTypography.monospace),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Valor Financiado',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'R\$ ${originalAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold)
                            .merge(AppTypography.monospace),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              installmentsAsync.when(
                data: (instList) {
                  final total = instList.length;
                  final paid = instList.where((i) => i.isPaid).length;
                  final progress = total > 0 ? paid / total : 0.0;

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$paid de $total parcelas pagas',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Taxa: ${financing.interestRate}% a.m.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: cs.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 20),
                error: (_, _) => const SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
