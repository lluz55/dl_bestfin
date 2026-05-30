import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class GetTransactions {
  final TransactionRepository repository;

  GetTransactions(this.repository);

  Stream<List<TransactionModel>> call({
    String? type,
    List<String>? accountIds,
    List<String>? creditCardIds,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (type == null &&
        (accountIds == null || accountIds.isEmpty) &&
        (creditCardIds == null || creditCardIds.isEmpty) &&
        categoryId == null &&
        startDate == null &&
        endDate == null) {
      return repository.watchAllTransactions();
    }
    return repository.watchTransactionsWithFilters(
      type: type,
      accountIds: accountIds,
      creditCardIds: creditCardIds,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
