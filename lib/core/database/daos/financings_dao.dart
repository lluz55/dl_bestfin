import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/financings.dart';
import '../tables/financing_installments.dart';

part 'financings_dao.g.dart';

@DriftAccessor(tables: [Financings, FinancingInstallments])
class FinancingsDao extends DatabaseAccessor<AppDatabase>
    with _$FinancingsDaoMixin {
  FinancingsDao(AppDatabase db) : super(db);

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
}
