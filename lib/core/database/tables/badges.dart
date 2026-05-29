import 'package:drift/drift.dart';

/// Tabela de Conquistas/Medalhas (Badges).
@DataClassName('Badge')
class Badges extends Table {
  TextColumn get id => text()();
  TextColumn get badgeKey => text().customConstraint('UNIQUE')(); // ex: 'first_transaction'
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get description => text()();
  DateTimeColumn get unlockedAt => dateTime().nullable()();
  TextColumn get iconAsset => text()();

  @override
  Set<Column> get primaryKey => {id};
}
