import 'dart:convert';

import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Lançada ao tentar criar/renomear uma conta com um nome já usado por outra.
class DuplicateAccountNameException implements Exception {
  const DuplicateAccountNameException(this.name);

  final String name;

  @override
  String toString() => 'Já existe uma conta com o nome "$name".';
}

abstract class AccountRepository {
  Stream<List<Account>> watchAllAccounts();
  Stream<Account> watchAccountById(String id);
  Future<int> getAccountBalance(String id);

  /// Retorna o id da conta criada.
  Future<String> createWithInitialBalance({
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
    final balanceExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN entries.type = 'debit' THEN entries.amount ELSE -entries.amount END), 0)",
    );

    final query = _database.select(_database.accounts).join([
      leftOuterJoin(
        _database.entries,
        _database.entries.accountId.equalsExp(_database.accounts.id),
      ),
    ])
      ..where(_database.accounts.type.equals('credit_card_bill').not())
      ..addColumns([balanceExpr]);

    query.groupBy([_database.accounts.id]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final dbAcc = row.readTable(_database.accounts);
        final balance = row.read(balanceExpr) ?? 0;
        return Account.fromDb(dbAcc, balance);
      }).toList();
    });
  }

  @override
  Stream<Account> watchAccountById(String id) {
    final balanceExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN entries.type = 'debit' THEN entries.amount ELSE -entries.amount END), 0)",
    );

    final query = _database.select(_database.accounts).join([
      leftOuterJoin(
        _database.entries,
        _database.entries.accountId.equalsExp(_database.accounts.id),
      ),
    ])
      ..where(_database.accounts.id.equals(id))
      ..addColumns([balanceExpr]);

    query.groupBy([_database.accounts.id]);

    return query.watch().map((rows) {
      if (rows.isEmpty) {
        throw Exception('Account not found');
      }
      final row = rows.first;
      final dbAcc = row.readTable(_database.accounts);
      final balance = row.read(balanceExpr) ?? 0;
      return Account.fromDb(dbAcc, balance);
    });
  }

  @override
  Future<int> getAccountBalance(String id) async {
    final balanceExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE -amount END), 0)",
    );

    final query = _database.selectOnly(_database.entries)
      ..addColumns([balanceExpr])
      ..where(_database.entries.accountId.equals(id));

    final row = await query.getSingleOrNull();
    return row?.read(balanceExpr) ?? 0;
  }

  @override
  Future<String> createWithInitialBalance({
    required String name,
    required String type,
    required String? icon,
    required String? color,
    required int initialBalance,
  }) async {
    await _ensureUniqueName(name);
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
    return accountId;
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
    await _ensureUniqueName(name, excludeId: id);
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

  /// Nomes são comparados sem distinção de maiúsculas e espaços nas bordas;
  /// contas internas de fatura (`credit_card_bill`) ficam fora da checagem.
  Future<void> _ensureUniqueName(String name, {String? excludeId}) async {
    final normalized = name.trim().toLowerCase();
    final query = _database.select(_database.accounts)
      ..where((t) => t.name.trim().lower().equals(normalized))
      ..where((t) => t.type.equals('credit_card_bill').not());
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    query.limit(1);
    final existing = await query.getSingleOrNull();
    if (existing != null) {
      throw DuplicateAccountNameException(name.trim());
    }
  }

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
