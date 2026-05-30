import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/presentation/widgets/progress_ring_widget.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:intl/intl.dart';

/// Card de um objetivo financeiro com progress ring mini.
class GoalCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback? onTap;
  final VoidCallback? onContribute;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
    this.onContribute,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final goalColor = _parseColor(goal.color, cs.primary);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone do objetivo
              _GoalIcon(goal: goal, color: goalColor),
              const SizedBox(width: 14),

              // Conteúdo principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (goal.status == GoalStatus.completed)
                          _Badge(
                            label: 'Concluído',
                            color: const Color(0xFF43A047),
                            icon: Icons.check_circle_rounded,
                          )
                        else if (goal.type == GoalType.spending &&
                            goal.currentAmountInCents >
                                goal.targetAmountInCents)
                          _Badge(
                            label: 'Excedido',
                            color: cs.error,
                            icon: Icons.warning_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Valor atual / meta
                    RichText(
                      text: TextSpan(
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                            text: CurrencyFormatter.formatCents(
                              goal.currentAmountInCents,
                            ),
                            style: TextStyle(
                              color: goalColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: goal.type == GoalType.saving
                                ? ' de '
                                : ' gastos de ',
                          ),
                          TextSpan(
                            text: CurrencyFormatter.formatCents(
                              goal.targetAmountInCents,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Barra de progresso linear (complemento visual)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: goal.progressFraction.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: cs.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Prazo / recorrência / categorias
                    Row(
                      children: [
                        if (goal.isRecurring) ...[
                          Icon(
                            Icons.repeat_rounded,
                            size: 11,
                            color: goalColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            goal.recurrenceFrequency?.label ?? 'Recorrente',
                            style: tt.labelSmall?.copyWith(color: goalColor),
                          ),
                          const SizedBox(width: 8),
                        ] else if (goal.targetDate != null) ...[
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(goal.targetDate!),
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!goal.isRecurring &&
                            goal.monthlyTargetInCents != null &&
                            !goal.isCompleted) ...[
                          Icon(
                            Icons.trending_up_rounded,
                            size: 11,
                            color: goalColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${CurrencyFormatter.formatCents(goal.monthlyTargetInCents!)}/mês',
                            style: tt.labelSmall?.copyWith(color: goalColor),
                          ),
                        ],
                        if (goal.categoryIds.isNotEmpty) ...[
                          const Spacer(),
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Auto',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Progress ring mini + menu
              Column(
                children: [
                  ProgressRingWidget(
                    progress: goal.progressFraction,
                    size: 64,
                    strokeWidth: 7,
                    color: goalColor,
                  ),
                  const SizedBox(height: 4),
                  _ActionMenu(
                    goal: goal,
                    onContribute: onContribute,
                    onArchive: onArchive,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

class _GoalIcon extends StatelessWidget {
  final GoalModel goal;
  final Color color;

  const _GoalIcon({required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final iconData = goal.icon != null
        ? IconMapper.fromString(goal.icon!)
        : Icons.flag_rounded;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback? onContribute;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const _ActionMenu({
    required this.goal,
    this.onContribute,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (ctx) => [
        if (!goal.isCompleted)
          PopupMenuItem(
            value: 'contribute',
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: 12),
                const Text('Contribuir'),
              ],
            ),
          ),
        if (goal.status == GoalStatus.active)
          PopupMenuItem(
            value: 'archive',
            child: Row(
              children: [
                Icon(Icons.archive_outlined, size: 18, color: cs.tertiary),
                const SizedBox(width: 12),
                const Text('Arquivar'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
              const SizedBox(width: 12),
              Text('Excluir', style: TextStyle(color: cs.error)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'contribute':
            onContribute?.call();
          case 'archive':
            onArchive?.call();
          case 'delete':
            onDelete?.call();
        }
      },
    );
  }
}
