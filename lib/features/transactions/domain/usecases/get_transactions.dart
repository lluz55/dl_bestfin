import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

class GetTransactions {
  final TransactionRepository repository;

  GetTransactions(this.repository);

  Stream<List<TransactionModel>> call({
    String? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (type == null &&
        accountId == null &&
        categoryId == null &&
        startDate == null &&
        endDate == null) {
      return repository.watchAllTransactions();
    }
    return repository.watchTransactionsWithFilters(
      type: type,
      accountId: accountId,
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
