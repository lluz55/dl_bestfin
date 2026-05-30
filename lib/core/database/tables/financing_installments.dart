import 'package:drift/drift.dart';
import 'financings.dart';

@TableIndex(
  name: 'financing_installments_financing_idx',
  columns: {#financingId},
)
@DataClassName('FinancingInstallment')
class FinancingInstallments extends Table {
  TextColumn get id => text()();
  TextColumn get financingId =>
      text().references(Financings, #id, onDelete: KeyAction.cascade)();
  IntColumn get number => integer()();
  IntColumn get amortizationValue => integer()(); // in cents
  IntColumn get interestValue => integer()(); // in cents
  IntColumn get totalValue => integer()(); // in cents
  IntColumn get remainingBalance => integer()(); // in cents
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get paidDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
