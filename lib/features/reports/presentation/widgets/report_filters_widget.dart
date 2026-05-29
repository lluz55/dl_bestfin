import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';

class ReportFiltersWidget extends ConsumerWidget {
  const ReportFiltersWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reportFiltersProvider);
    final notifier = ref.read(reportFiltersProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _PeriodChip(
            label: 'Mês',
            selected: filters.period == ReportPeriod.month,
            onTap: () =>
                notifier.update((f) => f.copyWith(period: ReportPeriod.month)),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: 'Trimestre',
            selected: filters.period == ReportPeriod.quarter,
            onTap: () => notifier.update(
              (f) => f.copyWith(period: ReportPeriod.quarter),
            ),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: 'Ano',
            selected: filters.period == ReportPeriod.year,
            onTap: () =>
                notifier.update((f) => f.copyWith(period: ReportPeriod.year)),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: 'Personalizado',
            selected: filters.period == ReportPeriod.custom,
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 3),
                lastDate: now,
                initialDateRange: DateTimeRange(
                  start:
                      filters.customStart ?? DateTime(now.year, now.month, 1),
                  end: filters.customEnd ?? now,
                ),
                builder: (context, child) =>
                    Theme(data: Theme.of(context), child: child!),
              );
              if (picked != null) {
                notifier.update(
                  (f) => f.copyWith(
                    period: ReportPeriod.custom,
                    customStart: picked.start,
                    customEnd: picked.end,
                  ),
                );
              }
            },
          ),
          if (filters.type != null || filters.accountId != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
              label: const Text('Limpar filtros'),
              onPressed: () => notifier.update(
                (f) => f.copyWith(
                  clearAccount: true,
                  clearType: true,
                  clearCategory: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
