import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/sync/data/repositories/household_repository.dart';
import 'package:bestfin/features/sync/data/services/nostr_sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/sync/domain/models/household.dart';
import 'package:bestfin/features/sync/domain/models/sync_identity.dart';

// ── Nostr transport (singleton) ───────────────────────────────────────────────

final nostrSyncServiceProvider = Provider<NostrSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = NostrSyncService(db);
  ref.onDispose(service.dispose);
  return service;
});

// ── Sync service ──────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final transport = ref.watch(nostrSyncServiceProvider);
  final service = SyncService(db, transport);
  ref.onDispose(service.dispose);
  return service;
});

// ── Identity state ────────────────────────────────────────────────────────────

final currentIdentityProvider = StreamProvider<SyncIdentity?>((ref) {
  return ref.watch(nostrSyncServiceProvider).identityChanges;
});

final isIdentityReadyProvider = Provider<bool>((ref) {
  return ref.watch(nostrSyncServiceProvider).isReady;
});

// ── Sync status ───────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSyncAt,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncAt,
    String? errorMessage,
  }) => SyncState(
    status: status ?? this.status,
    pendingCount: pendingCount ?? this.pendingCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    errorMessage: errorMessage,
  );
}

final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(
  SyncStateNotifier.new,
);

class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    final pendingSub = ref
        .watch(databaseProvider)
        .syncQueueDao
        .watchPendingCount()
        .listen((count) => state = state.copyWith(pendingCount: count));
    ref.onDispose(pendingSub.cancel);
    _loadLastSync();
    return const SyncState();
  }

  Future<void> _loadLastSync() async {
    final at = await ref.read(syncServiceProvider).getLastSyncAt();
    if (at != null) state = state.copyWith(lastSyncAt: at);
  }

  Future<void> syncNow() async {
    state = state.copyWith(status: SyncStatus.syncing);
    final result = await ref.read(syncServiceProvider).syncNow();
    if (result.success) {
      state = state.copyWith(
        status: SyncStatus.success,
        lastSyncAt: DateTime.now(),
      );
    } else {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: result.errorMessage,
      );
    }
    await Future.delayed(const Duration(seconds: 3));
    if (state.status != SyncStatus.syncing) {
      state = state.copyWith(status: SyncStatus.idle);
    }
  }
}

// ── Household ─────────────────────────────────────────────────────────────────

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HouseholdRepositoryImpl(db);
});

final householdsProvider = StreamProvider<List<HouseholdModel>>((ref) {
  return ref.watch(householdRepositoryProvider).watchAll();
});

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).syncQueueDao.watchPendingCount();
});
