import 'package:drift/drift.dart';

/// Tabela de controle de streaks (sequências).
/// [type]: 'recording' (dias seguidos registrando) | 'budget' (dias seguidos sob orçamento)
@DataClassName('Streak')
class Streaks extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'recording' | 'budget'
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
  IntColumn get longestCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
