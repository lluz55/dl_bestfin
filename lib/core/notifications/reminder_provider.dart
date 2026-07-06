import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/notifications/reminder_scheduler.dart';

final reminderReconcileProvider = FutureProvider<void>((ref) {
  final db = ref.watch(databaseProvider);
  return ReminderScheduler(db).reconcileAll();
});
