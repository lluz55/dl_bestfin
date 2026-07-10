import 'package:drift/drift.dart';
import 'categories.dart';
import 'credit_cards.dart';
import 'entities.dart';
import 'goals.dart';
import 'invoices.dart';

@TableIndex(
  name: 'transactions_confirmed_date_idx',
  columns: {#isConfirmed, #date},
)
@TableIndex(name: 'transactions_category_idx', columns: {#categoryId})
@TableIndex(name: 'transactions_entity_idx', columns: {#entityId})
@TableIndex(name: 'transactions_goal_idx', columns: {#goalId})
@TableIndex(name: 'transactions_group_idx', columns: {#groupId})
@DataClassName('Transaction')
class Transactions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().withLength(min: 1, max: 255)();
  TextColumn get type => text()(); // income, expense, transfer
  TextColumn get sentiment =>
      text().nullable()(); // positive, neutral, negative
  TextColumn get notes => text().nullable()();
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get entityId => text().nullable().references(
    Entities,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get goalId =>
      text().nullable().references(Goals, #id, onDelete: KeyAction.setNull)();
  TextColumn get installmentPlanId => text().nullable()();
  IntColumn get installmentNumber => integer().nullable()();
  TextColumn get recurringRuleId => text().nullable()();
  // Agrupa vários lançamentos criados juntos ("Inserir vários" agrupado) em um
  // único bloco: compartilham este id e são exibidos como uma transação só,
  // revelando o valor total. null = lançamento avulso.
  TextColumn get groupId => text().nullable()();
  TextColumn get creditCardId => text().nullable().references(
    CreditCards,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get rawAmount =>
      integer().nullable()(); // centavos; preenchido quando não há entries (CC)
  TextColumn get invoiceId => text().nullable().references(
    Invoices,
    #id,
    onDelete: KeyAction.setNull,
  )();

  BoolColumn get isSplit => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(true))();
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(true))();
  TextColumn get source =>
      text().nullable()(); // 'notification', 'manual', etc.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
