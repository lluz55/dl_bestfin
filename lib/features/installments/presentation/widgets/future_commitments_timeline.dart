import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/installments/domain/models/installment_plan.dart';

class FutureCommitmentsTimeline extends StatelessWidget {
  final List<InstallmentPlanModel> plans;

  const FutureCommitmentsTimeline({super.key, required this.plans});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    // Build a map of month-year -> List of (description, amount, isPaid)
    final commitments = <String, List<Map<String, dynamic>>>{};

    for (final plan in plans) {
      for (final tx in plan.transactions) {
        if (tx.isCompleted) continue;
        final key =
            '${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}';
        commitments.putIfAbsent(key, () => []);
        commitments[key]!.add({
          'description': tx.description,
          'amount': tx.amount,
        });
      }
    }

    if (commitments.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedKeys = commitments.keys.toList()
      ..sort((a, b) {
        final partsA = a.split('/').map(int.parse).toList();
        final partsB = b.split('/').map(int.parse).toList();
        final dtA = DateTime(partsA[1], partsA[0]);
        final dtB = DateTime(partsB[1], partsB[0]);
        return dtA.compareTo(dtB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compromissos Futuros',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...sortedKeys.map((key) {
          final items = commitments[key]!;
          final total = items.fold<int>(0, (s, i) => s + (i['amount'] as int));

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        key,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCents(total),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['description'] as String,
                              style: tt.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatCents(
                              item['amount'] as int,
                            ),
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
