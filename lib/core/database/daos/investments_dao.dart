import 'package:drift/drift.dart';
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

  Future<int> insertInvestment(InvestmentsCompanion investment) {
    return into(investments).insert(investment);
  }

  Future<bool> updateInvestment(InvestmentsCompanion investment) {
    return update(investments).replace(investment);
  }

  Future<int> deleteInvestment(String id) {
    return (delete(investments)..where((t) => t.id.equals(id))).go();
  }
}
