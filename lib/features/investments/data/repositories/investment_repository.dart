import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/investments/domain/models/investment.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class InvestmentRepository {
  Stream<List<Investment>> watchAllInvestments();
  Future<Investment> getInvestmentById(String id);
  Future<void> createInvestment({
    required String name,
    required String type,
    required int investedAmount,
    required int currentYield,
    DateTime? maturityDate,
  });
  Future<void> updateYield(String id, int currentYield);
  Future<void> updateInvestment({
    required String id,
    required String name,
    required String type,
    required int investedAmount,
    required int currentYield,
    DateTime? maturityDate,
  });
  Future<void> deleteInvestment(String id);
}

class InvestmentRepositoryImpl implements InvestmentRepository {
  final db.AppDatabase _database;

  InvestmentRepositoryImpl(this._database);

  @override
  Stream<List<Investment>> watchAllInvestments() {
    return _database.investmentsDao.watchAllInvestments().map((list) {
      return list.map((item) => Investment.fromDb(item)).toList();
    });
  }

  @override
  Future<Investment> getInvestmentById(String id) async {
    final dbInvestment = await _database.investmentsDao.getInvestmentById(id);
    return Investment.fromDb(dbInvestment);
  }

  @override
  Future<void> createInvestment({
    required String name,
    required String type,
    required int investedAmount,
    required int currentYield,
    DateTime? maturityDate,
  }) async {
    final id = const Uuid().v4();
    await _database.investmentsDao.insertInvestment(
      db.InvestmentsCompanion.insert(
        id: id,
        name: name,
        type: type,
        investedAmount: investedAmount,
        currentYield: Value(currentYield),
        maturityDate: Value(maturityDate),
      ),
    );
  }

  @override
  Future<void> updateYield(String id, int currentYield) async {
    final existing = await _database.investmentsDao.getInvestmentById(id);
    await _database.investmentsDao.updateInvestment(
      db.InvestmentsCompanion(
        id: Value(id),
        name: Value(existing.name),
        type: Value(existing.type),
        investedAmount: Value(existing.investedAmount),
        currentYield: Value(currentYield),
        maturityDate: Value(existing.maturityDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> updateInvestment({
    required String id,
    required String name,
    required String type,
    required int investedAmount,
    required int currentYield,
    DateTime? maturityDate,
  }) async {
    await _database.investmentsDao.updateInvestment(
      db.InvestmentsCompanion(
        id: Value(id),
        name: Value(name),
        type: Value(type),
        investedAmount: Value(investedAmount),
        currentYield: Value(currentYield),
        maturityDate: Value(maturityDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteInvestment(String id) async {
    await _database.investmentsDao.deleteInvestment(id);
  }
}
