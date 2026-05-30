import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_delete_context.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
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
    String? creditCardId,
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
    String? creditCardId,
  });
  Future<void> deleteTransaction(String id);
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
            leftOuterJoin(
              _database.recurringRules,
              _database.recurringRules.baseTransactionId.equalsExp(
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
        final rule = row.readTableOrNull(_database.recurringRules);

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
            recurringRuleId: rule?.id,
          ),
        );
      }
      return results;
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

      final List<db.Entry> allEntries;
      final hasAccountFilter = accountIds != null && accountIds.isNotEmpty;
      final hasCardFilter = creditCardIds != null && creditCardIds.isNotEmpty;

      if (hasAccountFilter || hasCardFilter) {
        final Set<String> matchedTxIds = {};

        if (hasAccountFilter) {
          final filterEntries =
              await (_database.select(_database.entries)..where(
                    (e) =>
                        e.accountId.isIn(accountIds) &
                        e.transactionId.isIn(txIds),
                  ))
                  .get();
          matchedTxIds.addAll(filterEntries.map((e) => e.transactionId));
        }

        if (hasCardFilter) {
          for (final row in rows) {
            final tx = row.readTable(_database.transactions);
            if (tx.creditCardId != null &&
                creditCardIds.contains(tx.creditCardId)) {
              matchedTxIds.add(tx.id);
            }
          }
        }

        if (matchedTxIds.isEmpty) return <TransactionModel>[];

        txIds.retainWhere((id) => matchedTxIds.contains(id));
        if (txIds.isEmpty) return <TransactionModel>[];
      }

      allEntries = await (_database.select(
        _database.entries,
      )..where((e) => e.transactionId.isIn(txIds))).get();

      final List<TransactionModel> results = [];
      for (final row in rows) {
        final tx = row.readTable(_database.transactions);
        if (!txIds.contains(tx.id)) continue;

        final cat = row.readTableOrNull(_database.categories);
        final ent = row.readTableOrNull(_database.entities);
        final rule = row.readTableOrNull(_database.recurringRules);

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
            recurringRuleId: rule?.id,
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
            leftOuterJoin(
              _database.recurringRules,
              _database.recurringRules.baseTransactionId.equalsExp(
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
        final rule = row.readTableOrNull(_database.recurringRules);
        final txEntries = allEntries
            .where((e) => e.transactionId == tx.id)
            .map((e) => EntryModel.fromDb(e))
            .toList();
        return TransactionModel.fromDb(
          tx,
          category: cat != null ? CategoryModel.fromDb(cat) : null,
          entity: ent,
          entries: txEntries,
          recurringRuleId: rule?.id,
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
    String? creditCardId,
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
              creditCardId: Value(creditCardId),
              rawAmount: creditCardId != null
                  ? Value(amount)
                  : const Value.absent(),
              isCompleted: const Value(true),
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

      // 4. Atualiza progresso da meta se vinculada
      if (goalId != null) {
        await _updateGoalProgress(goalId, amount, type);
      } else if (categoryId != null) {
        // Auto-absorção: procura goals ativos que absorvem essa categoria
        await _applyGoalAutoAbsorption(transactionId, categoryId, amount, type);
      }
    });
    return transactionId;
  }

  /// Aplica auto-absorção: liga a transação ao primeiro goal ativo que
  /// absorve [categoryId] e atualiza o progresso do goal.
  Future<void> _applyGoalAutoAbsorption(
    String transactionId,
    String categoryId,
    int amount,
    String type,
  ) async {
    final matchingGoals =
        await _database.goalsDao.getActiveGoalsForCategory(categoryId);
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
  }) async {
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
          categoryId: Value(categoryId),
          entityId: Value(entityId),
          goalId: Value(goalId),
          sentiment: Value(sentiment),
          notes: Value(notes),
          creditCardId: Value(creditCardId),
          rawAmount: creditCardId != null ? Value(amount) : const Value(null),
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

      // 4. Aplica novo impacto na meta
      if (goalId != null) {
        await _updateGoalProgress(goalId, amount, type);
      } else if (categoryId != null) {
        await _applyGoalAutoAbsorption(id, categoryId, amount, type);
      }
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
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

  Future<void> _deleteSingleTx(String id) async {
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
}
