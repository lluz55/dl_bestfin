import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/features/installments/presentation/providers/installments_provider.dart';
import 'package:bestfin/features/installments/presentation/widgets/installment_progress_widget.dart';

class InstallmentsListScreen extends ConsumerWidget {
  const InstallmentsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final plansAsync = ref.watch(installmentPlansProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Parcelamentos'),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Nenhum parcelamento',
              description: 'Suas compras parceladas aparecerão aqui.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final originTx = plan.transactions.isNotEmpty
                  ? plan.transactions.first
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              originTx?.description ?? 'Parcelamento',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (plan.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cs.tertiary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Concluído',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: ${CurrencyFormatter.formatCents(plan.totalAmount)}',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InstallmentProgressWidget(
                        paid: plan.paidInstallments,
                        total: plan.totalInstallments,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Erro: $err', style: TextStyle(color: cs.error)),
        ),
      ),
    );
  }
}
