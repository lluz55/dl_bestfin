import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class TransactionRepository {
  Stream<List<TransactionModel>> watchAllTransactions();
  Stream<List<TransactionModel>> watchTransactionsWithFilters({
    String? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  });
  Stream<List<TransactionModel>> watchSuggestedTransactions();
  Future<String> createTransaction({
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
  });
  Future<String> createSuggestion({
    required DateTime date,
    required String description,
    required String type,
    required int amountInCents,
    required String accountId,
    String? categoryId,
    String? merchant,
  });
  Future<void> confirmSuggestion(String id);
  Future<void> updateTransaction({
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
  });
  Future<void> deleteTransaction(String id);
  Future<List<String>> getRecentDescriptions({String? query, String? type, int limit = 10});
}

class TransactionRepositoryImpl implements TransactionRepository {
  final db.AppDatabase _database;

  TransactionRepositoryImpl(this._database);

  @override
  Stream<List<TransactionModel>> watchAllTransactions() {
    final query =
        _database.select(_database.transactions).join([
            leftOuterJoin(
              _database.categories,
              _database.categories.id.equalsExp(
                _database.transactions.categoryId,
              ),
            ),
            leftOuterJoin(
              _database.entities,
              _database.entities.id.equalsExp(_database.transactions.entityId),
            ),
          ])
          ..where(_database.transactions.isConfirmed.equals(true))
          ..orderBy([
            OrderingTerm(
              expression: _database.transactions.date,
              mode: OrderingMode.desc,
            ),
          ]);

    return query.watch().asyncMap((rows) async {
      final txIds = rows
          .map((r) => r.readTable(_database.transactions).id)
          .toList();
      final List<db.Entry> allEntries;
      if (txIds.isEmpty) {
        allEntries = [];
      } else {
        allEntries = await (_database.select(
          _database.entries,
        )..where((e) => e.transactionId.isIn(txIds))).get();
      }

      final List<TransactionModel> results = [];
      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        final cat = row.readTableOrNull(_database.categories);
        final ent = row.readTableOrNull(_database.entities);

        final txEntries = allEntries
            .where((e) => e.transactionId == tx.id)
            .map((e) => EntryModel.fromDb(e))
            .toList();

        results.add(
          TransactionModel.fromDb(
            tx,
            category: cat != null ? CategoryModel.fromDb(cat) : null,
            entity: ent,
            entries: txEntries,
          ),
        );
      }
      return results;
    });
  }

  @override
  Stream<List<TransactionModel>> watchTransactionsWithFilters({
    String? type,
    String? accountId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = _database.select(_database.transactions).join([
      leftOuterJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.transactions.categoryId),
      ),
      leftOuterJoin(
        _database.entities,
        _database.entities.id.equalsExp(_database.transactions.entityId),
      ),
    ]);

    query.where(_database.transactions.isConfirmed.equals(true));

    // Filtros do Header da Transação
    if (type != null) {
      query.where(_database.transactions.type.equals(type));
    }
    if (categoryId != null) {
      query.where(_database.transactions.categoryId.equals(categoryId));
    }
    if (startDate != null) {
      query.where(_database.transactions.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(_database.transactions.date.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([
      OrderingTerm(
        expression: _database.transactions.date,
        mode: OrderingMode.desc,
      ),
    ]);

    return query.watch().asyncMap((rows) async {
      final txIds = rows
          .map((r) => r.readTable(_database.transactions).id)
          .toList();
      if (txIds.isEmpty) return <TransactionModel>[];

      // Filtro por AccountID exige que a transação possua pelo menos um entry contendo a conta correspondente
      final List<db.Entry> allEntries;
      if (accountId != null) {
        // Encontra IDs das transações associadas a esta conta
        final filterEntries =
            await (_database.select(_database.entries)..where(
                  (e) =>
                      e.accountId.equals(accountId) &
                      e.transactionId.isIn(txIds),
                ))
                .get();
        final matchedTxIds = filterEntries.map((e) => e.transactionId).toSet();
        if (matchedTxIds.isEmpty) return <TransactionModel>[];

        txIds.retainWhere((id) => matchedTxIds.contains(id));
        if (txIds.isEmpty) return <TransactionModel>[];

        allEntries = await (_database.select(
          _database.entries,
        )..where((e) => e.transactionId.isIn(txIds))).get();
      } else {
        allEntries = await (_database.select(
          _database.entries,
        )..where((e) => e.transactionId.isIn(txIds))).get();
      }

      final List<TransactionModel> results = [];
      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        if (!txIds.contains(tx.id)) continue;

        final cat = row.readTableOrNull(_database.categories);
        final ent = row.readTableOrNull(_database.entities);

        final txEntries = allEntries
            .where((e) => e.transactionId == tx.id)
            .map((e) => EntryModel.fromDb(e))
            .toList();

        results.add(
          TransactionModel.fromDb(
            tx,
            category: cat != null ? CategoryModel.fromDb(cat) : null,
            entity: ent,
            entries: txEntries,
          ),
        );
      }
      return results;
    });
  }

  @override
  Stream<List<TransactionModel>> watchSuggestedTransactions() {
    final query =
        _database.select(_database.transactions).join([
            leftOuterJoin(
              _database.categories,
              _database.categories.id.equalsExp(
                _database.transactions.categoryId,
              ),
            ),
            leftOuterJoin(
              _database.entities,
              _database.entities.id.equalsExp(_database.transactions.entityId),
            ),
          ])
          ..where(_database.transactions.isConfirmed.equals(false))
          ..orderBy([
            OrderingTerm(
              expression: _database.transactions.date,
              mode: OrderingMode.desc,
            ),
          ]);

    return query.watch().asyncMap((rows) async {
      final txIds = rows
          .map((r) => r.readTable(_database.transactions).id)
          .toList();
      if (txIds.isEmpty) return <TransactionModel>[];

      final allEntries = await (_database.select(
        _database.entries,
      )..where((e) => e.transactionId.isIn(txIds))).get();

      return rows.map((row) {
        final tx = row.readTable(_database.transactions);
        final cat = row.readTableOrNull(_database.categories);
        final ent = row.readTableOrNull(_database.entities);
        final txEntries = allEntries
            .where((e) => e.transactionId == tx.id)
            .map((e) => EntryModel.fromDb(e))
            .toList();
        return TransactionModel.fromDb(
          tx,
          category: cat != null ? CategoryModel.fromDb(cat) : null,
          entity: ent,
          entries: txEntries,
        );
      }).toList();
    });
  }

  @override
  Future<String> createSuggestion({
    required DateTime date,
    required String description,
    required String type,
    required int amountInCents,
    required String accountId,
    String? categoryId,
    String? merchant,
  }) async {
    final transactionId = const Uuid().v4();

    await _database.transaction(() async {
      await _database
          .into(_database.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: transactionId,
              date: date,
              description: description,
              type: type,
              categoryId: Value(categoryId),
              isCompleted: const Value(false),
              isConfirmed: const Value(false),
              source: const Value('notification'),
            ),
          );

      final entryType = type == 'income' ? 'debit' : 'credit';
      await _database
          .into(_database.entries)
          .insert(
            db.EntriesCompanion.insert(
              id: const Uuid().v4(),
              transactionId: transactionId,
              accountId: accountId,
              amount: amountInCents,
              type: entryType,
            ),
          );
    });

    return transactionId;
  }

  @override
  Future<void> confirmSuggestion(String id) async {
    await (_database.update(
      _database.transactions,
    )..where((t) => t.id.equals(id))).write(
      const db.TransactionsCompanion(
        isConfirmed: Value(true),
        isCompleted: Value(true),
      ),
    );
  }

  @override
  Future<String> createTransaction({
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
  }) async {
    final transactionId = const Uuid().v4();

    await _database.transaction(() async {
      // 1. Incrementa o uso da entity
      if (entityId != null) {
        final currentEntity = await (_database.select(
          _database.entities,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        if (currentEntity != null) {
          await (_database.update(
            _database.entities,
          )..where((t) => t.id.equals(entityId))).write(
            db.EntitiesCompanion(
              useCount: Value(currentEntity.useCount + 1),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }

      // 2. Insere cabeçalho da transação
      await _database
          .into(_database.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: transactionId,
              date: date,
              description: description,
              type: type,
              sentiment: Value(sentiment),
              notes: Value(notes),
              categoryId: Value(categoryId),
              entityId: Value(entityId),
              goalId: Value(goalId),
              isCompleted: const Value(true),
            ),
          );

      // 3. Insere entries (Partida Dobrada)
      if (type == 'expense') {
        // Crédito na conta de origem (saída)
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: transactionId,
                accountId: accountId,
                amount: amount,
                type: 'credit',
              ),
            );
      } else if (type == 'income') {
        // Débito na conta de destino (entrada)
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: transactionId,
                accountId: accountId,
                amount: amount,
                type: 'debit',
              ),
            );
      } else if (type == 'transfer' && toAccountId != null) {
        // Crédito na conta de origem (saída)
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: transactionId,
                accountId: accountId,
                amount: amount,
                type: 'credit',
              ),
            );
        // Débito na conta de destino (entrada)
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: transactionId,
                accountId: toAccountId,
                amount: amount,
                type: 'debit',
              ),
            );
      }

      // 4. Atualiza progresso da meta se vinculada
      if (goalId != null) {
        await _updateGoalProgress(goalId, amount, type);
      }
    });
    return transactionId;
  }

  Future<void> _updateGoalProgress(String goalId, int amount, String type,
      {bool isUndo = false}) async {
    final goal = await _database.goalsDao.getGoalById(goalId);
    if (goal == null) return;

    final factor = isUndo ? -1 : 1;
    int impact = 0;

    if (goal.type == 'saving') {
      if (type == 'income' || type == 'transfer') {
        impact = amount * factor;
      } else if (type == 'expense') {
        impact = -amount * factor;
      }
    } else if (goal.type == 'spending') {
      if (type == 'expense') {
        impact = amount * factor;
      } else if (type == 'income') {
        impact = -amount * factor; // Reembolso diminui o gasto
      }
    }

    if (impact != 0) {
      await _database.goalsDao.addContribution(goalId, impact);
    }
  }

  @override
  Future<void> updateTransaction({
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
  }) async {
    await _database.transaction(() async {
      // 0. Busca estado anterior para desfazer impacto na meta
      final oldTx = await (_database.select(_database.transactions)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      if (oldTx != null && oldTx.goalId != null) {
        final oldEntries = await (_database.select(_database.entries)
              ..where((e) => e.transactionId.equals(id)))
            .get();
        if (oldEntries.isNotEmpty) {
          final oldAmount = oldEntries.first.amount;
          await _updateGoalProgress(oldTx.goalId!, oldAmount, oldTx.type,
              isUndo: true);
        }
      }

      // 1. Atualiza cabeçalho
      await (_database.update(
        _database.transactions,
      )..where((t) => t.id.equals(id))).write(
        db.TransactionsCompanion(
          date: Value(date),
          description: Value(description),
          type: Value(type),
          categoryId: Value(categoryId),
          entityId: Value(entityId),
          goalId: Value(goalId),
          sentiment: Value(sentiment),
          notes: Value(notes),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 2. Remove entries antigos
      await (_database.delete(
        _database.entries,
      )..where((e) => e.transactionId.equals(id))).go();

      // 3. Insere novos entries atualizados
      if (type == 'expense') {
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: id,
                accountId: accountId,
                amount: amount,
                type: 'credit',
              ),
            );
      } else if (type == 'income') {
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: id,
                accountId: accountId,
                amount: amount,
                type: 'debit',
              ),
            );
      } else if (type == 'transfer' && toAccountId != null) {
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: id,
                accountId: accountId,
                amount: amount,
                type: 'credit',
              ),
            );
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: id,
                accountId: toAccountId,
                amount: amount,
                type: 'debit',
              ),
            );
      }

      // 4. Aplica novo impacto na meta
      if (goalId != null) {
        await _updateGoalProgress(goalId, amount, type);
      }
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _database.transaction(() async {
      // 0. Desfaz impacto na meta
      final tx = await (_database.select(_database.transactions)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();

      if (tx != null && tx.goalId != null) {
        final entries = await (_database.select(_database.entries)
              ..where((e) => e.transactionId.equals(id)))
            .get();
        if (entries.isNotEmpty) {
          final amount = entries.first.amount;
          await _updateGoalProgress(tx.goalId!, amount, tx.type, isUndo: true);
        }
      }

      await (_database.delete(
        _database.entries,
      )..where((e) => e.transactionId.equals(id))).go();
      await (_database.delete(
        _database.transactions,
      )..where((t) => t.id.equals(id))).go();
    });
  }

  Future<List<String>> getRecentDescriptions({
    String? query,
    String? type,
    int limit = 10,
  }) async {
    final selectQuery = _database.selectOnly(_database.transactions, distinct: true)
      ..addColumns([_database.transactions.description]);

    if (query != null && query.isNotEmpty) {
      selectQuery.where(_database.transactions.description.contains(query));
    }

    if (type != null) {
      selectQuery.where(_database.transactions.type.equals(type));
    }

    selectQuery.orderBy([
      OrderingTerm(
        expression: _database.transactions.date,
        mode: OrderingMode.desc,
      ),
    ]);

    selectQuery.limit(limit);

    final rows = await selectQuery.get();
    return rows
        .map((row) => row.read(_database.transactions.description)!)
        .toList();
  }
}
