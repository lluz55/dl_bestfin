import 'package:drift/drift.dart';
import 'package:bestfin/core/database/tables/transactions.dart';

@TableIndex(name: 'attachments_transaction_idx', columns: {#transactionId})
@DataClassName('Attachment')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  TextColumn get fileType => text()(); // image, pdf
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
