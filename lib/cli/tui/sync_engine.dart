import 'dart:async';

import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';

/// Estado da sincronização residente da TUI — espelha o `SyncState` da GUI
/// sem Riverpod: mesma informação, consumida pela linha de status e pela
/// tela de Sincronização.
class TuiSyncState {
  const TuiSyncState({
    this.status = TuiSyncStatus.idle,
    this.hasIdentity = false,
    this.pendingCount = 0,
    this.lastSyncAt,
    this.lastPushed = 0,
    this.lastPulled = 0,
    this.lastFailed = 0,
    this.lastDeferred = 0,
    this.updateRequired = false,
    this.errorMessage,
    this.notice,
  });

  final TuiSyncStatus status;
  final bool hasIdentity;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final int lastPushed;
  final int lastPulled;
  final int lastFailed;
  final int lastDeferred;

  /// Registros adiados por serem de uma versão mais nova do app —
  /// o usuário precisa atualizar para recebê-los.
  final bool updateRequired;

  /// Último erro de sync de background (o manual reporta direto na tela).
  final String? errorMessage;

  /// Aviso discreto e transitório: "+N de outro dispositivo", falhas
  /// consecutivas agrupadas, etc.
  final String? notice;

  TuiSyncState copyWith({
    TuiSyncStatus? status,
    bool? hasIdentity,
    int? pendingCount,
    DateTime? lastSyncAt,
    int? lastPushed,
    int? lastPulled,
    int? lastFailed,
    int? lastDeferred,
    bool? updateRequired,
    String? errorMessage,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
  }) {
    return TuiSyncState(
      status: status ?? this.status,
      hasIdentity: hasIdentity ?? this.hasIdentity,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastPushed: lastPushed ?? this.lastPushed,
      lastPulled: lastPulled ?? this.lastPulled,
      lastFailed: lastFailed ?? this.lastFailed,
      lastDeferred: lastDeferred ?? this.lastDeferred,
      updateRequired: updateRequired ?? this.updateRequired,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  /// Linha de status compacta para o rodapé/cabeçalho da TUI.
  /// Ex.: `⟳ sincronizando… • 3 na fila • há 2min • 2 relay(s) • 1 peer`.
  String statusLine({required int onlineRelays, required int peers}) {
    if (!hasIdentity) return 'sync: sem identidade (modo offline)';
    final icon = switch (status) {
      TuiSyncStatus.syncing => '⟳ sincronizando…',
      TuiSyncStatus.error => '✗ sync falhou',
      TuiSyncStatus.success => '✓ sincronizado',
      TuiSyncStatus.idle => 'sync em dia',
      TuiSyncStatus.inactive => 'sync inativo',
    };
    final parts = <String>[
      icon,
      if (pendingCount > 0) '$pendingCount na fila',
      if (lastSyncAt != null) 'há ${_elapsed(lastSyncAt!)}',
      if (onlineRelays > 0) '$onlineRelays relay(s)',
      if (peers > 0) '$peers peer(s)',
      if (updateRequired) 'atualização necessária',
    ];
    return parts.join(' • ');
  }

  static String _elapsed(DateTime then) {
    final d = DateTime.now().difference(then);
    if (d.inSeconds < 60) return 'poucos seg';
    if (d.inMinutes < 60) return '${d.inMinutes}min';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

enum TuiSyncStatus { inactive, idle, syncing, success, error }

/// Engine de sincronização residente da TUI (task 57).
///
/// Substitui o sync manual-da-hora por um engine que vive enquanto a TUI
/// estiver aberta, replicando os três gatilhos do `SyncStateNotifier` da GUI
/// sem depender de Riverpod:
///
/// 1. **Live subscription** — [SyncTransport.liveEvents] sinaliza eventos
///    dos relays; cada um dispara um pull (com debounce curto).
/// 2. **Fila de push** — watch Drift sobre `sync_queue` pendente; quando a
///    fila cresce, agenda sync com debounce (3s, como na GUI).
/// 3. **Poll periódico** — rede de segurança de 1min caso o socket caia.
///
/// Sem identidade configurada, o engine fica inativo e a TUI segue 100%
/// funcional offline — igual a hoje.
class TuiSyncEngine {
  TuiSyncEngine(
    this._db,
    this._transport, {
    SyncService? syncService,
    Future<void> Function()? startLiveSync,
    Stream<void>? liveEvents,
    Duration pushDebounce = const Duration(seconds: 3),
    Duration pullDebounce = const Duration(milliseconds: 500),
    Duration pollInterval = const Duration(minutes: 1),
  }) : _syncService = syncService ?? SyncService(_db, _transport),
       _startLiveSync = startLiveSync,
       _liveEvents = liveEvents,
       _pushDebounce = pushDebounce,
       _pullDebounce = pullDebounce,
       _pollInterval = pollInterval;

  final AppDatabase _db;
  final SyncTransport _transport;
  final SyncService _syncService;

  // `startLiveSync`/`liveEvents` são exclusivos do NostrSyncService (não
  // fazem parte da interface SyncTransport) — entram como hooks injetáveis
  // para o engine seguir testável com transporte fake.
  final Future<void> Function()? _startLiveSync;
  final Stream<void>? _liveEvents;
  final Duration _pushDebounce;
  final Duration _pullDebounce;
  final Duration _pollInterval;

  final _stateController = StreamController<TuiSyncState>.broadcast();
  final _notices = StreamController<String>.broadcast();

  TuiSyncState _state = const TuiSyncState();
  StreamSubscription? _liveSub;
  StreamSubscription? _peerSub;
  StreamSubscription? _queueSub;
  StreamSubscription? _identitySub;
  Timer? _pushTimer;
  Timer? _pullTimer;
  Timer? _pollTimer;
  bool _starting = false;
  bool _disposed = false;
  bool _syncing = false;
  int _consecutiveFailures = 0;

  TuiSyncState get state => _state;

  /// Estado observável — a UI apenas desenha, nunca espera.
  Stream<TuiSyncState> get stateStream => _stateController.stream;

  /// Avisos discretos ("+N de outro dispositivo", falha de background).
  Stream<String> get notices => _notices.stream;

  /// Transporte da sessão — a tela de Sincronização usa o mesmo (live
  /// subscription, presença de peers, status de relays) em vez de montar o
  /// próprio e descartar.
  SyncTransport get transport => _transport;

  /// Peers vistos nesta sessão (última presença por dispositivo) — alimenta
  /// a tela de Sincronização.
  final Map<String, DevicePresenceInfo> peers = {};

  /// Relays online no momento (status `connected`).
  int get onlineRelays => _transport.relayStatuses.values
      .where((r) => r.status == RelayStatus.connected)
      .length;

  /// Inicia o engine. Idempotente e seguro: se não houver identidade (ou o
  /// armazenamento seguro não estiver acessível fora da GUI), fica inativo.
  Future<void> start() async {
    if (_disposed || _starting || _state.hasIdentity) return;
    _starting = true;
    try {
      SyncIdentity? identity;
      try {
        identity = await _transport.loadIdentity();
      } catch (_) {
        // Armazenamento seguro indisponível no terminal — modo offline.
      }
      if (identity == null) {
        _setState(const TuiSyncState(hasIdentity: false));
        return;
      }

      if (_startLiveSync != null) {
        await _startLiveSync();
      }

      _identitySub = _transport.identityChanges.listen((id) {
        if (_disposed) return;
        if (id == null) {
          // Identidade removida — volta ao modo offline.
          _teardownTriggers();
          _setState(const TuiSyncState(hasIdentity: false));
        }
      });

      // 1. Eventos ao vivo → pull rápido.
      if (_liveEvents != null) {
        _liveSub = _liveEvents.listen((_) => _scheduleSync(_pullDebounce));
      }

      // Presença de outros dispositivos (pushPresence dos peers).
      _peerSub = _transport.peerConnections.listen((p) {
        if (_disposed) return;
        peers[p.deviceId] = p;
        _setState(_state.copyWith());
      });

      // 2. Fila de push com debounce.
      _queueSub = _db.syncQueueDao.watchPendingCount().listen((count) {
        if (_disposed) return;
        if (count > _state.pendingCount) _scheduleSync(_pushDebounce);
        _setState(_state.copyWith(pendingCount: count));
      });

      // 3. Rede de segurança periódica.
      _pollTimer = Timer.periodic(_pollInterval, (_) => _scheduleSync(null));

      _setState(
        TuiSyncState(hasIdentity: true, pendingCount: _state.pendingCount),
      );
      // Primeira sync logo ao abrir — traz o que acumulou desde a última.
      _scheduleSync(null);
    } finally {
      _starting = false;
    }
  }

  /// Sync sob demanda (tela de Sincronização). Nunca concorre consigo
  /// mesma — se já está rodando, apenas retorna o estado atual.
  Future<void> syncNow() async {
    if (_disposed || !_state.hasIdentity || _syncing) return;
    await _runSync();
  }

  void _scheduleSync(Duration? delay) {
    if (_disposed || !_state.hasIdentity || _syncing) return;
    if (delay == null) {
      _pushTimer?.cancel();
      _pullTimer?.cancel();
      _runSync();
      return;
    }
    final isPush = identical(delay, _pushDebounce);
    final timer = isPush ? _pushTimer : _pullTimer;
    timer?.cancel();
    final fresh = Timer(delay, () => _runSync());
    if (isPush) {
      _pushTimer = fresh;
    } else {
      _pullTimer = fresh;
    }
  }

  Future<void> _runSync() async {
    if (_disposed || _syncing) return;
    _syncing = true;
    _setState(_state.copyWith(status: TuiSyncStatus.syncing));
    try {
      final result = await _syncService.syncNow();
      if (_disposed) return;
      if (result.success) {
        _consecutiveFailures = 0;
        String? notice;
        if (result.pulled > 0)
          notice = '+${result.pulled} de outro dispositivo';
        _setState(
          _state.copyWith(
            status: TuiSyncStatus.success,
            lastSyncAt: DateTime.now(),
            lastPushed: result.pushed,
            lastPulled: result.pulled,
            lastFailed: result.failed,
            lastDeferred: result.deferred,
            updateRequired: result.deferred > 0,
            clearError: true,
            notice: notice,
            clearNotice: notice == null,
          ),
        );
        if (notice != null) _notices.add(notice);
      } else {
        _consecutiveFailures++;
        final grouped = _consecutiveFailures > 1
            ? ' ($_consecutiveFailures x seguidas)'
            : '';
        final msg = result.errorMessage ?? 'falha desconhecida';
        _setState(
          _state.copyWith(
            status: TuiSyncStatus.error,
            errorMessage: msg,
            notice: 'sync de fundo falhou$grouped',
          ),
        );
        _notices.add('sync de fundo falhou$grouped');
      }
    } catch (e) {
      if (_disposed) return;
      _consecutiveFailures++;
      _setState(
        _state.copyWith(
          status: TuiSyncStatus.error,
          errorMessage: e.toString(),
          notice:
              'sync de fundo falhou'
              '${_consecutiveFailures > 1 ? ' ($_consecutiveFailures x seguidas)' : ''}',
        ),
      );
      _notices.add(state.notice ?? 'sync de fundo falhou');
    } finally {
      _syncing = false;
    }
  }

  void _setState(TuiSyncState next) {
    if (_disposed) return;
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  void _teardownTriggers() {
    _liveSub?.cancel();
    _peerSub?.cancel();
    _queueSub?.cancel();
    _identitySub?.cancel();
    _pollTimer?.cancel();
    _pushTimer?.cancel();
    _pullTimer?.cancel();
    _liveSub = null;
    _peerSub = null;
    _queueSub = null;
    _identitySub = null;
    _pollTimer = null;
    _pushTimer = null;
    _pullTimer = null;
  }

  /// Encerra o engine — idempotente. Não fecha o transporte: o dono dele
  /// (bootstrap da TUI) decide o momento.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _teardownTriggers();
    await _stateController.close();
    await _notices.close();
  }
}
