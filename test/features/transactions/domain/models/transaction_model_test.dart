import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/constants/transaction_status.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';

TransactionModel _buildTransaction({
  required bool isCompleted,
  required DateTime date,
}) {
  final now = DateTime.now();
  return TransactionModel(
    id: 'tx-1',
    date: date,
    description: 'Test',
    type: TransactionType.expense,
    isCompleted: isCompleted,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  final nextWeek = now.add(const Duration(days: 7));

  group('TransactionStatus.fromFlags', () {
    test('returns completed when isCompleted is true regardless of date', () {
      expect(
        TransactionStatus.fromFlags(isCompleted: true, date: yesterday),
        TransactionStatus.completed,
      );
    });

    test('returns pending when isCompleted is false and date is today/past', () {
      expect(
        TransactionStatus.fromFlags(isCompleted: false, date: now),
        TransactionStatus.pending,
      );
      expect(
        TransactionStatus.fromFlags(isCompleted: false, date: yesterday),
        TransactionStatus.pending,
      );
    });

    test(
      'returns scheduled when isCompleted is false and date is in the future',
      () {
        expect(
          TransactionStatus.fromFlags(isCompleted: false, date: nextWeek),
          TransactionStatus.scheduled,
        );
      },
    );
  });

  group('TransactionModel.status / isPending / isScheduled / isOverdue', () {
    test('a completed transaction is not pending', () {
      final tx = _buildTransaction(isCompleted: true, date: now);
      expect(tx.status, TransactionStatus.completed);
      expect(tx.isPending, isFalse);
      expect(tx.isScheduled, isFalse);
      expect(tx.isOverdue, isFalse);
    });

    test('a past/incomplete transaction is pending and overdue', () {
      final tx = _buildTransaction(isCompleted: false, date: yesterday);
      expect(tx.status, TransactionStatus.pending);
      expect(tx.isPending, isTrue);
      expect(tx.isOverdue, isTrue);
      expect(tx.isScheduled, isFalse);
    });

    test('a future/incomplete transaction is pending and scheduled', () {
      final tx = _buildTransaction(isCompleted: false, date: nextWeek);
      expect(tx.status, TransactionStatus.scheduled);
      expect(tx.isPending, isTrue);
      expect(tx.isScheduled, isTrue);
      expect(tx.isOverdue, isFalse);
    });
  });
}
