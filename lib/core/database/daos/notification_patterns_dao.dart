import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/notification_patterns.dart';

part 'notification_patterns_dao.g.dart';

@DriftAccessor(tables: [NotificationPatterns])
class NotificationPatternsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationPatternsDaoMixin {
  NotificationPatternsDao(AppDatabase db) : super(db);

  Stream<List<NotificationPattern>> watchAllNotificationPatterns() {
    return select(notificationPatterns).watch();
  }

  Stream<List<NotificationPattern>> watchEnabledNotificationPatterns() {
    return (select(
      notificationPatterns,
    )..where((t) => t.isEnabled.equals(true))).watch();
  }

  Future<void> togglePattern(String id, bool enabled) async {
    await (update(notificationPatterns)..where((t) => t.id.equals(id))).write(
      NotificationPatternsCompanion(isEnabled: Value(enabled)),
    );
  }

  Future<NotificationPattern> getNotificationPatternById(String id) {
    return (select(
      notificationPatterns,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertNotificationPattern(NotificationPatternsCompanion pattern) {
    return into(notificationPatterns).insert(pattern);
  }

  Future<bool> updateNotificationPattern(
    NotificationPatternsCompanion pattern,
  ) {
    return update(notificationPatterns).replace(pattern);
  }

  Future<int> deleteNotificationPattern(String id) {
    return (delete(notificationPatterns)..where((t) => t.id.equals(id))).go();
  }
}
