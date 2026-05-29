import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/notifications/data/repositories/notification_repository.dart';
import 'package:bestfin/features/notifications/data/services/android_notification_service.dart';
import 'package:bestfin/features/notifications/data/services/linux_notification_service.dart';
import 'package:bestfin/features/notifications/domain/models/notification_pattern.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return NotificationRepositoryImpl(database);
});

// ── Patterns ──────────────────────────────────────────────────────────────────

final allPatternsProvider = StreamProvider<List<NotificationPatternModel>>((
  ref,
) {
  return ref.watch(notificationRepositoryProvider).watchAllPatterns();
});

final enabledPatternsProvider = StreamProvider<List<NotificationPatternModel>>((
  ref,
) {
  return ref.watch(notificationRepositoryProvider).watchEnabledPatterns();
});

// ── Suggested Transactions ────────────────────────────────────────────────────

final suggestedTransactionsProvider = StreamProvider<List<TransactionModel>>((
  ref,
) {
  return ref.watch(transactionRepositoryProvider).watchSuggestedTransactions();
});

// ── Android Service ───────────────────────────────────────────────────────────

final androidNotificationServiceProvider = Provider<AndroidNotificationService>(
  (ref) {
    final service = AndroidNotificationService();
    ref.onDispose(service.dispose);
    return service;
  },
);

// ── Linux Service ─────────────────────────────────────────────────────────────

final linuxNotificationServiceProvider = Provider<LinuxNotificationService>((
  ref,
) {
  final service = LinuxNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

// ── Permission state (Android) ────────────────────────────────────────────────

final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return false;
  final service = ref.watch(androidNotificationServiceProvider);
  return service.isPermissionGranted();
});

// ── Actions ───────────────────────────────────────────────────────────────────

final confirmSuggestionProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (String id) async {
    await ref.read(transactionRepositoryProvider).confirmSuggestion(id);
  };
});

final discardSuggestionProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (String id) async {
    await ref.read(transactionRepositoryProvider).deleteTransaction(id);
  };
});

final togglePatternProvider = Provider<Future<void> Function(String, bool)>((
  ref,
) {
  return (String id, bool enabled) async {
    await ref.read(notificationRepositoryProvider).togglePattern(id, enabled);
  };
});

final deletePatternProvider = Provider<Future<void> Function(String)>((ref) {
  return (String id) async {
    await ref.read(notificationRepositoryProvider).deletePattern(id);
  };
});

final savePatternProvider =
    Provider<Future<void> Function(NotificationPatternModel)>((ref) {
      return (NotificationPatternModel pattern) async {
        await ref.read(notificationRepositoryProvider).upsertPattern(pattern);
      };
    });
