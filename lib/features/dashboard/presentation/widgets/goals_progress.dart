import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/presentation/providers/goal_form_modal_provider.dart';

class GoalsProgress extends StatelessWidget {
  final List<GoalModel> goals;

  const GoalsProgress({super.key, required this.goals});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      onTap: goals.isNotEmpty ? () => context.push('/goals') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'METAS E OBJETIVOS',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (goals.isNotEmpty)
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (goals.isEmpty)
            _EmptyState(cs: cs, tt: tt)
          else
            Column(
              children: [
                for (int i = 0; i < goals.length; i++) ...[
                  if (i > 0) const SizedBox(height: 20),
                  _GoalItem(goal: goals[i], cs: cs, tt: tt),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _EmptyState({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
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
              Icons.savings_outlined,
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
                  'Nenhum objetivo ativo.',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vamos começar a poupar?',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: Breakpoints.isCompact(context)
                ? () => context.push('/goals/new')
                : () => ProviderScope.containerOf(
                    context,
                  ).read(goalFormModalProvider.notifier).open(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }
}

class _GoalItem extends StatelessWidget {
  final GoalModel goal;
  final ColorScheme cs;
  final TextTheme tt;

  const _GoalItem({required this.goal, required this.cs, required this.tt});

  static Color? _parseGoalColor(String? hex) {
    if (hex == null) return null;
    try {
      final clean = hex.replaceFirst('#', '');
      final withAlpha = clean.length == 6 ? 'ff$clean' : clean;
      return Color(int.parse(withAlpha, radix: 16));
    } catch (_) {
      return null;
    }
  }

  String _formatAmount(int cents) {
    return CurrencyFormatter.formatCents(cents);
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseGoalColor(goal.color) ?? cs.primary;
    final icon = goal.icon != null
        ? IconMapper.fromString(goal.icon!)
        : Icons.savings_outlined;
    final progress = goal.progressFraction.clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatAmount(goal.currentAmountInCents),
                    style: tt.labelMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: goal.isCompleted
                              ? const Color(0xFF4CAF50)
                              : cs.onSurface,
                        )
                        .merge(AppTypography.monospace),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%'
                    '${goal.isCompleted ? ' · Concluído' : ''}',
                    style: tt.labelSmall?.copyWith(
                      color: goal.isCompleted
                          ? const Color(0xFF4CAF50)
                          : cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontWeight: goal.isCompleted
                          ? FontWeight.w700
                          : FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'Meta: ${_formatAmount(goal.targetAmountInCents)}',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
