import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/financings.dart';
import 'package:bestfin/core/database/tables/financing_installments.dart';

part 'financings_dao.g.dart';

@DriftAccessor(tables: [Financings, FinancingInstallments])
class FinancingsDao extends DatabaseAccessor<AppDatabase>
    with _$FinancingsDaoMixin {
  FinancingsDao(super.db);

  Stream<List<Financing>> watchAllFinancings() {
    return select(financings).watch();
  }

  Future<Financing> getFinancingById(String id) {
    return (select(financings)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertFinancing(FinancingsCompanion financing) {
    return into(financings).insert(financing);
  }

  Future<bool> updateFinancing(FinancingsCompanion financing) {
    return update(financings).replace(financing);
  }

  Future<int> deleteFinancing(String id) {
    return (delete(financings)..where((t) => t.id.equals(id))).go();
  }

  // Installment helpers
  Stream<List<FinancingInstallment>> watchInstallmentsForFinancing(
    String financingId,
  ) {
    return (select(financingInstallments)
          ..where((t) => t.financingId.equals(financingId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.number, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  Future<List<FinancingInstallment>> getInstallmentsForFinancing(
    String financingId,
  ) {
    return (select(financingInstallments)
          ..where((t) => t.financingId.equals(financingId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.number, mode: OrderingMode.asc),
          ]))
        .get();
  }

  Future<int> insertInstallment(FinancingInstallmentsCompanion installment) {
    return into(financingInstallments).insert(installment);
  }

  Future<void> insertInstallments(
    List<FinancingInstallmentsCompanion> companions,
  ) async {
    await batch((b) {
      b.insertAll(financingInstallments, companions);
    });
  }

  Future<bool> updateInstallment(FinancingInstallmentsCompanion installment) {
    return update(financingInstallments).replace(installment);
  }

  Future<int> deleteInstallmentsForFinancing(String financingId) {
    return (delete(
      financingInstallments,
    )..where((t) => t.financingId.equals(financingId))).go();
  }

  /// Publishes the financing header together with all of its installments as
  /// a single sync record — call after the header AND installments are both
  /// written, otherwise peers would receive a snapshot with an empty
  /// installment list.
  Future<void> enqueueFinancingSync(String id, String operation) async {
    final financing = await (select(
      financings,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final installments = financing == null
        ? const <FinancingInstallment>[]
        : await getInstallmentsForFinancing(id);

    final payload = financing == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': financing.id,
            'name': financing.name,
            'total_amount': financing.totalAmount,
            'outstanding_balance': financing.outstandingBalance,
            'interest_rate': financing.interestRate,
            'total_installments': financing.totalInstallments,
            'amortization_system': financing.amortizationSystem,
            'created_at': financing.createdAt.toIso8601String(),
            'updated_at': financing.updatedAt.toIso8601String(),
            'installments': installments
                .map(
                  (i) => <String, dynamic>{
                    'id': i.id,
                    'number': i.number,
                    'amortization_value': i.amortizationValue,
                    'interest_value': i.interestValue,
                    'total_value': i.totalValue,
                    'remaining_balance': i.remainingBalance,
                    'due_date': i.dueDate.toIso8601String(),
                    'paid_date': i.paidDate?.toIso8601String(),
                    'created_at': i.createdAt.toIso8601String(),
                  },
                )
                .toList(),
          };

    await db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'financing',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }
}
