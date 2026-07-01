import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/quick_suggestion.dart';
import 'package:bestfin/features/transactions/domain/usecases/get_quick_suggestions.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

/// Sugestões de "Lançamento Rápido" para um tipo de transação, ranqueadas pelo
/// recomendador estatístico ([rankQuickSuggestions]) a partir do histórico
/// recente. Recalcula automaticamente quando novas transações são criadas.
final quickSuggestionsProvider =
    StreamProvider.family<List<QuickSuggestion>, TransactionType>((ref, type) {
      final getTransactions = ref.watch(getTransactionsProvider);
      final since = DateTime.now().subtract(const Duration(days: 180));

      return getTransactions(type: type.name, startDate: since).map((txs) {
        return rankQuickSuggestions(txs, now: DateTime.now(), typeFilter: type);
      });
    });
