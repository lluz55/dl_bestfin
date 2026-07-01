import 'package:drift/drift.dart';
import 'transactions.dart';
import 'categories.dart';

/// Porções de uma transação dividida entre múltiplas categorias.
/// Ativa quando transactions.is_split = true.
/// Invariante: SUM(amount) deve igualar o total da transação pai.
@DataClassName('TransactionSplit')
class TransactionSplits extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get amount => integer()(); // centavos desta porção
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
