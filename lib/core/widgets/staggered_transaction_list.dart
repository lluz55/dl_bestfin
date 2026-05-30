import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../extensions/context_extensions.dart';
import '../theme/typography.dart';
import 'amount_display.dart';

class TransactionItem {
  const TransactionItem({
    required this.title,
    required this.category,
    required this.amountInCents,
    required this.date,
    required this.icon,
  });

  final String title;
  final String category;
  final int amountInCents;
  final String date;
  final IconData icon;
}

class StaggeredTransactionList extends StatelessWidget {
  const StaggeredTransactionList({
    super.key,
    required this.items,
    this.onItemTap,
  });

  final List<TransactionItem> items;
  final void Function(TransactionItem)? onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          _TransactionTile(
            item: items[i],
            delay: context.motion.staggerInterval * i,
            onTap: onItemTap != null ? () => onItemTap!(items[i]) : null,
          ),
      ],
    );
  }
}

class _TransactionTile extends StatefulWidget {
  const _TransactionTile({required this.item, required this.delay, this.onTap});

  final TransactionItem item;
  final Duration delay;
  final VoidCallback? onTap;

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final motion = context.motion;
    final colors = context.customColors;

    final isNegative = widget.item.amountInCents < 0;
    final iconBg = isNegative
        ? colors.expense.withValues(alpha: 0.12)
        : colors.income.withValues(alpha: 0.12);
    final iconColor = isNegative ? colors.expense : colors.income;

    final tile = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: motion.fastDuration,
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: shapes.transactionTile,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: shapes.chip,
                ),
                child: Icon(widget.item.icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.item.category,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountDisplay(
                    amountInCents: widget.item.amountInCents,
                    style: tt.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.date,
                    style: AppTypography.monospace.copyWith(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return tile
        .animate(delay: widget.delay)
        .slideX(
          begin: 0.05,
          end: 0,
          curve: Curves.easeOutCubic,
          duration: context.motion.mediumDuration,
        )
        .fadeIn(duration: context.motion.fastDuration);
  }
}
