import 'package:drift/drift.dart';
import 'categories.dart';
import 'accounts.dart';

@TableIndex(
  name: 'notification_patterns_category_idx',
  columns: {#defaultCategoryId},
)
@TableIndex(
  name: 'notification_patterns_account_idx',
  columns: {#defaultAccountId},
)
@DataClassName('NotificationPattern')
class NotificationPatterns extends Table {
  TextColumn get id => text()();
  TextColumn get bankName => text().withDefault(const Constant(''))();
  TextColumn get regexPattern => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get defaultCategoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get defaultAccountId => text().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
