import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/notifications/domain/models/notification_pattern.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class NotificationRepository {
  Stream<List<NotificationPatternModel>> watchAllPatterns();
  Stream<List<NotificationPatternModel>> watchEnabledPatterns();
  Future<void> upsertPattern(NotificationPatternModel pattern);
  Future<void> deletePattern(String id);
  Future<void> togglePattern(String id, bool enabled);
}

class NotificationRepositoryImpl implements NotificationRepository {
  final db.AppDatabase _database;

  NotificationRepositoryImpl(this._database);

  @override
  Stream<List<NotificationPatternModel>> watchAllPatterns() {
    return _database.notificationPatternsDao.watchAllNotificationPatterns().map(
      (list) => list.map(NotificationPatternModel.fromDb).toList(),
    );
  }

  @override
  Stream<List<NotificationPatternModel>> watchEnabledPatterns() {
    return _database.notificationPatternsDao
        .watchEnabledNotificationPatterns()
        .map((list) => list.map(NotificationPatternModel.fromDb).toList());
  }

  @override
  Future<void> upsertPattern(NotificationPatternModel pattern) async {
    await _database
        .into(_database.notificationPatterns)
        .insertOnConflictUpdate(
          db.NotificationPatternsCompanion(
            id: Value(pattern.id.isEmpty ? const Uuid().v4() : pattern.id),
            bankName: Value(pattern.bankName),
            regexPattern: Value(pattern.regexPattern),
            isEnabled: Value(pattern.isEnabled),
            defaultCategoryId: Value(pattern.defaultCategoryId),
            defaultAccountId: Value(pattern.defaultAccountId),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> deletePattern(String id) async {
    await _database.notificationPatternsDao.deleteNotificationPattern(id);
  }

  @override
  Future<void> togglePattern(String id, bool enabled) async {
    await _database.notificationPatternsDao.togglePattern(id, enabled);
  }
}
