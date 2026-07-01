import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/cashflow/domain/models/cashflow_projection.dart';
import 'package:bestfin/features/cashflow/presentation/providers/cashflow_provider.dart';

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final projectionAsync = ref.watch(cashFlowProjectionProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Projeção de Caixa'),
      body: projectionAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Erro: $err',
            style: tt.bodyMedium?.copyWith(color: cs.error),
          ),
        ),
        data: (projection) => RefreshIndicator(
          onRefresh: () => ref.refresh(cashFlowProjectionProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _SummaryCard(projection: projection, cs: cs, tt: tt),
              const SizedBox(height: 16),
              _buildHorizonCards(projection, cs, tt),
              const SizedBox(height: 20),
              if (projection.points.isNotEmpty) ...[
                Text(
                  'Próximos lançamentos',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._buildEventList(projection, cs, tt),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizonCards(
    CashFlowProjection projection,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Row(
      children: [
        _HorizonCard(
          days: 30,
          amount: projection.projectedBalance30d,
          baseline: projection.currentBalance,
          cs: cs,
          tt: tt,
        ),
        const SizedBox(width: 8),
        _HorizonCard(
          days: 60,
          amount: projection.projectedBalance60d,
          baseline: projection.currentBalance,
          cs: cs,
          tt: tt,
        ),
        const SizedBox(width: 8),
        _HorizonCard(
          days: 90,
          amount: projection.projectedBalance90d,
          baseline: projection.currentBalance,
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }

  List<Widget> _buildEventList(
    CashFlowProjection projection,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final events = projection.points
        .where((p) => p.dailyNet != 0)
        .take(30)
        .toList();

    if (events.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Sem lançamentos futuros identificados.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ];
    }

    return events
        .map((point) => _EventTile(point: point, cs: cs, tt: tt))
        .toList();
  }
}

class _SummaryCard extends StatelessWidget {
  final CashFlowProjection projection;
  final ColorScheme cs;
  final TextTheme tt;

  const _SummaryCard({
    required this.projection,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo atual',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.formatCents(projection.currentBalance),
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: projection.currentBalance >= 0 ? cs.onSurface : cs.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Projeção baseada em transações futuras e parcelas não pagas',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizonCard extends StatelessWidget {
  final int days;
  final int amount;
  final int baseline;
  final ColorScheme cs;
  final TextTheme tt;

  const _HorizonCard({
    required this.days,
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
      child: Card(
        color: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$days dias',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.formatCents(amount),
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '+' : ''}${CurrencyFormatter.formatCents(delta)}',
                style: tt.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CashFlowProjectionPoint point;
  final ColorScheme cs;
  final TextTheme tt;

  const _EventTile({required this.point, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    final isPositive = point.dailyNet > 0;
    final color = isPositive ? const Color(0xFF4CAF50) : cs.error;
    final day = point.date.day.toString().padLeft(2, '0');
    final month = point.date.month.toString().padLeft(2, '0');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isPositive
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        '$day/$month',
        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Saldo: ${CurrencyFormatter.formatCents(point.cumulativeBalance)}',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}${CurrencyFormatter.formatCents(point.dailyNet)}',
        style: tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
