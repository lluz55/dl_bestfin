import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/sync/data/repositories/household_repository.dart';
import 'package:bestfin/features/sync/data/services/backend_sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/sync/domain/models/household.dart';
import 'package:bestfin/features/sync/domain/models/sync_user.dart';

// ── Backend service (singleton) ───────────────────────────────────────────────

final backendSyncServiceProvider = Provider<BackendSyncService>((ref) {
  return BackendSyncService();
});

// ── Sync service ──────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final backend = ref.watch(backendSyncServiceProvider);
  final service = SyncService(db, backend);
  ref.onDispose(service.dispose);
  return service;
});

// ── Backend setup state ───────────────────────────────────────────────────────

class BackendSetup {
  final String baseUrl;

  const BackendSetup({required this.baseUrl});

  bool get isConfigured => baseUrl.isNotEmpty;
}

final backendSetupProvider =
    AsyncNotifierProvider<BackendSetupNotifier, BackendSetup>(
      BackendSetupNotifier.new,
    );

class BackendSetupNotifier extends AsyncNotifier<BackendSetup> {
  @override
  Future<BackendSetup> build() async {
    final config = await ref.read(backendSyncServiceProvider).loadConfig();
    return BackendSetup(baseUrl: config.baseUrl);
  }

  Future<void> save(String baseUrl) async {
    await ref.read(backendSyncServiceProvider).saveConfig(baseUrl);
    ref.invalidateSelf();
  }
}

// ── Auth state ────────────────────────────────────────────────────────────────

final currentUserProvider = StreamProvider<SyncUser?>((ref) {
  final backend = ref.watch(backendSyncServiceProvider);
  return backend.authStateChanges;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(backendSyncServiceProvider).isSignedIn;
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
    // Watch pending count from DB
    ref
        .watch(databaseProvider)
        .syncQueueDao
        .watchPendingCount()
        .listen((count) => state = state.copyWith(pendingCount: count));
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
    // Reset to idle after 3s
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
