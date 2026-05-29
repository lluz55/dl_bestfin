import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/financing/presentation/providers/financing_provider.dart';
import 'package:bestfin/features/financing/domain/models/financing.dart';
import 'package:bestfin/features/financing/domain/models/financing_installment.dart';

class FinancingDetailScreen extends ConsumerStatefulWidget {
  final String financingId;

  const FinancingDetailScreen({super.key, required this.financingId});

  @override
  ConsumerState<FinancingDetailScreen> createState() =>
      _FinancingDetailScreenState();
}

class _FinancingDetailScreenState extends ConsumerState<FinancingDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _extraPaymentController = TextEditingController();
  int _extraAmountCents = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _extraPaymentController.dispose();
    super.dispose();
  }

  void _onExtraPaymentChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _extraAmountCents = 0;
      });
      return;
    }
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      setState(() {
        _extraAmountCents = 0;
      });
      return;
    }
    final cents = int.parse(clean);
    final double amount = cents / 100.0;
    final formatted = amount.toStringAsFixed(2).replaceAll('.', ',');

    _extraPaymentController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    setState(() {
      _extraAmountCents = cents;
    });
  }

  Future<void> _togglePaidStatus(FinancingInstallment inst) async {
    final repo = ref.read(financingRepositoryProvider);
    final isPaid = !inst.isPaid;

    try {
      await repo.payInstallment(inst.id, isPaid);
      ref.invalidate(financingsStreamProvider);
      ref.invalidate(financingInstallmentsProvider(widget.financingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPaid
                  ? 'Parcela ${inst.number} marcada como PAGA!'
                  : 'Pagamento cancelado para parcela ${inst.number}.',
            ),
            backgroundColor: isPaid
                ? Colors.green.shade700
                : context.colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar parcela: $e'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteContract(Financing fin) async {
    final repo = ref.read(financingRepositoryProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Contrato?'),
        content: Text(
          'Tem certeza que deseja excluir o financiamento "${fin.name}" e todas as suas parcelas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colorScheme.error,
              foregroundColor: context.colorScheme.onError,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await repo.deleteFinancing(fin.id);
      ref.invalidate(financingsStreamProvider);
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contrato excluído com sucesso.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final financingAsync = ref.watch(financingByIdProvider(widget.financingId));
    final installmentsAsync = ref.watch(
      financingInstallmentsProvider(widget.financingId),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Detalhes do Contrato',
        actions: [
          financingAsync.when(
            data: (fin) => IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: cs.error,
              onPressed: () => _deleteContract(fin),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: financingAsync.when(
        data: (fin) {
          final double totalAmt = fin.totalAmount / 100.0;
          final double outstandingAmt = fin.outstandingBalance / 100.0;
          final double paidPrincipal =
              (fin.totalAmount - fin.outstandingBalance) / 100.0;

          return Column(
            children: [
              // Header Segment
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Text(
                      fin.name,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            fin.systemLabel,
                            style: tt.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Taxa: ${fin.interestRate}% a.m.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: cs.primary,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                tabs: const [
                  Tab(
                    text: 'Painel & Simulação',
                    icon: Icon(Icons.dashboard_outlined),
                  ),
                  Tab(
                    text: 'Tabela de Amortização',
                    icon: Icon(Icons.list_alt_rounded),
                  ),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Painel & Simulação
                    installmentsAsync.when(
                      data: (instList) {
                        final unpaid = instList
                            .where((i) => !i.isPaid)
                            .toList();
                        final paidCount = instList.length - unpaid.length;
                        final double progress = instList.isNotEmpty
                            ? paidCount / instList.length
                            : 0.0;

                        // Simulate extra payment
                        final simulation = _simulate(
                          extraAmount: _extraAmountCents,
                          outstanding: fin.outstandingBalance,
                          rate: fin.interestRate,
                          system: fin.amortizationSystem,
                          unpaid: unpaid,
                        );

                        return ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Circular Progress Overview Card
                            Card(
                              color: cs.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CircularProgressIndicator(
                                            value: progress,
                                            strokeWidth: 10,
                                            backgroundColor: cs.outlineVariant
                                                .withValues(alpha: 0.3),
                                            color: cs.primary,
                                          ),
                                          Center(
                                            child: Text(
                                              '${(progress * 100).toStringAsFixed(0)}%',
                                              style: tt.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _ProgressDetailRow(
                                            label: 'Original:',
                                            amount: totalAmt,
                                            tt: tt,
                                            cs: cs,
                                          ),
                                          const SizedBox(height: 6),
                                          _ProgressDetailRow(
                                            label: 'Amortizado:',
                                            amount: paidPrincipal,
                                            color: Colors.green.shade700,
                                            tt: tt,
                                            cs: cs,
                                          ),
                                          const SizedBox(height: 6),
                                          _ProgressDetailRow(
                                            label: 'Saldo Devedor:',
                                            amount: outstandingAmt,
                                            color: cs.primary,
                                            tt: tt,
                                            cs: cs,
                                          ),
                                          const Divider(height: 16),
                                          Text(
                                            '$paidCount de ${instList.length} parcelas quitadas',
                                            style: tt.bodySmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Extra Amortization Simulator
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.insights_rounded,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Simulador de Amortização Extra',
                                          style: tt.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Descubra quanto você economiza amortizando um valor extra hoje',
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _extraPaymentController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Valor Extra para Pagar',
                                        prefixText: 'R\$ ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onChanged: _onExtraPaymentChanged,
                                    ),
                                    if (_extraAmountCents > 0) ...[
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: cs.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.savings_outlined,
                                                  color: Colors.green.shade700,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Economia em Juros:',
                                                        style: tt.bodySmall,
                                                      ),
                                                      Text(
                                                        'R\$ ${(simulation.jurosSalvos / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
                                                        style: tt.titleLarge
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .green
                                                                  .shade700,
                                                            )
                                                            .merge(
                                                              AppTypography
                                                                  .monospace,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.speed_rounded,
                                                  color: cs.primary,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Redução no Prazo:',
                                                        style: tt.bodySmall,
                                                      ),
                                                      Text(
                                                        '${simulation.parcelasPoupadas} parcelas a menos!',
                                                        style: tt.titleLarge
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: cs.primary,
                                                            ),
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
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => Center(child: AppLoadingIndicator()),
                      error: (e, _) => Center(child: Text('Erro: $e')),
                    ),

                    // Tab 2: Tabela de Amortização
                    installmentsAsync.when(
                      data: (instList) {
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: instList.length,
                          itemBuilder: (context, idx) {
                            final inst = instList[idx];
                            final double valAmt = inst.totalValue / 100.0;
                            final double amortAmt =
                                inst.amortizationValue / 100.0;
                            final double interestAmt =
                                inst.interestValue / 100.0;
                            final double remainingAmt =
                                inst.remainingBalance / 100.0;

                            final isUnpaidOverdue =
                                !inst.isPaid &&
                                inst.dueDate.isBefore(DateTime.now());

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: inst.isPaid
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : (isUnpaidOverdue
                                            ? Colors.red.withValues(alpha: 0.3)
                                            : Colors.transparent),
                                  width: 1,
                                ),
                              ),
                              color: inst.isPaid
                                  ? Colors.green.withValues(alpha: 0.03)
                                  : (isUnpaidOverdue
                                        ? Colors.red.withValues(alpha: 0.03)
                                        : cs.surfaceContainerLow),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Checkbox for Paid Status
                                    Checkbox(
                                      value: inst.isPaid,
                                      onChanged: (_) => _togglePaidStatus(inst),
                                      activeColor: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Parcela ${inst.number}',
                                                style: tt.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Venc: ${inst.dueDate.day.toString().padLeft(2, '0')}/${inst.dueDate.month.toString().padLeft(2, '0')}/${inst.dueDate.year}',
                                                style: tt.bodySmall?.copyWith(
                                                  color: isUnpaidOverdue
                                                      ? cs.error
                                                      : cs.onSurfaceVariant,
                                                  fontWeight: isUnpaidOverdue
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _BreakdownItem(
                                                label: 'Total:',
                                                value: valAmt,
                                                color: cs.onSurface,
                                                tt: tt,
                                              ),
                                              _BreakdownItem(
                                                label: 'Amort:',
                                                value: amortAmt,
                                                color: cs.secondary,
                                                tt: tt,
                                              ),
                                              _BreakdownItem(
                                                label: 'Juros:',
                                                value: interestAmt,
                                                color: cs.tertiary,
                                                tt: tt,
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Saldo Devedor Restante:',
                                                style: tt.labelSmall?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                              Text(
                                                'R\$ ${remainingAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                                                style: tt.labelSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    )
                                                    .merge(
                                                      AppTypography.monospace,
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
                          },
                        );
                      },
                      loading: () => Center(child: AppLoadingIndicator()),
                      error: (e, _) => Center(child: Text('Erro: $e')),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  // Simulations logic
  _SimulationResult _simulate({
    required int extraAmount,
    required int outstanding,
    required double rate,
    required String system,
    required List<FinancingInstallment> unpaid,
  }) {
    if (extraAmount <= 0 || unpaid.isEmpty) {
      return const _SimulationResult(0, 0);
    }

    final int originalRemainingInterest = unpaid.fold<int>(
      0,
      (sum, inst) => sum + inst.interestValue,
    );

    int simulatedOutstanding = max(0, outstanding - extraAmount);
    if (simulatedOutstanding == 0) {
      return _SimulationResult(originalRemainingInterest, unpaid.length);
    }

    final double r = rate / 100.0;
    int simulatedInterest = 0;
    int simulatedInstallmentsCount = 0;

    if (system.toLowerCase() == 'sac') {
      final int amortizationPerMonth = unpaid.first.amortizationValue;

      while (simulatedOutstanding > 0 &&
          simulatedInstallmentsCount < unpaid.length) {
        simulatedInstallmentsCount++;
        final int interest = (simulatedOutstanding * r).round();
        final int amortization = min(
          simulatedOutstanding,
          amortizationPerMonth,
        );

        simulatedInterest += interest;
        simulatedOutstanding -= amortization;
      }
    } else {
      // Price
      final int pmt = unpaid.first.totalValue;

      while (simulatedOutstanding > 0 &&
          simulatedInstallmentsCount < unpaid.length) {
        simulatedInstallmentsCount++;
        final int interest = (simulatedOutstanding * r).round();
        final int amortization = min(
          simulatedOutstanding,
          max(0, pmt - interest),
        );

        if (amortization == 0) break; // Infinite loop safeguard

        simulatedInterest += interest;
        simulatedOutstanding -= amortization;
      }
    }

    final int jurosSalvos = max(
      0,
      originalRemainingInterest - simulatedInterest,
    );
    final int parcelasPoupadas = max(
      0,
      unpaid.length - simulatedInstallmentsCount,
    );

    return _SimulationResult(jurosSalvos, parcelasPoupadas);
  }
}

class _SimulationResult {
  final int jurosSalvos;
  final int parcelasPoupadas;

  const _SimulationResult(this.jurosSalvos, this.parcelasPoupadas);
}

class _ProgressDetailRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;
  final TextTheme tt;
  final ColorScheme cs;

  const _ProgressDetailRow({
    required this.label,
    required this.amount,
    this.color,
    required this.tt,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        Text(
          'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}',
          style: tt.bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: color)
              .merge(AppTypography.monospace),
        ),
      ],
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final TextTheme tt;

  const _BreakdownItem({
    required this.label,
    required this.value,
    required this.color,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}',
          style: tt.bodySmall
              ?.copyWith(fontWeight: FontWeight.bold, color: color)
              .merge(AppTypography.monospace),
        ),
      ],
    );
  }
}
