import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
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
    final isExpanded = Breakpoints.isExpanded(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(
        title: 'Parcelamentos',
        infoDescription: 'Acompanhe todas as suas compras parceladas, visualize o cronograma de pagamentos, parcelas restantes e o total de compromissos futuros.',
        infoFeatures: [
          'Cronograma completo de parcelas',
          'Total de compromissos futuros',
          'Valor por parcela e total',
          'Parcelas pagas e restantes',
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Nenhum parcelamento',
              description: 'Suas compras parceladas aparecerão aqui.',
            );
          }

          if (isExpanded) {
            return _buildExpandedLayout(plans, cs, tt);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final originTx = plan.transactions.isNotEmpty
                  ? plan.transactions.first
                  : null;
              return _buildPlanCard(plan, originTx, cs, tt);
            },
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (err, stack) => Center(
          child: Text('Erro: $err', style: TextStyle(color: cs.error)),
        ),
      ),
    );
  }

  Widget _buildExpandedLayout(
    List<dynamic> plans,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final originTx = plan.transactions.isNotEmpty
                  ? plan.transactions.first
                  : null;
              return _buildPlanListTile(plan, originTx, cs, tt);
            },
          ),
        ),
        const VerticalDivider(width: 1, thickness: 0.5),
        Expanded(
          child: Center(
            child: Text(
              'Selecione um parcelamento',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanListTile(
    dynamic plan,
    dynamic originTx,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isCompleted = plan.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          originTx?.description ?? 'Parcelamento',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Total: ${CurrencyFormatter.formatCents(plan.totalAmount)}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            InstallmentProgressWidget(
              paid: plan.paidInstallments,
              total: plan.totalInstallments,
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.paidInstallments}/${plan.totalInstallments} parcelas pagas',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        trailing: isCompleted
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              )
            : null,
        onTap: () {},
      ),
    );
  }

  Widget _buildPlanCard(
    dynamic plan,
    dynamic originTx,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isCompleted = plan.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                if (isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            InstallmentProgressWidget(
              paid: plan.paidInstallments,
              total: plan.totalInstallments,
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.paidInstallments}/${plan.totalInstallments} parcelas pagas',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}