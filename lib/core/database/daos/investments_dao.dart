import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/investments.dart';

part 'investments_dao.g.dart';

@DriftAccessor(tables: [Investments])
class InvestmentsDao extends DatabaseAccessor<AppDatabase>
    with _$InvestmentsDaoMixin {
  InvestmentsDao(AppDatabase db) : super(db);

  Stream<List<Investment>> watchAllInvestments() {
    return select(investments).watch();
  }

  Future<Investment> getInvestmentById(String id) {
    return (select(investments)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Investment?> getInvestmentByIdOrNull(String id) {
    return (select(
      investments,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertInvestment(InvestmentsCompanion investment) async {
    final res = await into(investments).insert(investment);
    await _enqueueInvestmentSync(investment.id.value, 'insert');
    return res;
  }

  Future<bool> updateInvestment(InvestmentsCompanion investment) async {
    final res = await update(investments).replace(investment);
    await _enqueueInvestmentSync(investment.id.value, 'update');
    return res;
  }

  Future<int> deleteInvestment(String id) async {
    await _enqueueInvestmentSync(id, 'delete');
    return (delete(investments)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _enqueueInvestmentSync(String id, String operation) async {
    final investment = await getInvestmentByIdOrNull(id);

    final payload = investment == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': investment.id,
            'name': investment.name,
            'type': investment.type,
            'invested_amount': investment.investedAmount,
            'current_yield': investment.currentYield,
            'maturity_date': investment.maturityDate?.toIso8601String(),
            'created_at': investment.createdAt.toIso8601String(),
            'updated_at': investment.updatedAt.toIso8601String(),
          };

    await db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'investment',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }
}
