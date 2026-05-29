import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:intl/intl.dart';

/// Card de uma regra de recorrência na lista.
class RecurringCard extends StatelessWidget {
  final RecurringRuleModel rule;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const RecurringCard({
    super.key,
    required this.rule,
    this.onPause,
    this.onResume,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dateFormat = DateFormat('dd/MM/yyyy');

    final isExpense = rule.type == 'expense';
    final amountColor = isExpense ? _expenseColor(cs) : _incomeColor(cs);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícone de categoria
              if (rule.categoryIcon != null && rule.categoryColor != null)
                CategoryIcon(
                  icon: rule.categoryIcon!,
                  color: rule.categoryColor!,
                  size: 48,
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.repeat_rounded,
                    color: cs.onSurfaceVariant,
                    size: 24,
                  ),
                ),

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
                            rule.description ?? 'Sem descrição',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusBadge(status: rule.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 13,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rule.frequency.label,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (rule.status == RecurringStatus.active) ...[
                          const SizedBox(width: 8),
                          Text(
                            '·',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(rule.nextDate),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (rule.categoryName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        rule.categoryName!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Valor e menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (rule.amountInCents != null)
                    Text(
                      CurrencyFormatter.formatCents(rule.amountInCents!),
                      style: tt.titleSmall?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    rule.frequency.shortLabel,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  _ActionMenu(
                    rule: rule,
                    onPause: onPause,
                    onResume: onResume,
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

  Color _expenseColor(ColorScheme cs) {
    return const Color(0xFFE53935);
  }

  Color _incomeColor(ColorScheme cs) {
    return const Color(0xFF43A047);
  }
}

class _StatusBadge extends StatelessWidget {
  final RecurringStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case RecurringStatus.active:
        bg = const Color(0xFF43A047).withValues(alpha: 0.12);
        fg = const Color(0xFF43A047);
        icon = Icons.check_circle_outline_rounded;
      case RecurringStatus.paused:
        bg = cs.tertiary.withValues(alpha: 0.12);
        fg = cs.tertiary;
        icon = Icons.pause_circle_outline_rounded;
      case RecurringStatus.finished:
        bg = cs.onSurfaceVariant.withValues(alpha: 0.1);
        fg = cs.onSurfaceVariant;
        icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  final RecurringRuleModel rule;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;

  const _ActionMenu({
    required this.rule,
    this.onPause,
    this.onResume,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: cs.onSurfaceVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        if (rule.status == RecurringStatus.active)
          PopupMenuItem(
            value: 'pause',
            child: Row(
              children: [
                Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 18,
                  color: cs.tertiary,
                ),
                const SizedBox(width: 12),
                const Text('Pausar'),
              ],
            ),
          ),
        if (rule.status == RecurringStatus.paused)
          PopupMenuItem(
            value: 'resume',
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: 18,
                  color: const Color(0xFF43A047),
                ),
                const SizedBox(width: 12),
                const Text('Retomar'),
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
          case 'pause':
            onPause?.call();
          case 'resume':
            onResume?.call();
          case 'delete':
            onDelete?.call();
        }
      },
    );
  }
}
