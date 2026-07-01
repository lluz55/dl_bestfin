import 'dart:convert';

import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class AccountRepository {
  Stream<List<Account>> watchAllAccounts();
  Stream<Account> watchAccountById(String id);
  Future<int> getAccountBalance(String id);
  Future<void> createWithInitialBalance({
    required String name,
    required String type,
    required String? icon,
    required String? color,
    required int initialBalance,
  });
  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    required String? icon,
    required String? color,
    bool? isActive,
  });
  Future<void> deleteAccount(String id);
  Future<bool> canDelete(String id);
}

class AccountRepositoryImpl implements AccountRepository {
  final db.AppDatabase _database;

  AccountRepositoryImpl(this._database);

  @override
  Stream<List<Account>> watchAllAccounts() {
    final query = _database.select(_database.accounts).join([
      leftOuterJoin(
        _database.entries,
        _database.entries.accountId.equalsExp(_database.accounts.id),
      ),
    ])..where(_database.accounts.type.equals('credit_card_bill').not());

    return query.watch().map((rows) {
      final Map<String, db.Account> accountsMap = {};
      final Map<String, int> balancesMap = {};

      for (final row in rows) {
        final account = row.readTable(_database.accounts);
        final entry = row.readTableOrNull(_database.entries);

        accountsMap[account.id] = account;

        if (entry != null) {
          final currentBalance = balancesMap[account.id] ?? 0;
          final amount = entry.amount;
          final change = entry.type == 'debit' ? amount : -amount;
          balancesMap[account.id] = currentBalance + change;
        } else {
          balancesMap[account.id] ??= 0;
        }
      }

      return accountsMap.values.map((dbAcc) {
        final balance = balancesMap[dbAcc.id] ?? 0;
        return Account.fromDb(dbAcc, balance);
      }).toList();
    });
  }

  @override
  Stream<Account> watchAccountById(String id) {
    final query = _database.select(_database.accounts).join([
      leftOuterJoin(
        _database.entries,
        _database.entries.accountId.equalsExp(_database.accounts.id),
      ),
    ])..where(_database.accounts.id.equals(id));

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        throw Exception('Account not found');
      }

      final dbAcc = rows.first.readTable(_database.accounts);
      int balance = 0;

      for (final row in rows) {
        final entry = row.readTableOrNull(_database.entries);
        if (entry != null) {
          final change = entry.type == 'debit' ? entry.amount : -entry.amount;
          balance += change;
        }
      }

      return Account.fromDb(dbAcc, balance);
    });
  }

  @override
  Future<int> getAccountBalance(String id) async {
    final entriesList = await (_database.select(
      _database.entries,
    )..where((t) => t.accountId.equals(id))).get();

    int balance = 0;
    for (final entry in entriesList) {
      final change = entry.type == 'debit' ? entry.amount : -entry.amount;
      balance += change;
    }
    return balance;
  }

  @override
  Future<void> createWithInitialBalance({
    required String name,
    required String type,
    required String? icon,
    required String? color,
    required int initialBalance,
  }) async {
    final accountId = const Uuid().v4();

    await _database.transaction(() async {
      // Insert Account
      await _database
          .into(_database.accounts)
          .insert(
            db.AccountsCompanion.insert(
              id: accountId,
              name: name,
              type: type,
              icon: Value(icon),
              color: Value(color),
              isArchived: const Value(false),
            ),
          );

      // Create initial balance transaction/entry if > 0
      if (initialBalance > 0) {
        await _database.transactionsDao.createTransaction(
          data: db.TransactionsCompanion.insert(
            id: const Uuid().v4(),
            description: 'Saldo Inicial',
            type: 'income',
            date: DateTime.now(),
            categoryId: const Value('cat_opening_balance'),
            isCompleted: const Value(true),
          ),
          accountId: accountId,
          amount: initialBalance,
        );
      }
    });
    await _enqueueAccountSync(accountId, 'insert');
  }

  @override
  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    required String? icon,
    required String? color,
    bool? isActive,
  }) async {
    await (_database.update(
      _database.accounts,
    )..where((t) => t.id.equals(id))).write(
      db.AccountsCompanion(
        name: Value(name),
        type: Value(type),
        icon: Value(icon),
        color: Value(color),
        isArchived: isActive != null ? Value(!isActive) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _enqueueAccountSync(id, 'update');
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _enqueueAccountSync(id, 'delete');
    await _database.accountsDao.deleteAccount(id);
  }

  @override
  Future<bool> canDelete(String id) async => true;

  Future<void> _enqueueAccountSync(String id, String operation) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    final payload = account == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': account.id,
            'name': account.name,
            'type': account.type,
            'icon': account.icon,
            'color': account.color,
            'is_archived': account.isArchived,
            'created_at': account.createdAt.toIso8601String(),
            'updated_at': account.updatedAt.toIso8601String(),
          };

    await _database.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'account',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }
}
