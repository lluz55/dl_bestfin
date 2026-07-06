import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/scheduled_reminders.dart';

part 'scheduled_reminders_dao.g.dart';

@DriftAccessor(tables: [ScheduledReminders])
class ScheduledRemindersDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledRemindersDaoMixin {
  ScheduledRemindersDao(super.db);

  Future<ScheduledReminder?> findByTransactionId(String transactionId) {
    return (select(
      scheduledReminders,
    )..where((r) => r.transactionId.equals(transactionId))).getSingleOrNull();
  }

  Future<void> upsert({
    required String transactionId,
    required int notificationId,
    required DateTime transactionDate,
    required int leadTimeMinutes,
    required DateTime scheduledFor,
  }) {
    return into(scheduledReminders).insertOnConflictUpdate(
      ScheduledRemindersCompanion.insert(
        transactionId: transactionId,
        notificationId: notificationId,
        transactionDate: transactionDate,
        leadTimeMinutes: leadTimeMinutes,
        scheduledFor: scheduledFor,
        firedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markFired(String transactionId, DateTime firedAt) {
    return (update(scheduledReminders)
          ..where((r) => r.transactionId.equals(transactionId)))
        .write(
          ScheduledRemindersCompanion(
            firedAt: Value(firedAt),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Lembretes cujo horário já passou mas ainda não foram exibidos —
  /// necessário pois não há agendamento nativo no Linux, e serve de rede de
  /// segurança no Android caso o alarme inexato atrase.
  Future<List<ScheduledReminder>> findDue(DateTime now) {
    return (select(scheduledReminders)..where(
          (r) =>
              r.scheduledFor.isSmallerOrEqualValue(now) &
              r.firedAt.isNull(),
        ))
        .get();
  }

  Future<int> deleteByTransactionId(String transactionId) {
    return (delete(
      scheduledReminders,
    )..where((r) => r.transactionId.equals(transactionId))).go();
  }

  Future<List<String>> allTransactionIds() async {
    final rows = await select(scheduledReminders).get();
    return rows.map((r) => r.transactionId).toList();
  }
}
