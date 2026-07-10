import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_group.dart';
import 'package:bestfin/features/transactions/domain/usecases/collapse_transaction_groups.dart';

TransactionModel tx(String id, {String? groupId, int amount = 1000}) {
  final now = DateTime(2026, 7, 9);
  return TransactionModel(
    id: id,
    date: now,
    description: id,
    type: TransactionType.expense,
    groupId: groupId,
    rawAmount: amount,
    isCompleted: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('ungrouped transactions pass through unchanged', () {
    final list = [tx('a'), tx('b')];
    final result = collapseTransactionGroups(list);
    expect(result, hasLength(2));
    expect(result.every((e) => e is TransactionModel), isTrue);
  });

  test('members sharing a groupId collapse into one TransactionGroup', () {
    final list = [
      tx('a', groupId: 'g1', amount: 1000),
      tx('b', groupId: 'g1', amount: 2500),
      tx('c'),
    ];
    final result = collapseTransactionGroups(list);

    expect(result, hasLength(2));
    final group = result.first as TransactionGroup;
    expect(group.groupId, 'g1');
    expect(group.count, 2);
    expect(group.total, 3500);
    expect(result[1], isA<TransactionModel>());
  });

  test('a group emits at the position of its first member', () {
    final list = [tx('solo'), tx('a', groupId: 'g1'), tx('b', groupId: 'g1')];
    final result = collapseTransactionGroups(list);
    expect(result[0], isA<TransactionModel>());
    expect(result[1], isA<TransactionGroup>());
  });

  test('a single remaining member renders as a plain transaction', () {
    final list = [tx('a', groupId: 'g1')];
    final result = collapseTransactionGroups(list);
    expect(result, hasLength(1));
    expect(result.first, isA<TransactionModel>());
  });
}
