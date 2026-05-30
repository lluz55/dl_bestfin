import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';

class UpdateTransaction {
  final TransactionRepository repository;

  UpdateTransaction(this.repository);

  Future<void> call({
    required String id,
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
  }) {
    return repository.updateTransaction(
      id: id,
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
    );
  }
}
