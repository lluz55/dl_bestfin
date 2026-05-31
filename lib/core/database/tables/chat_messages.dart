import 'package:drift/drift.dart';

@DataClassName('ChatMessageRow')
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get role => text()(); // 'user' | 'assistant'
  TextColumn get content => text()();
  BlobColumn get imageBytes => blob().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
