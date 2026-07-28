import 'package:drift/drift.dart';
import 'package:bestfin/core/database/tables/transactions.dart';

@TableIndex(
  name: 'installment_plans_origin_transaction_idx',
  columns: {#originTransactionId},
)
@DataClassName('InstallmentPlan')
class InstallmentPlans extends Table {
  TextColumn get id => text()();
  TextColumn get originTransactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get totalInstallments => integer()();
  IntColumn get installmentValue => integer()(); // in cents
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
