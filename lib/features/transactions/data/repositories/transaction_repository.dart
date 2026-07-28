import 'dart:async';
import 'dart:convert';

import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/notifications/reminder_scheduler.dart';
import 'package:bestfin/features/transactions/data/repositories/enriched_category_cache.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_delete_context.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/transactions/domain/models/split_entry.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class TransactionRepository {
  Stream<List<TransactionModel>> watchAllTransactions();
  Stream<List<TransactionModel>> watchTransactionsWithFilters({
    String? type,
    List<String>? accountIds,
    List<String>? creditCardIds,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCompleted,
    String? groupId,
  });
  Stream<List<TransactionModel>> watchSuggestedTransactions();

  /// Busca uma transação pelo id, com categoria/entidade/entries agregadas —
  /// usado para navegação a partir do toque em uma notificação de lembrete.
  Future<TransactionModel?> getTransactionById(String id);
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
    String? creditCardId,
    List<SplitEntry>? splits,
    bool isCompleted = true,
  });

  /// Insere todas as transações em uma única transação de banco —
  /// tudo-ou-nada: se qualquer linha falhar, nada é gravado.
  Future<List<String>> createTransactionsBulk(List<BulkTransactionItem> items);

  /// Substitui os membros de um bloco agrupado ([groupId]) pelos [items]
  /// informados, em uma única transação de banco. Os membros antigos são
  /// removidos (desfazendo impacto em metas e recalculando saldos) e os novos
  /// inseridos — cada item carrega o `groupId` de destino (o mesmo, para manter
  /// agrupado, ou null para desagrupar). Usado pela edição de bloco.
  Future<void> updateGroupedTransactions(
    String groupId,
    List<BulkTransactionItem> items,
  );
  Future<void> confirmSuggestion(String id);

  /// Marca uma transação pendente (futura, `isCompleted == false`) como
  /// concluída — ex.: uma parcela de recorrência ainda não paga. Diferente de
  /// [confirmSuggestion], que resolve sugestões geradas por recorrências sem
  /// auto-confirmação, esta ação fica disponível para qualquer transação
  /// pendente na UI principal.
  Future<void> markAsPaid(String id);
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
    String? creditCardId,
    List<SplitEntry>? splits,
    bool? isCompleted,
  });
  Future<void> deleteTransaction(String id);

  /// Exclui várias transações de uma vez, em uma única transação de banco.
  /// Cada membro desfaz seu impacto em metas, remove suas entries e enfileira
  /// o sync — os saldos (derivados das entries) recalculam sozinhos via stream.
  Future<void> deleteTransactions(List<String> ids);
  Future<TransactionDeleteContext> getDeleteContext(String id);
  Future<void> deleteInstallmentSingle(String id);
  Future<void> deleteInstallmentFromHere(String id, String planId);
  Future<void> deleteInstallmentAll(String planId);
  Future<void> deleteRecurringBaseAndFuture(String id, String ruleId);
  Future<void> deleteRecurringBaseAndAll(String id, String ruleId);
  Future<void> deleteRecurringCloneAndFuture(
    String id,
    String ruleId,
    DateTime date,
  );
  Future<List<String>> getRecentDescriptions({
    String? query,
    String? type,
    int limit = 10,
  });
  Future<bool> hasAnyTransactions();
}

class TransactionRepositoryImpl implements TransactionRepository {
  final db.AppDatabase _database;
  late final ReminderScheduler _reminderScheduler = ReminderScheduler(
    _database,
  );

  // O mapa enriquecido de categorias (árvore pai/filho) é consultado a cada
  // emissão dos streams de transação; a lógica de cache/invalidação vive em
  // [EnrichedCategoryCache] (extraída na task 58).
  late final EnrichedCategoryCache _categoryCache = EnrichedCategoryCache(
    _database,
  );

  TransactionRepositoryImpl(this._database);

  void dispose() {
    _categoryCache.dispose();
  }

  // Agendar/cancelar lembretes é um efeito colateral best-effort — uma falha
  // aqui (ex.: plugin de notificação indisponível) nunca deve interromper a
  // criação/edição/exclusão da transação em si.
  void _scheduleReminder(String id) {
    unawaited(_reminderScheduler.scheduleOne(id).catchError((_) {}));
  }

  void _cancelReminder(String id) {
    unawaited(_reminderScheduler.cancelOne(id).catchError((_) {}));
  }

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
            leftOuterJoin(
              _database.recurringRules,
              _database.recurringRules.baseTransactionId.equalsExp(
                _database.transactions.id,
              ),
            ),
            leftOuterJoin(
              _database.entries,
              _database.entries.transactionId.equalsExp(
                _database.transactions.id,
              ),
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
      final categoriesMap = await _categoryCache.load();
      final txMap = <String, db.Transaction>{};
      final catMap = <String, db.Category?>{};
      final entMap = <String, db.Entity?>{};
      final ruleMap = <String, db.RecurringRule?>{};
      final entriesMap = <String, List<EntryModel>>{};

      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        final cat = row.readTableOrNull(_database.categories);
        final ent = row.readTableOrNull(_database.entities);
        final rule = row.readTableOrNull(_database.recurringRules);
        final entry = row.readTableOrNull(_database.entries);

        if (!txMap.containsKey(tx.id)) {
          txMap[tx.id] = tx;
          catMap[tx.id] = cat;
          entMap[tx.id] = ent;
          ruleMap[tx.id] = rule;
          entriesMap[tx.id] = [];
        }

        if (entry != null) {
          entriesMap[tx.id]!.add(EntryModel.fromDb(entry));
        }
      }

      return txMap.entries.map((e) {
        final catId = catMap[e.key]?.id;
        return TransactionModel.fromDb(
          e.value,
          category: catId != null ? categoriesMap[catId] : null,
          entity: entMap[e.key],
          entries: entriesMap[e.key]!,
          recurringRuleId: ruleMap[e.key]?.id,
        );
      }).toList();
    });
  }

  @override
  Stream<List<TransactionModel>> watchTransactionsWithFilters({
    String? type,
    List<String>? accountIds,
    List<String>? creditCardIds,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCompleted,
    String? groupId,
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
      leftOuterJoin(
        _database.recurringRules,
        _database.recurringRules.baseTransactionId.equalsExp(
          _database.transactions.id,
        ),
      ),
      leftOuterJoin(
        _database.entries,
        _database.entries.transactionId.equalsExp(_database.transactions.id),
      ),
    ]);

    query.where(_database.transactions.isConfirmed.equals(true));

    if (type != null) {
      query.where(_database.transactions.type.equals(type));
    }
    if (categoryId != null) {
      query.where(_database.transactions.categoryId.equals(categoryId));
    }
    if (groupId != null) {
      query.where(_database.transactions.groupId.equals(groupId));
    }
    if (startDate != null) {
      query.where(_database.transactions.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(_database.transactions.date.isSmallerOrEqualValue(endDate));
    }
    if (isCompleted != null) {
      query.where(_database.transactions.isCompleted.equals(isCompleted));
    }
    if (accountIds != null && accountIds.isNotEmpty) {
      final txIdsWithAccount = _database.selectOnly(_database.entries)
        ..addColumns([_database.entries.transactionId])
        ..where(_database.entries.accountId.isIn(accountIds));
      query.where(_database.transactions.id.isInQuery(txIdsWithAccount));
    }
    if (creditCardIds != null && creditCardIds.isNotEmpty) {
      query.where(_database.transactions.creditCardId.isIn(creditCardIds));
    }

    query.orderBy([
      OrderingTerm(
        expression: _database.transactions.date,
        mode: OrderingMode.desc,
      ),
    ]);

    return query.watch().asyncMap((rows) async {
      final categoriesMap = await _categoryCache.load();
      final txMap = <String, db.Transaction>{};
      final catMap = <String, db.Category?>{};
      final entMap = <String, db.Entity?>{};
      final ruleMap = <String, db.RecurringRule?>{};
      final entriesMap = <String, List<EntryModel>>{};

      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        final cat = row.readTableOrNull(_database.categories);
        final ent = row.readTableOrNull(_database.entities);
        final rule = row.readTableOrNull(_database.recurringRules);
        final entry = row.readTableOrNull(_database.entries);

        if (!txMap.containsKey(tx.id)) {
          txMap[tx.id] = tx;
          catMap[tx.id] = cat;
          entMap[tx.id] = ent;
          ruleMap[tx.id] = rule;
          entriesMap[tx.id] = [];
        }

        if (entry != null) {
          entriesMap[tx.id]!.add(EntryModel.fromDb(entry));
        }
      }

      return txMap.entries.map((e) {
        final catId = catMap[e.key]?.id;
        return TransactionModel.fromDb(
          e.value,
          category: catId != null ? categoriesMap[catId] : null,
          entity: entMap[e.key],
          entries: entriesMap[e.key]!,
          recurringRuleId: ruleMap[e.key]?.id,
        );
      }).toList();
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
            leftOuterJoin(
              _database.recurringRules,
              _database.recurringRules.baseTransactionId.equalsExp(
                _database.transactions.id,
              ),
            ),
            leftOuterJoin(
              _database.entries,
              _database.entries.transactionId.equalsExp(
                _database.transactions.id,
              ),
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
      final categoriesMap = await _categoryCache.load();
      final txMap = <String, db.Transaction>{};
      final catMap = <String, db.Category?>{};
      final entMap = <String, db.Entity?>{};
      final ruleMap = <String, db.RecurringRule?>{};
      final entriesMap = <String, List<EntryModel>>{};

      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        final cat = row.readTableOrNull(_database.categories);
        final ent = row.readTableOrNull(_database.entities);
        final rule = row.readTableOrNull(_database.recurringRules);
        final entry = row.readTableOrNull(_database.entries);

        if (!txMap.containsKey(tx.id)) {
          txMap[tx.id] = tx;
          catMap[tx.id] = cat;
          entMap[tx.id] = ent;
          ruleMap[tx.id] = rule;
          entriesMap[tx.id] = [];
        }

        if (entry != null) {
          entriesMap[tx.id]!.add(EntryModel.fromDb(entry));
        }
      }

      return txMap.entries.map((e) {
        final catId = catMap[e.key]?.id;
        return TransactionModel.fromDb(
          e.value,
          category: catId != null ? categoriesMap[catId] : null,
          entity: entMap[e.key],
          entries: entriesMap[e.key]!,
          recurringRuleId: ruleMap[e.key]?.id,
        );
      }).toList();
    });
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    final query = _database.select(_database.transactions).join([
      leftOuterJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.transactions.categoryId),
      ),
      leftOuterJoin(
        _database.entities,
        _database.entities.id.equalsExp(_database.transactions.entityId),
      ),
      leftOuterJoin(
        _database.recurringRules,
        _database.recurringRules.baseTransactionId.equalsExp(
          _database.transactions.id,
        ),
      ),
      leftOuterJoin(
        _database.entries,
        _database.entries.transactionId.equalsExp(_database.transactions.id),
      ),
    ])..where(_database.transactions.id.equals(id));

    final rows = await query.get();
    if (rows.isEmpty) return null;

    final tx = rows.first.readTable(_database.transactions);
    final cat = rows.first.readTableOrNull(_database.categories);
    final ent = rows.first.readTableOrNull(_database.entities);
    final rule = rows.first.readTableOrNull(_database.recurringRules);
    final entries = rows
        .map((r) => r.readTableOrNull(_database.entries))
        .whereType<db.Entry>()
        .map(EntryModel.fromDb)
        .toList();

    final categoriesMap = await _categoryCache.load();
    return TransactionModel.fromDb(
      tx,
      category: cat != null ? categoriesMap[cat.id] : null,
      entity: ent,
      entries: entries,
      recurringRuleId: rule?.id,
    );
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
  Future<void> markAsPaid(String id) async {
    await (_database.update(
      _database.transactions,
    )..where((t) => t.id.equals(id))).write(
      const db.TransactionsCompanion(
        isConfirmed: Value(true),
        isCompleted: Value(true),
      ),
    );
    // Best-effort, como o lembrete — não faz sentido a UI esperar 3 SELECTs
    // extras (tx + entries + splits) só para montar o payload da fila de sync.
    unawaited(_enqueueTransactionSync(id, 'update').catchError((_) {}));
    _scheduleReminder(id);
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
    String? creditCardId,
    List<SplitEntry>? splits,
    bool isCompleted = true,
  }) async {
    final transactionId = const Uuid().v4();

    await _database.transaction(
      () => _insertTransactionRecords(
        transactionId: transactionId,
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
        splits: splits,
        isCompleted: isCompleted,
      ),
    );
    // Best-effort — a UI não deve esperar 3 SELECTs extras (tx + entries +
    // splits) só para montar o payload da fila de sync após o commit.
    unawaited(
      _enqueueTransactionSync(transactionId, 'insert').catchError((_) {}),
    );
    _scheduleReminder(transactionId);
    return transactionId;
  }

  @override
  Future<List<String>> createTransactionsBulk(
    List<BulkTransactionItem> items,
  ) async {
    final ids = [for (final _ in items) const Uuid().v4()];

    await _database.transaction(() async {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        await _insertTransactionRecords(
          transactionId: ids[i],
          date: item.date,
          description: item.description,
          type: item.type,
          amount: item.amount,
          categoryId: item.categoryId,
          entityId: item.entityId,
          accountId: item.accountId,
          toAccountId: item.toAccountId,
          isCompleted: item.isCompleted,
          groupId: item.groupId,
        );
      }
    });
    // Efeitos colaterais só após o commit — o enqueue de sync relê as linhas
    // do banco e elas não existem fora da transação antes do commit.
    for (final id in ids) {
      unawaited(_enqueueTransactionSync(id, 'insert').catchError((_) {}));
      _scheduleReminder(id);
    }
    return ids;
  }

  @override
  Future<void> updateGroupedTransactions(
    String groupId,
    List<BulkTransactionItem> items,
  ) async {
    final newIds = [for (final _ in items) const Uuid().v4()];

    await _database.transaction(() async {
      // 1. Remove os membros atuais do bloco (desfaz metas + entries).
      final existing = await (_database.select(
        _database.transactions,
      )..where((t) => t.groupId.equals(groupId))).get();
      for (final tx in existing) {
        await _deleteSingleTx(tx.id);
      }

      // 2. Insere as linhas atualizadas com o groupId de destino de cada item.
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        await _insertTransactionRecords(
          transactionId: newIds[i],
          date: item.date,
          description: item.description,
          type: item.type,
          amount: item.amount,
          categoryId: item.categoryId,
          entityId: item.entityId,
          accountId: item.accountId,
          toAccountId: item.toAccountId,
          isCompleted: item.isCompleted,
          groupId: item.groupId,
        );
      }
    });

    // Efeitos colaterais só após o commit — mesma razão do createTransactionsBulk.
    for (final id in newIds) {
      unawaited(_enqueueTransactionSync(id, 'insert').catchError((_) {}));
      _scheduleReminder(id);
    }
  }

  /// Insere header, entries, splits e progresso de meta de uma transação.
  /// Assume que o chamador já está dentro de um `_database.transaction`.
  Future<void> _insertTransactionRecords({
    required String transactionId,
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
    List<SplitEntry>? splits,
    bool isCompleted = true,
    String? groupId,
  }) async {
    final hasSplits = splits != null && splits.isNotEmpty;

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
            categoryId: hasSplits ? const Value(null) : Value(categoryId),
            entityId: Value(entityId),
            goalId: Value(goalId),
            creditCardId: Value(creditCardId),
            groupId: Value(groupId),
            rawAmount: creditCardId != null
                ? Value(amount)
                : const Value.absent(),
            isSplit: Value(hasSplits),
            // Pendente (isCompleted=false) continua confirmado (revisado pelo
            // usuário) — só ainda não "aconteceu". Mesma modelagem de uma
            // parcela futura de recorrência.
            isCompleted: Value(isCompleted),
          ),
        );

    // 3. Insere entries (Partida Dobrada)
    // Transações de cartão de crédito não criam entries — o saldo da conta vinculada
    // só é impactado no pagamento da fatura.
    if (creditCardId == null) {
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
    }

    // 4. Insere splits se existirem
    if (hasSplits) {
      for (final split in splits) {
        await _database
            .into(_database.transactionSplits)
            .insert(
              db.TransactionSplitsCompanion.insert(
                id: const Uuid().v4(),
                transactionId: transactionId,
                categoryId: Value(split.categoryId),
                amount: split.amount,
                description: Value(split.description),
              ),
            );
      }
    }

    // 5. Atualiza progresso da meta se vinculada
    if (goalId != null) {
      await _updateGoalProgress(goalId, amount, type);
    } else if (categoryId != null && !hasSplits) {
      // Auto-absorção: procura goals ativos que absorvem essa categoria
      await _applyGoalAutoAbsorption(transactionId, categoryId, amount, type);
    }
  }

  /// Aplica auto-absorção: liga a transação ao primeiro goal ativo que
  /// absorve [categoryId] e atualiza o progresso do goal.
  Future<void> _applyGoalAutoAbsorption(
    String transactionId,
    String categoryId,
    int amount,
    String type,
  ) async {
    final matchingGoals = await _database.goalsDao.getActiveGoalsForCategory(
      categoryId,
    );
    if (matchingGoals.isEmpty) return;

    final goal = matchingGoals.first;
    // Vincula a transação ao goal
    await (_database.update(_database.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .write(db.TransactionsCompanion(goalId: Value(goal.id)));
    // Atualiza o progresso
    await _updateGoalProgress(goal.id, amount, type);
  }

  Future<void> _updateGoalProgress(
    String goalId,
    int amount,
    String type, {
    bool isUndo = false,
  }) async {
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
    String? creditCardId,
    List<SplitEntry>? splits,
    bool? isCompleted,
  }) async {
    final hasSplits = splits != null && splits.isNotEmpty;
    await _database.transaction(() async {
      // 0. Busca estado anterior para desfazer impacto na meta
      final oldTx = await (_database.select(
        _database.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (oldTx != null && oldTx.goalId != null) {
        // Para CC, o valor fica em rawAmount; para contas normais, vem do entry
        int oldAmount = oldTx.rawAmount ?? 0;
        if (oldAmount == 0) {
          final oldEntries = await (_database.select(
            _database.entries,
          )..where((e) => e.transactionId.equals(id))).get();
          if (oldEntries.isNotEmpty) oldAmount = oldEntries.first.amount;
        }
        if (oldAmount > 0) {
          await _updateGoalProgress(
            oldTx.goalId!,
            oldAmount,
            oldTx.type,
            isUndo: true,
          );
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
          categoryId: hasSplits ? const Value(null) : Value(categoryId),
          entityId: Value(entityId),
          goalId: Value(goalId),
          sentiment: Value(sentiment),
          notes: Value(notes),
          creditCardId: Value(creditCardId),
          rawAmount: creditCardId != null ? Value(amount) : const Value(null),
          isSplit: Value(hasSplits),
          isCompleted: isCompleted != null
              ? Value(isCompleted)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 2. Remove entries antigos
      await (_database.delete(
        _database.entries,
      )..where((e) => e.transactionId.equals(id))).go();

      // 3. Insere novos entries — transações CC não geram entries
      if (creditCardId == null) {
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
      }

      // 4. Atualiza splits
      await (_database.delete(
        _database.transactionSplits,
      )..where((s) => s.transactionId.equals(id))).go();
      if (hasSplits) {
        for (final split in splits) {
          await _database
              .into(_database.transactionSplits)
              .insert(
                db.TransactionSplitsCompanion.insert(
                  id: const Uuid().v4(),
                  transactionId: id,
                  categoryId: Value(split.categoryId),
                  amount: split.amount,
                  description: Value(split.description),
                ),
              );
        }
      }

      // 5. Aplica novo impacto na meta
      if (goalId != null) {
        await _updateGoalProgress(goalId, amount, type);
      } else if (categoryId != null && !hasSplits) {
        await _applyGoalAutoAbsorption(id, categoryId, amount, type);
      }
    });
    // Best-effort — mesma razão do createTransaction acima.
    unawaited(_enqueueTransactionSync(id, 'update').catchError((_) {}));
    _scheduleReminder(id);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _enqueueTransactionSync(id, 'delete');
    _cancelReminder(id);
    await _database.transaction(() async {
      // 0. Desfaz impacto na meta
      final tx = await (_database.select(
        _database.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (tx != null && tx.goalId != null) {
        final entries = await (_database.select(
          _database.entries,
        )..where((e) => e.transactionId.equals(id))).get();
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

  @override
  Future<void> deleteTransactions(List<String> ids) async {
    if (ids.isEmpty) return;
    // Tudo-ou-nada: se qualquer exclusão falhar, nenhuma é aplicada, evitando
    // saldos parcialmente recalculados.
    await _database.transaction(() async {
      for (final id in ids) {
        await _deleteSingleTx(id);
      }
    });
  }

  Future<void> _deleteSingleTx(String id) async {
    await _enqueueTransactionSync(id, 'delete');
    _cancelReminder(id);
    final tx = await (_database.select(
      _database.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (tx == null) return;

    if (tx.goalId != null) {
      final txEntries = await (_database.select(
        _database.entries,
      )..where((e) => e.transactionId.equals(id))).get();
      if (txEntries.isNotEmpty) {
        await _updateGoalProgress(
          tx.goalId!,
          txEntries.first.amount,
          tx.type,
          isUndo: true,
        );
      }
    }

    await (_database.delete(
      _database.entries,
    )..where((e) => e.transactionId.equals(id))).go();
    await (_database.delete(
      _database.transactions,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> _enqueueTransactionSync(String id, String operation) async {
    final tx = await (_database.select(
      _database.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final entries = await (_database.select(
      _database.entries,
    )..where((e) => e.transactionId.equals(id))).get();
    final splits = await (_database.select(
      _database.transactionSplits,
    )..where((s) => s.transactionId.equals(id))).get();

    final payload = tx == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': tx.id,
            'date': tx.date.toIso8601String(),
            'description': tx.description,
            'type': tx.type,
            'sentiment': tx.sentiment,
            'notes': tx.notes,
            'category_id': tx.categoryId,
            'entity_id': tx.entityId,
            'goal_id': tx.goalId,
            'installment_plan_id': tx.installmentPlanId,
            'installment_number': tx.installmentNumber,
            'recurring_rule_id': tx.recurringRuleId,
            'group_id': tx.groupId,
            'credit_card_id': tx.creditCardId,
            'raw_amount': tx.rawAmount,
            'invoice_id': tx.invoiceId,
            'is_completed': tx.isCompleted,
            'is_confirmed': tx.isConfirmed,
            'source': tx.source,
            'created_at': tx.createdAt.toIso8601String(),
            'updated_at': tx.updatedAt.toIso8601String(),
            'entries': entries
                .map(
                  (entry) => <String, dynamic>{
                    'id': entry.id,
                    'transaction_id': entry.transactionId,
                    'account_id': entry.accountId,
                    'amount': entry.amount,
                    'type': entry.type,
                    'created_at': entry.createdAt.toIso8601String(),
                  },
                )
                .toList(),
            'splits': splits
                .map(
                  (split) => <String, dynamic>{
                    'id': split.id,
                    'transaction_id': split.transactionId,
                    'category_id': split.categoryId,
                    'amount': split.amount,
                    'description': split.description,
                  },
                )
                .toList(),
          };

    await _database.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'transaction',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }

  @override
  Future<TransactionDeleteContext> getDeleteContext(String id) async {
    final tx = await (_database.select(
      _database.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (tx == null) {
      return const TransactionDeleteContext(
        deleteCase: TransactionDeleteCase.regular,
      );
    }

    if (tx.recurringRuleId != null) {
      return TransactionDeleteContext(
        deleteCase: TransactionDeleteCase.recurringClone,
        recurringRuleId: tx.recurringRuleId,
      );
    }

    final rule = await _database.recurringRulesDao.findByBaseTransactionId(id);
    if (rule != null) {
      return TransactionDeleteContext(
        deleteCase: TransactionDeleteCase.recurringBase,
        recurringRuleId: rule.id,
      );
    }

    if (tx.installmentPlanId != null) {
      final plan = await (_database.select(
        _database.installmentPlans,
      )..where((p) => p.id.equals(tx.installmentPlanId!))).getSingleOrNull();
      return TransactionDeleteContext(
        deleteCase: TransactionDeleteCase.installment,
        installmentPlanId: tx.installmentPlanId,
        installmentNumber: tx.installmentNumber,
        totalInstallments: plan?.totalInstallments,
      );
    }

    return const TransactionDeleteContext(
      deleteCase: TransactionDeleteCase.regular,
    );
  }

  @override
  Future<void> deleteInstallmentSingle(String id) async {
    await _database.transaction(() async {
      final tx = await (_database.select(
        _database.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (tx == null) return;

      final planId = tx.installmentPlanId;
      if (planId != null) {
        // Verifica se esta é a transação de origem do plano (causa cascade).
        final isOrigin =
            await (_database.select(_database.installmentPlans)..where(
                  (p) => p.id.equals(planId) & p.originTransactionId.equals(id),
                ))
                .getSingleOrNull() !=
            null;

        if (isOrigin) {
          // Limpa o vínculo de todas as parcelas irmãs antes de deletar o plano.
          await (_database.update(_database.transactions)..where(
                (t) => t.installmentPlanId.equals(planId) & t.id.isNotValue(id),
              ))
              .write(
                const db.TransactionsCompanion(
                  installmentPlanId: Value(null),
                  installmentNumber: Value(null),
                ),
              );
          // Deleta o plano explicitamente (antes da tx origem para controlar ordem).
          await (_database.delete(
            _database.installmentPlans,
          )..where((p) => p.id.equals(planId))).go();
        }
      }

      await _deleteSingleTx(id);
    });
  }

  @override
  Future<void> deleteInstallmentFromHere(String id, String planId) async {
    await _database.transaction(() async {
      final currentTx = await (_database.select(
        _database.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (currentTx == null) return;

      final currentNumber = currentTx.installmentNumber ?? 0;

      final toDelete =
          await (_database.select(_database.transactions)..where(
                (t) =>
                    t.installmentPlanId.equals(planId) &
                    t.installmentNumber.isBiggerOrEqualValue(currentNumber),
              ))
              .get();

      // Limpa installmentPlanId das parcelas que ficam (anteriores a esta).
      await (_database.update(_database.transactions)..where(
            (t) =>
                t.installmentPlanId.equals(planId) &
                t.installmentNumber.isSmallerThanValue(currentNumber),
          ))
          .write(
            const db.TransactionsCompanion(
              installmentPlanId: Value(null),
              installmentNumber: Value(null),
            ),
          );

      // Deleta o plano antes das transações para evitar cascade inesperado.
      await (_database.delete(
        _database.installmentPlans,
      )..where((p) => p.id.equals(planId))).go();

      for (final tx in toDelete) {
        await _deleteSingleTx(tx.id);
      }
    });
  }

  @override
  Future<void> deleteInstallmentAll(String planId) async {
    await _database.transaction(() async {
      final toDelete = await (_database.select(
        _database.transactions,
      )..where((t) => t.installmentPlanId.equals(planId))).get();

      // Deleta o plano antes das transações para evitar cascade inesperado.
      await (_database.delete(
        _database.installmentPlans,
      )..where((p) => p.id.equals(planId))).go();

      for (final tx in toDelete) {
        await _deleteSingleTx(tx.id);
      }
    });
  }

  @override
  Future<void> deleteRecurringBaseAndFuture(String id, String ruleId) async {
    await _database.transaction(() async {
      final clones = await _database.recurringRulesDao
          .getFutureGeneratedTransactions(ruleId, DateTime.now());
      for (final clone in clones) {
        await _deleteSingleTx(clone.id);
      }
      await _database.recurringRulesDao.deleteRule(ruleId);
      await _deleteSingleTx(id);
    });
  }

  @override
  Future<void> deleteRecurringBaseAndAll(String id, String ruleId) async {
    await _database.transaction(() async {
      final clones = await _database.recurringRulesDao.getGeneratedTransactions(
        ruleId,
      );
      for (final clone in clones) {
        await _deleteSingleTx(clone.id);
      }
      await _database.recurringRulesDao.deleteRule(ruleId);
      await _deleteSingleTx(id);
    });
  }

  @override
  Future<void> deleteRecurringCloneAndFuture(
    String id,
    String ruleId,
    DateTime date,
  ) async {
    await _database.transaction(() async {
      final clones =
          await (_database.select(_database.transactions)..where(
                (t) =>
                    t.recurringRuleId.equals(ruleId) &
                    t.date.isBiggerOrEqualValue(date),
              ))
              .get();

      for (final clone in clones) {
        await _deleteSingleTx(clone.id);
      }

      await _database.recurringRulesDao.setStatus(ruleId, 'finished');
    });
  }

  @override
  Future<List<String>> getRecentDescriptions({
    String? query,
    String? type,
    int limit = 10,
  }) async {
    final selectQuery = _database.selectOnly(
      _database.transactions,
      distinct: true,
    )..addColumns([_database.transactions.description]);

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

  @override
  Future<bool> hasAnyTransactions() async {
    final selectQuery = _database.selectOnly(_database.transactions)
      ..addColumns([_database.transactions.id])
      ..where(_database.transactions.isConfirmed.equals(true))
      ..limit(1);
    final row = await selectQuery.getSingleOrNull();
    return row != null;
  }

}
