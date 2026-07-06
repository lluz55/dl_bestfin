import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/notifications/notification_service.dart';
import 'package:bestfin/core/providers/reminders_settings_provider.dart';
import 'package:bestfin/core/utils/date_formatter.dart';

/// Decide quando agendar/cancelar/disparar lembretes de notificação para
/// transações pendentes (agendadas/recorrentes) com base na antecedência
/// configurada pelo usuário.
///
/// O agendamento nativo do `flutter_local_notifications` só existe no
/// Android — o plugin Linux não implementa `zonedSchedule` (só `show`
/// imediato). Por isso toda a decisão "está na hora de avisar?" também é
/// resolvida aqui via [ScheduledReminders], e uma checagem periódica
/// ([fireDueReminders]) dispara o que já venceu — mecanismo principal no
/// Linux, rede de segurança no Android caso o alarme inexato atrase.
class ReminderScheduler {
  ReminderScheduler(this._db);

  final AppDatabase _db;

  static const _channelId = 'scheduled_transactions';
  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Transações agendadas',
      channelDescription:
          'Lembretes de transações e recorrências futuras próximas do vencimento',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    linux: LinuxNotificationDetails(),
  );

  Future<void> scheduleOne(String transactionId) async {
    final tx = await _db.transactionsDao.findTransactionById(transactionId);
    final existing = await _db.scheduledRemindersDao.findByTransactionId(
      transactionId,
    );
    final enabled = await _remindersEnabled();

    if (tx == null || !enabled || tx.isCompleted) {
      if (existing != null) await _cancelRow(existing);
      return;
    }

    final leadMinutes = await _leadTimeMinutes();
    final fireAt = tx.date.subtract(Duration(minutes: leadMinutes));

    if (existing != null &&
        existing.transactionDate.isAtSameMomentAs(tx.date) &&
        existing.leadTimeMinutes == leadMinutes) {
      return; // já agendado corretamente, nada mudou
    }

    if (existing != null) {
      await notificationsPlugin.cancel(id: existing.notificationId);
    }
    final notificationId = existing?.notificationId ?? _deriveId(transactionId);

    final now = DateTime.now();
    if (fireAt.isAfter(now)) {
      if (Platform.isAndroid) {
        await notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: _titleFor(tx),
          body: _bodyFor(tx),
          scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: transactionId,
        );
      }
      // Linux (e demais plataformas sem agendamento nativo): apenas a
      // marcação abaixo é registrada; fireDueReminders() dispara na hora
      // certa enquanto o app estiver aberto.
      await _db.scheduledRemindersDao.upsert(
        transactionId: transactionId,
        notificationId: notificationId,
        transactionDate: tx.date,
        leadTimeMinutes: leadMinutes,
        scheduledFor: fireAt,
      );
    } else {
      // A janela de antecedência já passou (ex.: item criado/editado depois
      // do horário em que o lembrete deveria disparar) — avisa na hora.
      await notificationsPlugin.show(
        id: notificationId,
        title: _titleFor(tx),
        body: _bodyFor(tx),
        notificationDetails: _notificationDetails,
        payload: transactionId,
      );
      await _db.scheduledRemindersDao.upsert(
        transactionId: transactionId,
        notificationId: notificationId,
        transactionDate: tx.date,
        leadTimeMinutes: leadMinutes,
        scheduledFor: fireAt,
      );
      await _db.scheduledRemindersDao.markFired(transactionId, now);
    }
  }

  Future<void> cancelOne(String transactionId) async {
    final existing = await _db.scheduledRemindersDao.findByTransactionId(
      transactionId,
    );
    if (existing != null) await _cancelRow(existing);
  }

  /// Reavalia todos os lembretes: agenda os que faltam, cancela os órfãos
  /// (transação concluída/excluída ou lembretes desativados) e dispara os
  /// que já venceram. Chamado na abertura do app e após mudanças de config.
  Future<void> reconcileAll() async {
    final enabled = await _remindersEnabled();
    if (!enabled) {
      final tracked = await _db.scheduledRemindersDao.allTransactionIds();
      for (final id in tracked) {
        await cancelOne(id);
      }
      return;
    }

    final candidates = await _db.transactionsDao
        .getReminderCandidateTransactionIds();
    for (final id in candidates) {
      await scheduleOne(id);
    }

    final tracked = await _db.scheduledRemindersDao.allTransactionIds();
    final candidateSet = candidates.toSet();
    for (final id in tracked) {
      if (!candidateSet.contains(id)) await cancelOne(id);
    }

    await fireDueReminders();
  }

  /// Dispara lembretes cujo horário já passou mas ainda não foram exibidos.
  Future<void> fireDueReminders() async {
    final due = await _db.scheduledRemindersDao.findDue(DateTime.now());
    for (final row in due) {
      final tx = await _db.transactionsDao.findTransactionById(
        row.transactionId,
      );
      if (tx == null || tx.isCompleted) {
        await _cancelRow(row);
        continue;
      }
      await notificationsPlugin.show(
        id: row.notificationId,
        title: _titleFor(tx),
        body: _bodyFor(tx),
        notificationDetails: _notificationDetails,
        payload: row.transactionId,
      );
      await _db.scheduledRemindersDao.markFired(
        row.transactionId,
        DateTime.now(),
      );
    }
  }

  Future<void> _cancelRow(ScheduledReminder row) async {
    await notificationsPlugin.cancel(id: row.notificationId);
    await _db.scheduledRemindersDao.deleteByTransactionId(row.transactionId);
  }

  int _deriveId(String transactionId) => transactionId.hashCode & 0x7fffffff;

  String _titleFor(Transaction tx) {
    return tx.type == 'transfer'
        ? 'Transferência agendada'
        : 'Transação agendada';
  }

  String _bodyFor(Transaction tx) {
    return '${tx.description} • ${DateFormatter.formatDate(tx.date)}';
  }

  Future<bool> _remindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kRemindersEnabledKey) ?? initialRemindersEnabled;
  }

  Future<int> _leadTimeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final days =
        prefs.getInt(kReminderLeadTimeDaysKey) ?? initialReminderLeadTimeDays;
    return days * 24 * 60;
  }
}
