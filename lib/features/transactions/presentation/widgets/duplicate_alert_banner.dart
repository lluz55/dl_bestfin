import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/ai/presentation/providers/duplicate_detector_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

class DuplicateAlertBanner extends ConsumerWidget {
  const DuplicateAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairs = ref.watch(duplicateDetectorProvider);
    if (pairs.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pair = pairs.first;
    final dup = pair.duplicate;
    final minutesAgo = DateTime.now().difference(dup.updatedAt).inMinutes;
    final timeLabel = minutesAgo < 1 ? 'agora' : '$minutesAgo min atrás';
    final amount =
        'R\$ ${(dup.amount / 100).toStringAsFixed(2).replaceAll('.', ',')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.content_copy_rounded,
                size: 16,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Possível duplicata detectada',
                  style: tt.labelMedium?.copyWith(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '"${CurrencyFormatter.sanitizeText(dup.description)}" $amount — registrado $timeLabel',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => dismissDuplicate(ref, dup.id),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Manter ambos'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () async {
                  try {
                    await ref.read(deleteTransactionProvider)(dup.id);
                  } catch (_) {}
                  dismissDuplicate(ref, dup.id);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.withValues(alpha: 0.2),
                  foregroundColor: Colors.amber.shade900,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Remover duplicata'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
