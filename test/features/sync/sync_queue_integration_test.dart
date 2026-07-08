import 'dart:convert';

import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/categories/data/repositories/category_repository.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('account repository enqueues account changes', () async {
    final repository = AccountRepositoryImpl(db);

    await repository.createWithInitialBalance(
      name: 'Checking',
      type: 'checking',
      icon: 'account_balance_wallet',
      color: '#6750A4',
      initialBalance: 0,
    );

    final pending = await db.syncQueueDao.getPendingItems();
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'insert');
    expect(pending.single.entityType, 'account');

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['name'], 'Checking');
  });

  test('transaction repository enqueues transaction with entries', () async {
    final accountId = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: accountId, name: 'Wallet', type: 'wallet'),
    );
    final repository = TransactionRepositoryImpl(db);

    await repository.createTransaction(
      date: DateTime(2026, 7),
      description: 'Groceries',
      type: 'expense',
      amount: 1234,
      accountId: accountId,
    );

    // Wait for the unawaited _enqueueTransactionSync to execute
    await Future.delayed(Duration.zero);

    final pending = await db.syncQueueDao.getPendingItems();
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'insert');
    expect(pending.single.entityType, 'transaction');

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['description'], 'Groceries');
    expect(payload['entries'], isA<List<dynamic>>());
    expect(payload['entries'] as List<dynamic>, hasLength(1));
  });

  test('category repository enqueues category changes', () async {
    final repository = CategoryRepositoryImpl(db);

    await repository.createCategory(
      name: 'Food',
      icon: 'restaurant',
      color: '#FF9800',
      type: 'expense',
    );

    final pending = await db.syncQueueDao.getPendingItems();
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'insert');
    expect(pending.single.entityType, 'category');

    final payload = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    expect(payload['name'], 'Food');
  });
}
