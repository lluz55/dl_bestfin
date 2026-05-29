import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class SuggestionCard extends ConsumerWidget {
  final TransactionModel suggestion;

  const SuggestionCard({super.key, required this.suggestion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final amount = CurrencyFormatter.formatCents(suggestion.amount);
    final date = DateFormat('dd/MM HH:mm').format(suggestion.date);
    final merchant = suggestion.description;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_rounded,
                    size: 20,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        date,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _discard(context, ref),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Descartar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurfaceVariant,
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirm(context, ref),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirm(BuildContext context, WidgetRef ref) async {
    await ref.read(confirmSuggestionProvider)(suggestion.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transação confirmada')));
    }
  }

  void _discard(BuildContext context, WidgetRef ref) async {
    await ref.read(discardSuggestionProvider)(suggestion.id);
  }

  void _edit(BuildContext context) {
    context.push('/transaction/edit', extra: suggestion);
  }
}
