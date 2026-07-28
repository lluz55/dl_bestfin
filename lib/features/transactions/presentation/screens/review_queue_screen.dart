import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/suggestion_card.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen> {
  TransactionModel? _selectedTransaction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isExpanded = Breakpoints.isExpanded(context);
    final suggestionsAsync = ref.watch(suggestedTransactionsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Sugestões',
        infoDescription: 'Revise as transações geradas automaticamente por recorrências sem confirmação automática. Confirme, edite ou descarte cada sugestão antes de importá-las.',
        infoFeatures: const [
          'Geradas por recorrências sem auto-confirmação',
          'Confirmação individual ou em lote',
          'Edição antes de importar',
        ],
        actions: [
          suggestionsAsync.when(
            data: (list) => list.isNotEmpty
                ? TextButton(
                    onPressed: () => _confirmAll(context, ref, list),
                    child: const Text('Confirmar todas'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: suggestionsAsync.when(
        data: (suggestions) {
          if (suggestions.isEmpty) {
            return _EmptyState(cs: cs, tt: tt);
          }

          if (isExpanded && suggestions.length > 1) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 380,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final tx = suggestions[index];
                      return _TransactionListTile(
                        transaction: tx,
                        isSelected: tx.id == _selectedTransaction?.id,
                        onTap: () {
                          setState(() => _selectedTransaction = tx);
                        },
                        cs: cs,
                        tt: tt,
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 0.5),
                Expanded(
                  child: _selectedTransaction == null
                      ? Center(
                          child: Text(
                            'Selecione uma transação',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: SuggestionCard(suggestion: _selectedTransaction!),
                        ),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              suggestionsAsync.when(
                data: (suggestions) {
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
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
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
            Icon(Icons.pending_actions_rounded, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'Nenhuma sugestão pendente',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Transações de recorrências sem auto-confirmação aparecerão aqui para você revisar.',
              style: tt.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionListTile extends StatelessWidget {
  const _TransactionListTile({
    required this.transaction,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final TransactionModel transaction;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final amount = transaction.amount;
    final isPositive = amount >= 0;

    return ListTile(
      selected: isSelected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.4),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (isPositive ? context.customColors.income : cs.error)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isPositive
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          color: isPositive ? context.customColors.income : cs.error,
          size: 20,
        ),
      ),
      title: Text(
        transaction.description,
        style: tt.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        'R\$ ${(amount.abs() / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
        style: tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isPositive ? context.customColors.income : cs.error,
        ),
      ),
    );
  }
}