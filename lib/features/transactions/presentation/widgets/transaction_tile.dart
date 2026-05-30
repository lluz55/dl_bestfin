import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
    this.onClone,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;
  final Future<void> Function()? onDelete;
  final VoidCallback? onClone;

  Account? _findAccount(List<Account> accounts, String? id) {
    if (id == null) return null;
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;
    final shapes = context.shapes;

    final accounts = ref.watch(activeAccountsProvider);

    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final isCreditCard = transaction.creditCardId != null;

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

    // ── Icon widget ─────────────────────────────────────────────────────────
    Widget iconWidget;
    if (isTransfer) {
      iconWidget = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.transfer.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.swap_horiz_rounded, color: colors.transfer, size: 20),
      );
    } else {
      Widget baseIcon;
      if (transaction.category != null) {
        final cat = transaction.category!;
        // Look up the enriched category from the tree to get parent info
        final allCategories = ref.watch(allFlatCategoriesProvider);
        final enrichedCat =
            allCategories.where((c) => c.id == cat.id).firstOrNull ?? cat;
        baseIcon = CategoryIcon(
          icon: enrichedCat.icon,
          color: enrichedCat.color,
          parentIcon: enrichedCat.parentIcon,
          parentColor: enrichedCat.parentColor,
          size: 44,
        );
      } else {
        baseIcon = Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
        );
      }

      if (isCreditCard) {
        // Overlay small credit card badge
        iconWidget = SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              baseIcon,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.credit_card_rounded,
                      size: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        iconWidget = baseIcon;
      }
    }

    // ── Subtitle line ────────────────────────────────────────────────────────
    Widget subtitleWidget;
    if (isTransfer) {
      subtitleWidget = Row(
        children: [
          Text(
            DateFormatter.formatRelativeDate(transaction.date),
            style: AppTypography.monospace.copyWith(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    } else {
      subtitleWidget = Row(
        children: [
          if (transaction.entity != null) ...[
            Text(
              transaction.entity!.name,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            DateFormatter.formatRelativeDate(transaction.date),
            style: AppTypography.monospace.copyWith(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    // ── Card tile ────────────────────────────────────────────────────────────
    Widget tile = Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: shapes.transactionTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: shapes.transactionTile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isTransfer
                                ? (() {
                                    final fromAccount = _findAccount(
                                      accounts,
                                      transaction.fromAccountId,
                                    );
                                    final toAccount = _findAccount(
                                      accounts,
                                      transaction.toAccountId,
                                    );
                                    final fromName = fromAccount?.name ?? '—';
                                    final toName = toAccount?.name ?? '—';
                                    return '$fromName → $toName';
                                  })()
                                : transaction.description,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (transaction.sentiment != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            transaction.sentiment!.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    subtitleWidget,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$sign${CurrencyFormatter.formatCents(transaction.amount)}',
                style: tt.titleSmall?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // ── Swipe actions ────────────────────────────────────────────────────────
    final hasSwipe = onClone != null || onDelete != null;
    if (!hasSwipe) return tile;

    final swipeDirection = (onClone != null && onDelete != null)
        ? DismissDirection.horizontal
        : onClone != null
        ? DismissDirection.startToEnd
        : DismissDirection.endToStart;

    return Dismissible(
      key: Key(transaction.id),
      direction: swipeDirection,
      // Left-to-right: clone (blue)
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: shapes.transactionTile,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, color: cs.onPrimaryContainer),
            const SizedBox(width: 6),
            Text(
              'Duplicar',
              style: tt.labelMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      // Right-to-left: delete (red)
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: shapes.transactionTile,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Apagar',
              style: tt.labelMedium?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.delete_rounded, color: cs.onErrorContainer),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onClone?.call();
        } else {
          await onDelete?.call();
        }
        return false;
      },
      child: tile,
    );
  }
}
