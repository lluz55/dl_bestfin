import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/invoices.dart';

part 'invoices_dao.g.dart';

@DriftAccessor(tables: [Invoices])
class InvoicesDao extends DatabaseAccessor<AppDatabase>
    with _$InvoicesDaoMixin {
  InvoicesDao(AppDatabase db) : super(db);

  Stream<List<Invoice>> watchAllInvoices() {
    return select(invoices).watch();
  }

  Future<Invoice> getInvoiceById(String id) {
    return (select(invoices)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertInvoice(InvoicesCompanion invoice) {
    return into(invoices).insert(invoice);
  }

  Future<bool> updateInvoice(InvoicesCompanion invoice) {
    return update(invoices).replace(invoice);
  }

  Future<int> deleteInvoice(String id) {
    return (delete(invoices)..where((t) => t.id.equals(id))).go();
  }
}
