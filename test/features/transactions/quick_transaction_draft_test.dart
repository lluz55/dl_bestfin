import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/presentation/widgets/quick_transaction_sheet.dart';

void main() {
  test('expense draft carries amount, account, category and entity', () {
    final draft = buildQuickTransactionDraft(
      type: TransactionType.expense,
      amountInCents: 5000,
      description: 'Padaria',
      categoryId: 'cat-1',
      entityId: 'entity-1',
      accountId: 'acc-1',
    );

    expect(draft.id, isEmpty);
    expect(draft.description, 'Padaria');
    expect(draft.categoryId, 'cat-1');
    expect(draft.entityId, 'entity-1');
    expect(draft.amount, 5000);
    expect(draft.accountId, 'acc-1');
  });

  test('income draft uses a debit entry so accountId/amount resolve', () {
    final draft = buildQuickTransactionDraft(
      type: TransactionType.income,
      amountInCents: 12000,
      description: 'Salário',
      entityId: 'payer-1',
      accountId: 'acc-1',
    );

    expect(draft.amount, 12000);
    expect(draft.accountId, 'acc-1');
    expect(draft.entityId, 'payer-1');
  });

  test('transfer draft carries both accounts and drops category/entity', () {
    final draft = buildQuickTransactionDraft(
      type: TransactionType.transfer,
      amountInCents: 3000,
      description: '',
      categoryId: 'cat-1',
      entityId: 'entity-1',
      accountId: 'acc-1',
      toAccountId: 'acc-2',
    );

    expect(draft.amount, 3000);
    expect(draft.accountId, 'acc-1');
    expect(draft.toAccountId, 'acc-2');
    expect(draft.categoryId, isNull);
    expect(draft.entityId, isNull);
  });

  test('missing account yields no entries but still carries other fields', () {
    final draft = buildQuickTransactionDraft(
      type: TransactionType.expense,
      amountInCents: 1500,
      description: 'Sem conta ainda',
      categoryId: 'cat-1',
    );

    expect(draft.accountId, isNull);
    expect(draft.amount, 0);
    expect(draft.description, 'Sem conta ainda');
  });

  test('id is empty so the draft is never treated as an existing transaction', () {
    final draft = buildQuickTransactionDraft(
      type: TransactionType.expense,
      amountInCents: 100,
      description: '',
      accountId: 'acc-1',
    );

    expect(draft.id.isNotEmpty, isFalse);
  });
}
