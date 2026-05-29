import 'dart:async';
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
  }) async {
    if (totalInstallments < 2) {
      throw ArgumentError('Parcelamento requer pelo menos 2 parcelas');
    }
    if (totalAmount <= 0) {
      throw ArgumentError('Valor total deve ser maior que zero');
    }

    final baseValue = totalAmount ~/ totalInstallments;
    final remainder = totalAmount % totalInstallments;

    await _database.transaction(() async {
      // Create the first transaction (origin)
      final originTxId = const Uuid().v4();

      await _database
          .into(_database.transactions)
          .insert(
            db.TransactionsCompanion.insert(
              id: originTxId,
              date: baseDate,
              description: '$description (1/$totalInstallments)',
              type: 'expense',
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
              type: 'credit',
            ),
          );

      // Create InstallmentPlan pointing to origin transaction
      final planId = const Uuid().v4();
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
        await _database
            .into(_database.transactions)
            .insert(
              db.TransactionsCompanion.insert(
                id: txId,
                date: installmentDate,
                description: '$description ($i/$totalInstallments)',
                type: 'expense',
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
                type: 'credit',
              ),
            );
      }
    });
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
  }
}
