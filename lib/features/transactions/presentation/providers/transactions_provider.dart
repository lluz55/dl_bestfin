import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_delete_context.dart';
import 'package:bestfin/features/transactions/domain/usecases/create_transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/update_transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/delete_transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/get_transactions.dart';

// Repository
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return TransactionRepositoryImpl(database);
});

// Use cases
final createTransactionProvider = Provider<CreateTransaction>((ref) {
  return CreateTransaction(ref.watch(transactionRepositoryProvider));
});

final updateTransactionProvider = Provider<UpdateTransaction>((ref) {
  return UpdateTransaction(ref.watch(transactionRepositoryProvider));
});

final deleteTransactionProvider = Provider<DeleteTransaction>((ref) {
  return DeleteTransaction(ref.watch(transactionRepositoryProvider));
});

final markTransactionAsPaidProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return ref.watch(transactionRepositoryProvider).markAsPaid;
});

final getTransactionsProvider = Provider<GetTransactions>((ref) {
  return GetTransactions(ref.watch(transactionRepositoryProvider));
});

// Filtros de busca
class TransactionFilters {
  final String? type;
  final List<String> accountIds;
  final List<String> creditCardIds;
  final String? categoryId;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilters({
    this.type,
    this.accountIds = const [],
    this.creditCardIds = const [],
    this.categoryId,
    this.startDate,
    this.endDate,
  });

  TransactionFilters copyWith({
    String? type,
    List<String>? accountIds,
    List<String>? creditCardIds,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool clearType = false,
    bool clearAccounts = false,
    bool clearCreditCards = false,
    bool clearCategory = false,
    bool clearDate = false,
  }) {
    return TransactionFilters(
      type: clearType ? null : (type ?? this.type),
      accountIds: clearAccounts ? const [] : (accountIds ?? this.accountIds),
      creditCardIds: clearCreditCards
          ? const []
          : (creditCardIds ?? this.creditCardIds),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      startDate: clearDate ? null : (startDate ?? this.startDate),
      endDate: clearDate ? null : (endDate ?? this.endDate),
    );
  }

  bool get isEmpty =>
      type == null &&
      accountIds.isEmpty &&
      creditCardIds.isEmpty &&
      categoryId == null &&
      startDate == null &&
      endDate == null;
}

class TransactionFiltersNotifier extends Notifier<TransactionFilters> {
  @override
  TransactionFilters build() {
    return const TransactionFilters();
  }

  void update(TransactionFilters Function(TransactionFilters) cb) {
    state = cb(state);
  }

  @override
  set state(TransactionFilters value) {
    super.state = value;
  }
}

final transactionFiltersProvider =
    NotifierProvider<TransactionFiltersNotifier, TransactionFilters>(() {
      return TransactionFiltersNotifier();
    });

// Stream das transações com base no filtro atual
final filteredTransactionsProvider = StreamProvider<List<TransactionModel>>((
  ref,
) {
  final getTransactions = ref.watch(getTransactionsProvider);
  final filters = ref.watch(transactionFiltersProvider);

  return getTransactions(
    type: filters.type,
    accountIds: filters.accountIds,
    creditCardIds: filters.creditCardIds,
    categoryId: filters.categoryId,
    startDate: filters.startDate,
    endDate: filters.endDate,
  );
});

final transactionDeleteContextProvider =
    FutureProvider.family<TransactionDeleteContext, String>((ref, txId) {
      return ref.watch(transactionRepositoryProvider).getDeleteContext(txId);
    });

final deleteInstallmentSingleProvider = Provider<Future<void> Function(String)>(
  (ref) {
    return ref.watch(transactionRepositoryProvider).deleteInstallmentSingle;
  },
);

final deleteInstallmentFromHereProvider =
    Provider<Future<void> Function(String, String)>((ref) {
      return ref.watch(transactionRepositoryProvider).deleteInstallmentFromHere;
    });

final deleteInstallmentAllProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return ref.watch(transactionRepositoryProvider).deleteInstallmentAll;
});

final deleteRecurringBaseAndFutureProvider =
    Provider<Future<void> Function(String, String)>((ref) {
      return ref
          .watch(transactionRepositoryProvider)
          .deleteRecurringBaseAndFuture;
    });

final deleteRecurringBaseAndAllProvider =
    Provider<Future<void> Function(String, String)>((ref) {
      return ref.watch(transactionRepositoryProvider).deleteRecurringBaseAndAll;
    });

final deleteRecurringCloneAndFutureProvider =
    Provider<Future<void> Function(String, String, DateTime)>((ref) {
      return ref
          .watch(transactionRepositoryProvider)
          .deleteRecurringCloneAndFuture;
    });

// autoDispose: a chave inclui o texto digitado, então sem isso cada tecla
// deixaria uma entrada de cache presa na árvore de providers para sempre.
final recentDescriptionsProvider = FutureProvider.autoDispose
    .family<List<String>, ({String query, String? type})>((ref, params) async {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.getRecentDescriptions(
        query: params.query,
        type: params.type,
      );
    });
