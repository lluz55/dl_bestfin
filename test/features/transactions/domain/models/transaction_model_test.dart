import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/constants/transaction_status.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

TransactionModel _buildTransaction({required bool isCompleted}) {
  final now = DateTime.now();
  return TransactionModel(
    id: 'tx-1',
    date: now,
    description: 'Test',
    type: TransactionType.expense,
    isCompleted: isCompleted,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('TransactionStatus.fromFlags', () {
    test('returns completed when isCompleted is true', () {
      expect(
        TransactionStatus.fromFlags(isCompleted: true),
        TransactionStatus.completed,
      );
    });

    test('returns pending when isCompleted is false', () {
      expect(
        TransactionStatus.fromFlags(isCompleted: false),
        TransactionStatus.pending,
      );
    });
  });

  group('TransactionModel.status / isPending', () {
    test('a completed transaction is not pending', () {
      final tx = _buildTransaction(isCompleted: true);
      expect(tx.status, TransactionStatus.completed);
      expect(tx.isPending, isFalse);
    });

    test('a future/incomplete transaction is pending', () {
      final tx = _buildTransaction(isCompleted: false);
      expect(tx.status, TransactionStatus.pending);
      expect(tx.isPending, isTrue);
    });
  });
}
