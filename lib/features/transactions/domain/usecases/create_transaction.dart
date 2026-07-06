import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/split_entry.dart';

class CreateTransaction {
  final TransactionRepository repository;

  CreateTransaction(this.repository);

  Future<String> call({
    required DateTime date,
    required String description,
    required String type,
    required int amount,
    String? categoryId,
    String? entityId,
    required String accountId,
    String? toAccountId,
    String? sentiment,
    String? notes,
    String? goalId,
    String? creditCardId,
    List<SplitEntry>? splits,
    bool isCompleted = true,
  }) {
    return repository.createTransaction(
      date: date,
      description: description,
      type: type,
      amount: amount,
      categoryId: categoryId,
      entityId: entityId,
      accountId: accountId,
      toAccountId: toAccountId,
      sentiment: sentiment,
      notes: notes,
      goalId: goalId,
      creditCardId: creditCardId,
      splits: splits,
      isCompleted: isCompleted,
    );
  }
}
