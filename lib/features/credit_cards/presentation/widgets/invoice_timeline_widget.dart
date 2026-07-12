import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/features/credit_cards/domain/models/invoice.dart';
import 'package:go_router/go_router.dart';

class InvoiceTimelineWidget extends StatelessWidget {
  final List<InvoiceModel> invoices;
  final String cardId;

  const InvoiceTimelineWidget({
    super.key,
    required this.invoices,
    required this.cardId,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Nenhuma fatura encontrada para este cartão.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.6,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final isFirst = index == 0;
        final isLast = index == invoices.length - 1;

        return _TimelineTile(
          invoice: invoice,
          cardId: cardId,
          isFirst: isFirst,
          isLast: isLast,
        );
      },
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final InvoiceModel invoice;
  final String cardId;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({
    required this.invoice,
    required this.cardId,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;

    Color statusColor;
    IconData statusIcon;

    switch (invoice.status) {
      case 'paid':
        statusColor = colors.income; // Green
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'closed':
        statusColor = colors.warning;
        statusIcon = Icons.lock_rounded;
        break;
      case 'open':
      default:
        statusColor = cs.primary; // Blue
        statusIcon = Icons.play_circle_fill_rounded;
        break;
    }

    final double amount = invoice.totalAmount / 100.0;
    final formattedAmount =
        'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

    final dueDay = invoice.dueDate.day.toString().padLeft(2, '0');
    final dueMonth = invoice.dueDate.month.toString().padLeft(2, '0');
    final formattedDue = '$dueDay/$dueMonth';

    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline Line & Icon
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                onTap: () => context.push(
                  '/credit-cards/$cardId/invoices/${invoice.id}',
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${invoice.monthName} de ${invoice.year}',
                              style: tt.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    invoice.statusLabel.toUpperCase(),
                                    style: tt.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 12,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Vence $formattedDue',
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formattedAmount,
                            style: tt.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                )
                                .merge(AppTypography.monospace),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
