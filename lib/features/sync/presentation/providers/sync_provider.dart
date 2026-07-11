import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/core/constants/app_info.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/sync/data/repositories/household_repository.dart';
import 'package:bestfin/features/sync/data/services/nostr_sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';
import 'package:bestfin/features/sync/domain/models/app_update_info.dart';
import 'package:bestfin/features/sync/domain/models/household.dart';

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

// ── Peer connections ──────────────────────────────────────────────────────────

final peerConnectionsProvider = StreamProvider<DevicePresenceInfo>((ref) {
  return ref.watch(nostrSyncServiceProvider).peerConnections;
});

// ── Relay status ──────────────────────────────────────────────────────────────

final relayStatusesProvider = StreamProvider<Map<String, RelayConnectionInfo>>((
  ref,
) {
  return ref.watch(nostrSyncServiceProvider).relayStatusChanges;
});

// ── Relay list (user-configurable) ───────────────────────────────────────────

/// Configured relay URLs (custom list or defaults). Mutations persist and
/// reconnect through the NostrSyncService.
final relayListProvider =
    AsyncNotifierProvider<RelayListNotifier, List<String>>(
      RelayListNotifier.new,
    );

class RelayListNotifier extends AsyncNotifier<List<String>> {
  NostrSyncService get _service => ref.read(nostrSyncServiceProvider);

  @override
  Future<List<String>> build() => _service.loadConfiguredRelays();

  /// Adds a relay. Returns null on success, or an error message to show.
  Future<String?> addRelay(String rawUrl) async {
    final url = NostrSyncService.normalizeRelayUrl(rawUrl);
    if (url == null) {
      return 'URL inválida. Use o formato wss://seu-relay.com';
    }
    final current = state.value ?? await _service.loadConfiguredRelays();
    if (current.contains(url)) return 'Esse relay já está na lista';
    await _apply([...current, url]);
    return null;
  }

  /// Removes a relay. Returns null on success, or an error message to show.
  Future<String?> removeRelay(String url) async {
    final current = state.value ?? await _service.loadConfiguredRelays();
    if (current.length <= 1) {
      return 'Mantenha ao menos um relay para sincronizar';
    }
    await _apply(current.where((r) => r != url).toList());
    return null;
  }

  Future<void> resetToDefaults() async {
    state = const AsyncLoading();
    await _service.resetRelaysToDefaults();
    state = AsyncData(await _service.loadConfiguredRelays());
  }

  Future<void> _apply(List<String> next) async {
    state = AsyncData(next);
    await _service.updateRelays(next);
  }
}

// Read isReady directly from the service — don't use a Provider<bool> wrapper
// because Provider caches the value and won't recompute when internal mutable
// state changes (isReady depends on _masterKey which changes after loadIdentity).
bool _isIdentityReady(Ref ref) => ref.read(nostrSyncServiceProvider).isReady;

// ── Sync status ───────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final String? errorMessage;

  /// Human-readable description of the current sync step (only during syncing).
  final String? currentPhase;

  /// Items pushed in the last completed sync.
  final int? lastPushed;

  /// Items pulled in the last completed sync.
  final int? lastPulled;

  /// Total number of items to sync at the start of the current operation.
  final int syncTotal;

  /// Number of items already synced in the current operation.
  final int syncProgress;

  /// Estimated total records that will be synced (backfill + pending queue).
  final int? estimatedTotal;

  /// Cumulative ciphertext bytes transferred in the current phase (push or
  /// pull). Resets whenever the phase kind changes.
  final int syncBytes;

  /// Which direction [syncBytes]/[syncProgress] refer to. The pull phase has
  /// no known total ahead of time, so [syncKind] tells the UI whether to show
  /// a percentage bar (push) or a running byte counter (pull).
  final SyncPhaseKind syncKind;

  /// Whether the current/last sync transition was triggered automatically
  /// (background/live-subscription/periodic) rather than by the user
  /// pressing "Sincronizar agora". Only meaningful while [status] is
  /// [SyncStatus.syncing].
  final bool isBackground;

  /// True for a few seconds right after a background sync succeeds, so the
  /// Dashboard can flash a checkmark without needing a manual-sync-oriented
  /// [SyncStatus.success] transition (which would also surface in the sync
  /// settings screen on every periodic auto-sync).
  final bool backgroundJustSucceeded;

  /// Set when a background sync fails; holds a user-facing message a
  /// tappable Dashboard icon can show. Cleared as soon as the next sync
  /// (background or manual) starts.
  final String? backgroundErrorMessage;

  /// True when the last pull found records published by a peer running a
  /// newer app version — they were deferred, not applied, so this device is
  /// behind until the app is updated. Cleared automatically once a sync
  /// applies everything.
  final bool updateRequired;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSyncAt,
    this.errorMessage,
    this.currentPhase,
    this.lastPushed,
    this.lastPulled,
    this.syncTotal = 0,
    this.syncProgress = 0,
    this.estimatedTotal,
    this.syncBytes = 0,
    this.syncKind = SyncPhaseKind.other,
    this.isBackground = false,
    this.backgroundJustSucceeded = false,
    this.backgroundErrorMessage,
    this.updateRequired = false,
  });

  double get syncPercent =>
      syncTotal > 0 ? (syncProgress / syncTotal).clamp(0.0, 1.0) : 0.0;

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncAt,
    String? errorMessage,
    String? currentPhase,
    int? lastPushed,
    int? lastPulled,
    int? syncTotal,
    int? syncProgress,
    int? estimatedTotal,
    int? syncBytes,
    SyncPhaseKind? syncKind,
    bool? isBackground,
    bool? backgroundJustSucceeded,
    String? backgroundErrorMessage,
    bool? updateRequired,
    bool clearError = false,
    bool clearPhase = false,
    bool clearResults = false,
    bool clearProgress = false,
    bool clearBackgroundError = false,
  }) => SyncState(
    status: status ?? this.status,
    pendingCount: pendingCount ?? this.pendingCount,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    currentPhase: clearPhase ? null : (currentPhase ?? this.currentPhase),
    lastPushed: clearResults ? null : (lastPushed ?? this.lastPushed),
    lastPulled: clearResults ? null : (lastPulled ?? this.lastPulled),
    syncTotal: clearProgress ? 0 : (syncTotal ?? this.syncTotal),
    syncProgress: clearProgress ? 0 : (syncProgress ?? this.syncProgress),
    estimatedTotal: clearProgress
        ? null
        : (estimatedTotal ?? this.estimatedTotal),
    syncBytes: clearProgress ? 0 : (syncBytes ?? this.syncBytes),
    syncKind: clearProgress ? SyncPhaseKind.other : (syncKind ?? this.syncKind),
    isBackground: isBackground ?? this.isBackground,
    backgroundJustSucceeded:
        backgroundJustSucceeded ?? this.backgroundJustSucceeded,
    backgroundErrorMessage: clearBackgroundError
        ? null
        : (backgroundErrorMessage ?? this.backgroundErrorMessage),
    updateRequired: updateRequired ?? this.updateRequired,
  );
}

final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(
  SyncStateNotifier.new,
);

class SyncStateNotifier extends Notifier<SyncState> {
  // Foreground poll interval. Now just a safety net — the live Nostr
  // subscription (see NostrSyncService.startLiveSync) is what actually
  // catches remote changes within seconds, so this no longer needs to be
  // aggressive.
  static const _activeInterval = Duration(minutes: 1);

  // While backgrounded, the live subscription's socket may be suspended by
  // the OS anyway, so there's little to gain from polling often — fall back
  // to a much longer interval to save battery/data until the app resumes
  // (which already triggers an immediate sync in main.dart).
  static const _backgroundInterval = Duration(minutes: 10);

  // Debounce delay after a transaction is enqueued before triggering sync.
  static const _debounceDelay = Duration(seconds: 3);

  Duration _currentInterval = _activeInterval;
  Timer? _periodicTimer;
  Timer? _debounceTimer;

  // Background syncs fail silently (no inline UI to show an error in), so a
  // one-off notification is emitted here instead. Counting consecutive
  // failures — rather than notifying on every one — keeps a flaky network
  // from spamming a snackbar every periodic tick (e.g. every 60s).
  int _consecutiveBackgroundFailures = 0;
  final _backgroundErrorsController = StreamController<String>.broadcast();
  Stream<String> get backgroundErrors => _backgroundErrorsController.stream;

  @override
  SyncState build() {
    // Listen to pendingSyncCountProvider to trigger debounced sync on increments
    ref.listen<AsyncValue<int>>(pendingSyncCountProvider, (prev, next) {
      final prevCount = prev?.value ?? 0;
      final nextCount = next.value ?? 0;

      if (nextCount > prevCount && nextCount > 0) {
        _scheduleDebouncedSync();
      }

      state = state.copyWith(pendingCount: nextCount);
    });

    // Start the periodic background sync (safety net; see _activeInterval).
    _startPeriodicSync();

    // React to remote changes within seconds instead of waiting for the next
    // periodic tick, once identity is ready.
    final liveSub = ref
        .watch(nostrSyncServiceProvider)
        .liveEvents
        .listen((_) => _scheduleDebouncedSync());
    _startLiveSyncWhenReady();

    // Identity may still be loading asynchronously when this notifier is
    // built (e.g. on app cold start) — start the live subscription as soon
    // as it becomes available rather than only once here.
    ref.listen<AsyncValue<SyncIdentity?>>(currentIdentityProvider, (
      prev,
      next,
    ) {
      if (next.value != null) _startLiveSyncWhenReady();
    });

    ref.onDispose(() {
      _periodicTimer?.cancel();
      _debounceTimer?.cancel();
      _backgroundErrorsController.close();
      liveSub.cancel();
    });

    _loadLastSync();
    return const SyncState();
  }

  Future<void> _startLiveSyncWhenReady() async {
    if (!_isIdentityReady(ref)) return;
    try {
      await ref.read(nostrSyncServiceProvider).startLiveSync();
    } catch (e) {
      debugPrint('[Sync] Falha ao iniciar live subscription: $e');
    }
  }

  void _reportBackgroundFailure(String message) {
    _consecutiveBackgroundFailures++;
    if (_consecutiveBackgroundFailures == 1 &&
        !_backgroundErrorsController.isClosed) {
      _backgroundErrorsController.add(message);
    }
  }

  Future<void> _loadLastSync() async {
    final at = await ref.read(syncServiceProvider).getLastSyncAt();
    if (at != null) state = state.copyWith(lastSyncAt: at);
  }

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _scheduleNextPeriodicTick();
  }

  // Self-rescheduling instead of Timer.periodic so each tick can carry its
  // own jitter (±10%) — without this, every device on the same identity
  // that started syncing around the same time would keep polling relays in
  // lockstep indefinitely.
  void _scheduleNextPeriodicTick() {
    final jitterMs = (_currentInterval.inMilliseconds * 0.1).round();
    final jitter = jitterMs > 0
        ? Duration(milliseconds: Random().nextInt(jitterMs * 2) - jitterMs)
        : Duration.zero;
    final delay = _currentInterval + jitter;
    _periodicTimer = Timer(delay, () {
      _backgroundSync();
      _scheduleNextPeriodicTick();
    });
  }

  /// Switches the periodic safety-net poll to a longer interval to save
  /// battery/data while the app is backgrounded. Called from main.dart's
  /// app-lifecycle observer.
  void onAppPaused() {
    _currentInterval = _backgroundInterval;
    _startPeriodicSync();
  }

  /// Restores the active (short) poll interval. Called from main.dart's
  /// app-lifecycle observer on resume, alongside its own immediate sync.
  void onAppResumed() {
    _currentInterval = _activeInterval;
    _startPeriodicSync();
    _startLiveSyncWhenReady();
  }

  void _scheduleDebouncedSync() {
    if (state.status == SyncStatus.syncing) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _backgroundSync);
  }

  // Silent background sync — does not block the manual sync button.
  Future<void> _backgroundSync() async {
    if (!_isIdentityReady(ref)) return;
    if (state.status == SyncStatus.syncing) return;
    await syncNow(background: true);
  }

  /// Runs a full bidirectional sync. [background] suppresses the syncing
  /// indicator so the UI button stays usable during auto-sync.
  Future<void> syncNow({bool background = false}) async {
    if (!_isIdentityReady(ref)) {
      if (!background) {
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Identidade não configurada',
          clearPhase: true,
        );
        await _resetToIdleAfterDelay();
      }
      return;
    }

    if (state.status == SyncStatus.syncing) return;

    // Snapshot pending count before starting so the progress bar has a total.
    final pendingBefore = state.pendingCount;

    state = state.copyWith(
      status: SyncStatus.syncing,
      currentPhase: background ? null : 'Iniciando...',
      clearError: true,
      syncTotal: pendingBefore > 0 ? pendingBefore : 0,
      syncProgress: 0,
      isBackground: background,
      backgroundJustSucceeded: false,
      clearBackgroundError: true,
    );

    SyncResult result;
    try {
      result = await ref
          .read(syncServiceProvider)
          .syncNow(
            onProgress: background
                ? null
                : (progress) {
                    state = state.copyWith(
                      currentPhase: progress.phase,
                      syncProgress: progress.itemsDone,
                      syncTotal: progress.itemsTotal,
                      syncBytes: progress.bytesDone,
                      syncKind: progress.kind,
                    );
                  },
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      debugPrint('[Sync] syncNow() excedeu 90s');
      if (!background) {
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Tempo limite excedido ao conectar aos relays',
          clearPhase: true,
          clearProgress: true,
        );
        await _resetToIdleAfterDelay();
      } else {
        const message = 'Tempo limite excedido ao conectar aos relays';
        _reportBackgroundFailure(message);
        state = state.copyWith(
          status: SyncStatus.idle,
          clearProgress: true,
          backgroundErrorMessage: message,
        );
      }
      return;
    } catch (e, st) {
      debugPrint('[Sync] Erro inesperado em syncNow: $e\n$st');
      if (!background) {
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: 'Erro ao sincronizar',
          clearPhase: true,
          clearProgress: true,
        );
        await _resetToIdleAfterDelay();
      } else {
        const message = 'Erro ao sincronizar em segundo plano';
        _reportBackgroundFailure(message);
        state = state.copyWith(
          status: SyncStatus.idle,
          clearProgress: true,
          backgroundErrorMessage: message,
        );
      }
      return;
    }

    final now = DateTime.now();

    if (result.success) {
      _consecutiveBackgroundFailures = 0;
      final totalItems = result.pushed + result.pulled;
      state = state.copyWith(
        status: background ? SyncStatus.idle : SyncStatus.success,
        lastSyncAt: now,
        lastPushed: result.pushed,
        lastPulled: result.pulled,
        clearPhase: true,
        clearError: true,
        syncProgress: totalItems,
        syncTotal: totalItems,
        backgroundJustSucceeded: background,
        updateRequired: result.deferred > 0,
      );
      if (background) unawaited(_clearBackgroundSuccessAfterDelay());
    } else if (result == SyncResult.alreadyRunning) {
      if (!background) state = state.copyWith(status: SyncStatus.idle);
      return;
    } else {
      if (!background) {
        state = state.copyWith(
          status: SyncStatus.error,
          errorMessage: result.errorMessage,
          clearPhase: true,
          clearProgress: true,
        );
      } else {
        final message =
            result.errorMessage ?? 'Erro ao sincronizar em segundo plano';
        _reportBackgroundFailure(message);
        state = state.copyWith(
          status: SyncStatus.idle,
          clearProgress: true,
          backgroundErrorMessage: message,
        );
      }
    }

    if (!background) await _resetToIdleAfterDelay();
  }

  Future<void> _resetToIdleAfterDelay() async {
    await Future.delayed(const Duration(seconds: 4));
    if (state.status != SyncStatus.syncing) {
      state = state.copyWith(status: SyncStatus.idle, clearPhase: true);
    }
  }

  Future<void> _clearBackgroundSuccessAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    if (state.status != SyncStatus.syncing) {
      state = state.copyWith(backgroundJustSucceeded: false);
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

/// Emits an error message the first time a *background* sync fails after a
/// success (or after startup) — a global listener (e.g. in main.dart) can
/// surface this as a snackbar, since background syncs have no inline UI of
/// their own to show an error in.
final syncBackgroundErrorsProvider = StreamProvider<String>((ref) {
  return ref.watch(syncStateProvider.notifier).backgroundErrors;
});

// ── App update notifications ──────────────────────────────────────────────────

/// Persists and exposes the latest available app update.
///
/// On build, loads any previously received update from SharedPreferences so
/// the banner and the Settings tile survive app restarts. When the Nostr
/// listener delivers a newer version it is saved automatically. The update
/// stays stored until the user explicitly dismisses it (via [clearUpdate])
/// or until the installed version already matches or exceeds it (stale on
/// next load).
final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateNotifier, AppUpdateInfo?>(
      AppUpdateNotifier.new,
    );

class AppUpdateNotifier extends AsyncNotifier<AppUpdateInfo?> {
  static const _prefKey = 'bestfin_pending_update';

  @override
  Future<AppUpdateInfo?> build() async {
    // Load persisted update first so the UI shows it before Nostr connects.
    final persisted = await _loadPersisted();

    // Start the Nostr listener and wire up incoming events.
    final service = ref.read(nostrSyncServiceProvider);
    unawaited(Future.microtask(service.startUpdateListener));
    final sub = service.appUpdateEvents.listen(_onUpdateReceived);
    ref.onDispose(sub.cancel);

    return persisted;
  }

  Future<AppUpdateInfo?> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return null;
      final info = AppUpdateInfo.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!info.isNewerThan(kAppVersion)) {
        // Already on this version or newer — clean up stale entry.
        await prefs.remove(_prefKey);
        return null;
      }
      return info;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onUpdateReceived(AppUpdateInfo info) async {
    if (!info.isNewerThan(kAppVersion)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(info.toJson()));
    } catch (_) {}
    state = AsyncData(info);
  }

  /// Permanently removes the stored update (user chose to download or ignore).
  Future<void> clearUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
    state = const AsyncData(null);
  }
}
