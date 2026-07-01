import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/ai/presentation/providers/recurring_discovery_provider.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_form_modal_provider.dart';

class RecurringDiscoveryBanner extends ConsumerStatefulWidget {
  const RecurringDiscoveryBanner({super.key});

  @override
  ConsumerState<RecurringDiscoveryBanner> createState() =>
      _RecurringDiscoveryBannerState();
}

class _RecurringDiscoveryBannerState
    extends ConsumerState<RecurringDiscoveryBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(recurringDiscoveryProvider);
    if (drafts.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: cs.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Detectamos ${drafts.length} padrão${drafts.length > 1 ? 'ões' : ''} recorrente${drafts.length > 1 ? 's' : ''}',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: cs.onSecondaryContainer.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, thickness: 0.5),
            ...drafts.map(
              (draft) => _DraftItem(
                draft: draft,
                onIgnore: () => dismissRecurringDraft(
                  ref,
                  draft.description,
                  draft.inferredFrequency,
                ),
                onCreate: () {
                  ref
                      .read(recurringFormModalProvider.notifier)
                      .open(
                        prefillData: {
                          'description': draft.description,
                          'amountInCents': draft.amountInCents,
                          'categoryId': draft.categoryId,
                          'categoryName': draft.categoryName,
                        },
                      );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DraftItem extends StatelessWidget {
  final RecurringDraftRule draft;
  final VoidCallback onIgnore;
  final VoidCallback onCreate;

  const _DraftItem({
    required this.draft,
    required this.onIgnore,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final amount =
        'R\$ ${(draft.amountInCents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.sanitizeText(draft.description),
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$amount · ${draft.inferredFrequency.label}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onIgnore,
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Ignorar'),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Criar regra'),
          ),
        ],
      ),
    );
  }
}
