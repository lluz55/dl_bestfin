import 'package:drift/drift.dart';
import 'package:bestfin/core/database/tables/accounts.dart';

/// Registro de reconciliação: snapshot do saldo confirmado em uma data.
@DataClassName('ReconciliationCheckpoint')
class ReconciliationCheckpoints extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get statementBalance => integer()(); // centavos — saldo no extrato
  DateTimeColumn get date => dateTime()();
  IntColumn get entriesCount =>
      integer()(); // quantas entries foram reconciliadas
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
