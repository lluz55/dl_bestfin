import 'package:flutter/material.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_group.dart';

/// Exibe um bloco de lançamentos agrupados como um único item de lista,
/// revelando apenas o valor total. O comportamento agrupado é destacado apenas
/// pelo selo de itens e pelo ícone de pilha (sem borda). Tocar abre a edição
/// do bloco.
class GroupedTransactionTile extends StatelessWidget {
  const GroupedTransactionTile({
    super.key,
    required this.group,
    this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final TransactionGroup group;
  final VoidCallback? onTap;

  /// Long-press para entrar no modo de seleção em massa (seleciona o bloco
  /// inteiro — todos os membros do grupo).
  final VoidCallback? onLongPress;

  /// Quando true, o bloco exibe um indicador de seleção.
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;
    final shapes = context.shapes;

    final isIncome = group.type == TransactionType.income;
    final isTransfer = group.type == TransactionType.transfer;
    final amountColor = isIncome
        ? colors.income
        : isTransfer
        ? colors.transfer
        : colors.expense;
    final sign = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '-';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      color: selected ? cs.secondaryContainer : cs.surfaceContainer,
      // Sem borda de destaque: o selo de itens e o ícone de pilha já
      // diferenciam o bloco de um lançamento comum.
      shape: RoundedRectangleBorder(borderRadius: shapes.transactionTile),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: shapes.transactionTile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],
              // Ícone de pilha indica agregação de vários lançamentos.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.layers_rounded, color: amountColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.title,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _GroupBadge(color: amountColor, count: group.count),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.formatRelativeDate(group.date),
                      style: AppTypography.monospace.copyWith(
                        fontSize: 10,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${CurrencyFormatter.formatCents(group.total)}',
                    style: tt.titleSmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'total',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_rounded, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '$count itens',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
