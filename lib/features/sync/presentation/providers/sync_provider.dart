import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/sync/data/repositories/household_repository.dart';
import 'package:bestfin/features/sync/data/services/supabase_service.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/sync/domain/models/household.dart';
import 'package:bestfin/features/sync/domain/models/sync_user.dart';

// ── Supabase service (singleton) ──────────────────────────────────────────────

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

// ── Sync service ──────────────────────────────────────────────────────────────

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final supabase = ref.watch(supabaseServiceProvider);
  final service = SyncService(db, supabase);
  ref.onDispose(service.dispose);
  return service;
});

// ── Supabase setup state ──────────────────────────────────────────────────────

class SupabaseSetup {
  final String url;
  final String anonKey;

  const SupabaseSetup({required this.url, required this.anonKey});

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

final supabaseSetupProvider =
    AsyncNotifierProvider<SupabaseSetupNotifier, SupabaseSetup>(
      SupabaseSetupNotifier.new,
    );

class SupabaseSetupNotifier extends AsyncNotifier<SupabaseSetup> {
  static const _urlKey = 'supabase_url';
  static const _keyKey = 'supabase_anon_key';

  @override
  Future<SupabaseSetup> build() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey) ?? '';
    final key = prefs.getString(_keyKey) ?? '';
    final setup = SupabaseSetup(url: url, anonKey: key);

    // Auto-initialize if configured
    if (setup.isConfigured) {
      final service = ref.read(supabaseServiceProvider);
      if (!service.isInitialized) {
        await service.initialize(url: url, anonKey: key);
      }
    }

    return setup;
  }

  Future<void> save(String url, String anonKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
    await prefs.setString(_keyKey, anonKey);

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      await ref
          .read(supabaseServiceProvider)
          .initialize(url: url, anonKey: anonKey);
    }

    ref.invalidateSelf();
  }
}

// ── Auth state ────────────────────────────────────────────────────────────────

final currentUserProvider = StreamProvider<SyncUser?>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return supabase.authStateChanges;
});

final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(supabaseServiceProvider).isSignedIn;
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
