import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/installments/domain/models/installment_plan.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';

abstract class InstallmentRepository {
  Future<void> createInstallmentPlan({
    required DateTime baseDate,
    required String description,
    required int totalAmount,
    required int totalInstallments,
    required String accountId,
    String? categoryId,
    String? entityId,
    String? sentiment,
    String? notes,
    String type = 'expense',
  });

  Future<InstallmentPlanModel?> getInstallmentPlanById(String planId);

  Future<void> updateInstallmentPlan({
    required String planId,
    required int totalAmount,
    required String description,
    String? categoryId,
    String? entityId,
    String? notes,
    String? sentiment,
  });

  Stream<List<InstallmentPlanModel>> watchInstallmentPlans();

  Future<void> cancelInstallmentPlan(String planId);
}

class InstallmentRepositoryImpl implements InstallmentRepository {
  final db.AppDatabase _database;

  InstallmentRepositoryImpl(this._database);

  @override
  Future<void> createInstallmentPlan({
    required DateTime baseDate,
    required String description,
    required int totalAmount,
    required int totalInstallments,
    required String accountId,
    String? categoryId,
    String? entityId,
    String? sentiment,
    String? notes,
    String type = 'expense',
  }) async {
    if (totalInstallments < 2) {
      throw ArgumentError('Parcelamento requer pelo menos 2 parcelas');
    }
    if (totalAmount <= 0) {
      throw ArgumentError('Valor total deve ser maior que zero');
    }

    final baseValue = totalAmount ~/ totalInstallments;
    final remainder = totalAmount % totalInstallments;
    final entryType = type == 'income' ? 'debit' : 'credit';
    final cleanDesc = description
        .replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '')
        .trim();

    final planId = const Uuid().v4();
    final generatedTxIds = <String>[];

    await _database.transaction(() async {
      // Create the first transaction (origin)
      final originTxId = const Uuid().v4();
      generatedTxIds.add(originTxId);

      await _database
          .into(_database.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: originTxId,
              date: baseDate,
              description: '$cleanDesc (1/$totalInstallments)',
              type: type,
              sentiment: Value(sentiment),
              notes: Value(notes),
              categoryId: Value(categoryId),
              entityId: Value(entityId),
              isCompleted: const Value(true),
            ),
          );

      // Create entry for first transaction
      await _database
          .into(_database.entries)
          .insert(
            db.EntriesCompanion.insert(
              id: const Uuid().v4(),
              transactionId: originTxId,
              accountId: accountId,
              amount: baseValue,
              type: entryType,
            ),
          );

      // Create InstallmentPlan pointing to origin transaction
      await _database
          .into(_database.installmentPlans)
          .insert(
            db.InstallmentPlansCompanion.insert(
              id: planId,
              originTransactionId: originTxId,
              totalInstallments: totalInstallments,
              installmentValue: baseValue,
            ),
          );

      // Update origin transaction with plan id
      await (_database.update(
        _database.transactions,
      )..where((t) => t.id.equals(originTxId))).write(
        db.TransactionsCompanion(
          installmentPlanId: Value(planId),
          installmentNumber: const Value(1),
        ),
      );

      // Generate remaining future transactions
      for (int i = 2; i <= totalInstallments; i++) {
        final installmentDate = DateTime(
          baseDate.year,
          baseDate.month + (i - 1),
          baseDate.day,
        );
        final isLast = i == totalInstallments;
        final value = isLast ? baseValue + remainder : baseValue;

        final txId = const Uuid().v4();
        generatedTxIds.add(txId);

        await _database
            .into(_database.transactions)
            .insert(
              db.TransactionsCompanion.insert(
                id: txId,
                date: installmentDate,
                description: '$cleanDesc ($i/$totalInstallments)',
                type: type,
                sentiment: Value(sentiment),
                notes: Value(notes),
                categoryId: Value(categoryId),
                entityId: Value(entityId),
                installmentPlanId: Value(planId),
                installmentNumber: Value(i),
                isCompleted: const Value(false),
              ),
            );

        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: txId,
                accountId: accountId,
                amount: value,
                type: entryType,
              ),
            );
      }
    });

    await _enqueueInstallmentPlanSync(planId, 'insert');
    for (final txId in generatedTxIds) {
      await _enqueueTransactionSync(txId, 'insert');
    }
  }

  @override
  Future<InstallmentPlanModel?> getInstallmentPlanById(String planId) async {
    final plan = await (_database.select(
      _database.installmentPlans,
    )..where((p) => p.id.equals(planId))).getSingleOrNull();
    if (plan == null) return null;
    return InstallmentPlanModel(
      id: plan.id,
      originTransactionId: plan.originTransactionId,
      totalInstallments: plan.totalInstallments,
      installmentValue: plan.installmentValue,
      createdAt: plan.createdAt,
    );
  }

  @override
  Future<void> updateInstallmentPlan({
    required String planId,
    required int totalAmount,
    required String description,
    String? categoryId,
    String? entityId,
    String? notes,
    String? sentiment,
  }) async {
    final plan = await (_database.select(
      _database.installmentPlans,
    )..where((p) => p.id.equals(planId))).getSingleOrNull();
    if (plan == null) return;

    final totalInstallments = plan.totalInstallments;
    final baseValue = totalAmount ~/ totalInstallments;
    final remainder = totalAmount % totalInstallments;
    final cleanDesc = description
        .replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '')
        .trim();

    final txs =
        await (_database.select(_database.transactions)
              ..where((t) => t.installmentPlanId.equals(planId))
              ..orderBy([(t) => OrderingTerm(expression: t.installmentNumber)]))
            .get();

    await _database.transaction(() async {
      for (final tx in txs) {
        final isLast = tx.installmentNumber == totalInstallments;
        final value = isLast ? baseValue + remainder : baseValue;

        await (_database.update(
          _database.transactions,
        )..where((t) => t.id.equals(tx.id))).write(
          db.TransactionsCompanion(
            description: Value(
              '$cleanDesc (${tx.installmentNumber}/$totalInstallments)',
            ),
            categoryId: Value(categoryId),
            entityId: Value(entityId),
            notes: Value(notes),
            sentiment: Value(sentiment),
          ),
        );

        await (_database.update(_database.entries)
              ..where((e) => e.transactionId.equals(tx.id)))
            .write(db.EntriesCompanion(amount: Value(value)));
      }

      await (_database.update(
        _database.installmentPlans,
      )..where((p) => p.id.equals(planId))).write(
        db.InstallmentPlansCompanion(installmentValue: Value(baseValue)),
      );
    });

    await _enqueueInstallmentPlanSync(planId, 'update');
    for (final tx in txs) {
      await _enqueueTransactionSync(tx.id, 'update');
    }
  }

  @override
  Stream<List<InstallmentPlanModel>> watchInstallmentPlans() {
    final query = _database.select(_database.installmentPlans)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap((plans) async {
      final result = <InstallmentPlanModel>[];
      for (final plan in plans) {
        final txQuery =
            _database.select(_database.transactions).join([
                innerJoin(
                  _database.entries,
                  _database.entries.transactionId.equalsExp(
                    _database.transactions.id,
                  ),
                ),
                leftOuterJoin(
                  _database.categories,
                  _database.categories.id.equalsExp(
                    _database.transactions.categoryId,
                  ),
                ),
              ])
              ..where(_database.transactions.installmentPlanId.equals(plan.id))
              ..orderBy([
                OrderingTerm(
                  expression: _database.transactions.installmentNumber,
                  mode: OrderingMode.asc,
                ),
              ]);

        final rows = await txQuery.get();
        final transactions = <TransactionModel>[];
        for (final row in rows) {
          final tx = row.readTable(_database.transactions);
          final entry = row.readTable(_database.entries);
          final cat = row.readTableOrNull(_database.categories);
          transactions.add(
            TransactionModel.fromDb(
              tx,
              category: cat != null ? CategoryModel.fromDb(cat) : null,
              entries: [EntryModel.fromDb(entry)],
            ),
          );
        }

        result.add(
          InstallmentPlanModel(
            id: plan.id,
            originTransactionId: plan.originTransactionId,
            totalInstallments: plan.totalInstallments,
            installmentValue: plan.installmentValue,
            createdAt: plan.createdAt,
            transactions: transactions,
          ),
        );
      }
      return result;
    });
  }

  @override
  Future<void> cancelInstallmentPlan(String planId) async {
    final completedTxs =
        await (_database.select(_database.transactions)..where(
              (t) =>
                  t.installmentPlanId.equals(planId) &
                  t.isCompleted.equals(true),
            ))
            .get();
    final uncompletedTxs =
        await (_database.select(_database.transactions)..where(
              (t) =>
                  t.installmentPlanId.equals(planId) &
                  t.isCompleted.equals(false),
            ))
            .get();

    await _database.transaction(() async {
      // Clear installment references from the origin (completed) transaction
      await (_database.update(_database.transactions)..where(
            (t) =>
                t.installmentPlanId.equals(planId) & t.isCompleted.equals(true),
          ))
          .write(
            const db.TransactionsCompanion(
              installmentPlanId: Value(null),
              installmentNumber: Value(null),
            ),
          );

      // Delete uncompleted transactions belonging to this plan
      await (_database.delete(_database.transactions)..where(
            (t) =>
                t.installmentPlanId.equals(planId) &
                t.isCompleted.equals(false),
          ))
          .go();

      // Delete the plan itself
      await (_database.delete(
        _database.installmentPlans,
      )..where((p) => p.id.equals(planId))).go();
    });

    await _enqueueInstallmentPlanSync(planId, 'delete');
    for (final tx in completedTxs) {
      await _enqueueTransactionSync(tx.id, 'update');
    }
    for (final tx in uncompletedTxs) {
      await _enqueueTransactionSync(tx.id, 'delete');
    }
  }

  Future<void> _enqueueInstallmentPlanSync(String id, String operation) async {
    final plan = await (_database.select(
      _database.installmentPlans,
    )..where((p) => p.id.equals(id))).getSingleOrNull();

    final payload = plan == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': plan.id,
            'origin_transaction_id': plan.originTransactionId,
            'total_installments': plan.totalInstallments,
            'installment_value': plan.installmentValue,
            'created_at': plan.createdAt.toIso8601String(),
            'updated_at': plan.createdAt.toIso8601String(),
          };

    await _database.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'installment_plan',
      entityId: id,
      payload: jsonEncode(payload),
    );
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
}
