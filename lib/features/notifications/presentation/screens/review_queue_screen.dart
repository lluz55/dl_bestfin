import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bestfin/features/notifications/presentation/widgets/suggestion_card.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final suggestionsAsync = ref.watch(suggestedTransactionsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Sugestões',
        actions: [
          suggestionsAsync.when(
            data: (list) => list.isNotEmpty
                ? TextButton(
                    onPressed: () => _confirmAll(context, ref, list),
                    child: const Text('Confirmar todas'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          suggestionsAsync.when(
            data: (suggestions) {
              if (suggestions.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(cs: cs, tt: tt),
                );
              }

              // Group by date
              final grouped = _groupByDay(suggestions);
              final days = grouped.keys.toList();

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final day = days[index];
                  final items = grouped[day]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          _formatDay(day),
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...items.map((s) => SuggestionCard(suggestion: s)),
                    ],
                  );
                }, childCount: days.length),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: AppLoadingIndicator()),
            ),
            error: (err, _) =>
                SliverFillRemaining(child: Center(child: Text('Erro: $err'))),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Map<DateTime, List<TransactionModel>> _groupByDay(
    List<TransactionModel> list,
  ) {
    final map = <DateTime, List<TransactionModel>>{};
    for (final tx in list) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      map.putIfAbsent(day, () => []).add(tx);
    }
    return map;
  }

  String _formatDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (day == today) return 'Hoje';
    if (day == yesterday) return 'Ontem';
    return DateFormat('EEEE, d MMM', 'pt_BR').format(day);
  }

  Future<void> _confirmAll(
    BuildContext context,
    WidgetRef ref,
    List<TransactionModel> suggestions,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar todas?'),
        content: Text('${suggestions.length} transações serão confirmadas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final confirmAction = ref.read(confirmSuggestionProvider);
      for (final s in suggestions) {
        await confirmAction(s.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${suggestions.length} transações confirmadas'),
          ),
        );
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'Nenhuma sugestão pendente',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Transações capturadas de notificações bancárias aparecerão aqui para você revisar.',
              style: tt.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
