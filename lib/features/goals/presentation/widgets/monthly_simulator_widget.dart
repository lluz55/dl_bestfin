import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/goals/domain/usecases/calculate_monthly_target.dart';

/// Widget simulador mensal com slider de prazo e 3 cenários.
class MonthlySimulatorWidget extends StatefulWidget {
  final int remainingInCents;
  final int? initialMonths;

  const MonthlySimulatorWidget({
    super.key,
    required this.remainingInCents,
    this.initialMonths,
  });

  @override
  State<MonthlySimulatorWidget> createState() => _MonthlySimulatorWidgetState();
}

class _MonthlySimulatorWidgetState extends State<MonthlySimulatorWidget> {
  late double _months;
  final _calculator = CalculateMonthlyTarget();

  @override
  void initState() {
    super.initState();
    _months = (widget.initialMonths ?? 12).toDouble().clamp(1, 120);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sim = _calculator(
      remainingInCents: widget.remainingInCents,
      months: _months.round(),
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Simulador Mensal',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slider de prazo
          Row(
            children: [
              Text(
                'Prazo: ',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${_months.round()} ${_months.round() == 1 ? 'mês' : 'meses'}',
                style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _months,
            min: 1,
            max: 120,
            divisions: 119,
            onChanged: (v) => setState(() => _months = v),
          ),
          const SizedBox(height: 12),

          // 3 cenários
          Row(
            children: [
              Expanded(
                child: _ScenarioCard(
                  label: 'Otimista',
                  subtitle: 'Reserva a mais',
                  amountInCents: sim.optimisticInCents,
                  color: cs.primary,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScenarioCard(
                  label: 'Ideal',
                  subtitle: 'Exato no prazo',
                  amountInCents: sim.idealInCents,
                  color: cs.primary,
                  icon: Icons.check_circle_outline_rounded,
                  highlighted: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScenarioCard(
                  label: 'Pessimista',
                  subtitle: 'Pode atrasar',
                  amountInCents: sim.pessimisticInCents,
                  color: cs.error,
                  icon: Icons.trending_down_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final int amountInCents;
  final Color color;
  final IconData icon;
  final bool highlighted;

  const _ScenarioCard({
    required this.label,
    required this.subtitle,
    required this.amountInCents,
    required this.color,
    required this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.1)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatCents(amountInCents),
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
