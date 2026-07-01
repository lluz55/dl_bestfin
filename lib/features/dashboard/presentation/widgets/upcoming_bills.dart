import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class UpcomingBills extends StatelessWidget {
  final List<TransactionModel> transactions;

  const UpcomingBills({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRÓXIMOS LANÇAMENTOS',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            _EmptyState(cs: cs, tt: tt)
          else
            Column(
              children: [
                for (int i = 0; i < transactions.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  _BillItem(tx: transactions[i], cs: cs, tt: tt),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sem lançamentos pendentes para este período.',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillItem extends StatelessWidget {
  final TransactionModel tx;
  final ColorScheme cs;
  final TextTheme tt;

  const _BillItem({required this.tx, required this.cs, required this.tt});

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return 'Vence em $day/$month';
  }

  String _formatAmount(int cents, TransactionType type) {
    final formatted = CurrencyFormatter.formatCents(cents);
    if (CurrencyFormatter.valuesHidden) return formatted;
    return type == TransactionType.income ? '+ $formatted' : '- $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final icon = tx.category?.iconData ?? Icons.receipt_long_outlined;
    final isIncome = tx.type == TransactionType.income;
    final amountColor = isIncome ? const Color(0xFF4CAF50) : cs.onSurface;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cs.onSurfaceVariant, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tx.description,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(tx.date),
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Text(
          _formatAmount(tx.amount, tx.type),
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
