import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/get_quick_suggestions.dart';

void main() {
  final now = DateTime(2026, 6, 30);

  TransactionModel expense({
    required String id,
    required DateTime date,
    required String description,
    required int amount,
    required String accountId,
    String? categoryId,
    bool isCompleted = true,
    bool isConfirmed = true,
  }) {
    return TransactionModel(
      id: id,
      date: date,
      description: description,
      type: TransactionType.expense,
      categoryId: categoryId,
      isCompleted: isCompleted,
      isConfirmed: isConfirmed,
      createdAt: date,
      updatedAt: date,
      entries: [
        EntryModel(
          id: '$id-e',
          transactionId: id,
          accountId: accountId,
          amount: amount,
          type: 'credit',
          createdAt: date,
        ),
      ],
    );
  }

  TransactionModel transfer({
    required String id,
    required DateTime date,
    required int amount,
    required String from,
    required String to,
  }) {
    return TransactionModel(
      id: id,
      date: date,
      description: 'Transferência',
      type: TransactionType.transfer,
      isCompleted: true,
      createdAt: date,
      updatedAt: date,
      entries: [
        EntryModel(
          id: '$id-c',
          transactionId: id,
          accountId: from,
          amount: amount,
          type: 'credit',
          createdAt: date,
        ),
        EntryModel(
          id: '$id-d',
          transactionId: id,
          accountId: to,
          amount: amount,
          type: 'debit',
          createdAt: date,
        ),
      ],
    );
  }

  test('ranqueia grupos por frequência ponderada pela recência', () {
    final txs = [
      // "Mercado" 3x recentes → grupo mais relevante.
      expense(
        id: 'm1',
        date: now.subtract(const Duration(days: 1)),
        description: 'Mercado',
        amount: 5000,
        accountId: 'acc1',
        categoryId: 'food',
      ),
      expense(
        id: 'm2',
        date: now.subtract(const Duration(days: 5)),
        description: 'Mercado',
        amount: 5000,
        accountId: 'acc1',
        categoryId: 'food',
      ),
      expense(
        id: 'm3',
        date: now.subtract(const Duration(days: 9)),
        description: 'Mercado',
        amount: 5000,
        accountId: 'acc1',
        categoryId: 'food',
      ),
      // "Uber" 1x muito antigo → menos relevante apesar de existir.
      expense(
        id: 'u1',
        date: now.subtract(const Duration(days: 150)),
        description: 'Uber',
        amount: 2000,
        accountId: 'acc1',
        categoryId: 'transport',
      ),
    ];

    final result = rankQuickSuggestions(
      txs,
      now: now,
      typeFilter: TransactionType.expense,
    );

    expect(result.length, 2);
    expect(result.first.description, 'Mercado');
    expect(result.first.score, greaterThan(result.last.score));
    expect(result.first.amount, 5000);
    expect(result.first.categoryId, 'food');
    expect(result.first.accountId, 'acc1');
  });

  test('escolhe o valor típico (moda) do grupo', () {
    final txs = [
      expense(
        id: 'a',
        date: now.subtract(const Duration(days: 2)),
        description: 'Padaria',
        amount: 1000,
        accountId: 'acc1',
        categoryId: 'food',
      ),
      expense(
        id: 'b',
        date: now.subtract(const Duration(days: 3)),
        description: 'Padaria',
        amount: 1000,
        accountId: 'acc1',
        categoryId: 'food',
      ),
      expense(
        id: 'c',
        date: now.subtract(const Duration(days: 4)),
        description: 'Padaria',
        amount: 9999,
        accountId: 'acc1',
        categoryId: 'food',
      ),
    ];

    final result = rankQuickSuggestions(
      txs,
      now: now,
      typeFilter: TransactionType.expense,
    );

    expect(result.single.amount, 1000);
  });

  test('filtra por tipo e monta transferência com origem/destino', () {
    final txs = [
      transfer(
        id: 't1',
        date: now.subtract(const Duration(days: 2)),
        amount: 20000,
        from: 'corrente',
        to: 'poupanca',
      ),
      transfer(
        id: 't2',
        date: now.subtract(const Duration(days: 6)),
        amount: 20000,
        from: 'corrente',
        to: 'poupanca',
      ),
      expense(
        id: 'e1',
        date: now.subtract(const Duration(days: 1)),
        description: 'Mercado',
        amount: 5000,
        accountId: 'corrente',
        categoryId: 'food',
      ),
    ];

    final transfers = rankQuickSuggestions(
      txs,
      now: now,
      typeFilter: TransactionType.transfer,
    );
    expect(transfers.length, 1);
    expect(transfers.single.type, TransactionType.transfer);
    expect(transfers.single.accountId, 'corrente');
    expect(transfers.single.toAccountId, 'poupanca');
    expect(transfers.single.amount, 20000);
  });

  test('ignora transações não concluídas ou não confirmadas', () {
    final txs = [
      expense(
        id: 'p1',
        date: now.subtract(const Duration(days: 1)),
        description: 'Pendente',
        amount: 5000,
        accountId: 'acc1',
        categoryId: 'food',
        isCompleted: false,
      ),
      expense(
        id: 'p2',
        date: now.subtract(const Duration(days: 1)),
        description: 'Sugerida',
        amount: 5000,
        accountId: 'acc1',
        categoryId: 'food',
        isConfirmed: false,
      ),
    ];

    expect(rankQuickSuggestions(txs, now: now), isEmpty);
  });
}
