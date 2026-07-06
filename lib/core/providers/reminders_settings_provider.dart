import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReminderLeadTime {
  sameDay(0, 'No dia'),
  oneDay(1, '1 dia antes'),
  twoDays(2, '2 dias antes'),
  threeDays(3, '3 dias antes'),
  oneWeek(7, '1 semana antes');

  final int days;
  final String label;

  const ReminderLeadTime(this.days, this.label);

  Duration get duration => Duration(days: days);

  static ReminderLeadTime fromDays(int days) => ReminderLeadTime.values
      .firstWhere((e) => e.days == days, orElse: () => ReminderLeadTime.oneDay);
}

const kRemindersEnabledKey = 'reminders_enabled';
const kReminderLeadTimeDaysKey = 'reminder_lead_time_days';

bool initialRemindersEnabled = true;
int initialReminderLeadTimeDays = ReminderLeadTime.oneDay.days;

class RemindersEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => initialRemindersEnabled;

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kRemindersEnabledKey, value);
  }
}

final remindersEnabledProvider = NotifierProvider<RemindersEnabledNotifier, bool>(
  RemindersEnabledNotifier.new,
);

class ReminderLeadTimeNotifier extends Notifier<ReminderLeadTime> {
  @override
  ReminderLeadTime build() =>
      ReminderLeadTime.fromDays(initialReminderLeadTimeDays);

  Future<void> set(ReminderLeadTime value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kReminderLeadTimeDaysKey, value.days);
  }
}

final reminderLeadTimeProvider =
    NotifierProvider<ReminderLeadTimeNotifier, ReminderLeadTime>(
      ReminderLeadTimeNotifier.new,
    );
