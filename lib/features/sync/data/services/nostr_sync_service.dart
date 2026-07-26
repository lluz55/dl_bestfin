import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestfin/core/constants/app_info.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';
import 'package:bestfin/features/sync/domain/models/app_update_info.dart';

const _encMasterKeyKey = 'nostr_encrypted_master_key';
const _kdfSaltKey = 'nostr_kdf_salt';
const _localDeviceIdKey = 'sync_local_device_id';

// SharedPreferences key holding the user's custom relay list (List<String>).
// Absent/empty means "use defaultRelays". Persisted independently of the
// identity, so it survives sign-out and identity re-import.
const _customRelaysKey = 'nostr_custom_relays';

// Random per-device KDF password (base64) used to wrap the master key at rest.
// Replaces the pre-1.0.6 hardcoded '_legacyKekPassword' constant, so the
// wrapping now depends on a real secret instead of a public string. The blob,
// this secret and the salt all live in the OS secure storage (Keystore/
// Keychain), which remains the actual gate — this just removes the false
// sense of security of a fixed password.
const _kekSecretKey = 'nostr_kek_secret';
// Only kept to decrypt (and then migrate) identities stored by older builds.
const _legacyKekPassword = 'device-local';

// kind:30078 — NIP-78 "application-specific data", replaceable by d-tag
const _nostrKind = 30078;

const _queryTimeoutSeconds = 12;

// Per-relay backoff after a connection error/close/rate-limit notice, so a
// consistently bad relay stops being retried on every single sync cycle.
// Doubles per consecutive failure (30s, 1m, 2m, 4m, 8m, capped at 16m), with
// jitter so multiple devices sharing an identity don't retry in lockstep.
const _relayBackoffBase = Duration(seconds: 30);
const _relayBackoffMax = Duration(minutes: 16);

// Page size for pull pagination. Relays silently cap query responses (often
// at ~500 events), so the initial sync must paginate with `until` instead of
// trusting a single unbounded query.
const _pullPageSize = 500;
const _pullMaxPages = 40;

// Verified 2026-07-04 via NIP-11 (https://<host> with `Accept:
// application/nostr+json`): each of these resolves, connects, and reports no
// auth/payment requirement for reads or writes. The previous list carried
// several hostnames that never resolved via DNS (fabricated/decommissioned)
// and nostr.wine, which is reachable but requires payment for writes and so
// silently rejected our sync events.
const defaultRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://relay.nostr.info',
  'wss://relay.nostr.net',
  'wss://nostr-pub.wellorder.net',
  'wss://relay.snort.social',
  'wss://bitcoiner.social',
  'wss://purplerelay.com',
  'wss://offchain.pub',
];

class NostrSyncService implements SyncTransport {
  static const _storage = FlutterSecureStorage();

  final AppDatabase _db;
  List<String> relays;

  Uint8List? _masterKey;
  NostrKeyPairs? _keyPair;
  SyncIdentity? _identity;
  Nostr? _nostr;
  bool _relaysInitialized = false;

  final _identityController = StreamController<SyncIdentity?>.broadcast();
  final _peerConnectionsController =
      StreamController<DevicePresenceInfo>.broadcast();
  final _seenDeviceIds = <String>{};
  String? _localDeviceId;

  final Map<String, RelayConnectionInfo> _relayStatuses = {};
  final _relayStatusController =
      StreamController<Map<String, RelayConnectionInfo>>.broadcast();

  // Per-relay backoff bookkeeping (see _relayBackoffBase above).
  final Map<String, int> _relayFailureCounts = {};
  final Map<String, DateTime> _relayCooldownUntil = {};

  // Live subscription: kept open (never closed on EOSE) so new events
  // authored by us show up within seconds instead of waiting for the next
  // periodic poll. Emits a signal only — the actual pull+merge is triggered
  // by the listener (SyncStateNotifier) through the existing debounced sync.
  final _liveEventController = StreamController<void>.broadcast();
  NostrEventsStream? _liveSubscription;

  // Developer broadcast subscription: watches for app_update events published
  // by the developer keypair (kDeveloperNostrPubkey). Events carry plain JSON
  // content — no per-user masterKey encryption, since these are public
  // announcements meant to reach every instance of the app.
  final _appUpdateController = StreamController<AppUpdateInfo>.broadcast();
  NostrEventsStream? _updateSubscription;

  // When relays are passed explicitly (tests), skip loading the persisted list.
  final bool _relaysExplicit;
  bool _relaysLoaded = false;

  NostrSyncService(this._db, {List<String>? relays})
    : relays = relays ?? defaultRelays,
      _relaysExplicit = relays != null;

  // ── SyncTransport interface ───────────────────────────────────────────────

  @override
  Stream<SyncIdentity?> get identityChanges async* {
    yield _identity;
    yield* _identityController.stream;
  }

  @override
  Stream<DevicePresenceInfo> get peerConnections =>
      _peerConnectionsController.stream;

  @override
  SyncIdentity? get identity => _identity;

  @override
  bool get isReady => _masterKey != null && _keyPair != null;

  @override
  Uint8List? get masterKey => _masterKey;

  @override
  Map<String, RelayConnectionInfo> get relayStatuses =>
      Map.unmodifiable(_relayStatuses);

  @override
  Stream<Map<String, RelayConnectionInfo>> get relayStatusChanges async* {
    yield Map.unmodifiable(_relayStatuses);
    yield* _relayStatusController.stream;
  }

  void _emitRelayStatuses() {
    if (_relayStatusController.isClosed) return;
    _relayStatusController.add(Map.unmodifiable(_relayStatuses));
  }

  @override
  Future<SyncIdentity?> loadIdentity() async {
    if (_identity != null) return _identity;
    try {
      final encMK = await _storage.read(key: _encMasterKeyKey);
      final kdfSalt = await _storage.read(key: _kdfSaltKey);
      if (encMK == null || kdfSalt == null) {
        debugPrint(
          '[Sync] loadIdentity: nenhuma identidade salva no armazenamento seguro.',
        );
        return null;
      }
      final kekSecret = await _storage.read(key: _kekSecretKey);
      final kek = await E2ECryptoService.deriveKEK(
        kekSecret ?? _legacyKekPassword,
        kdfSalt,
      );
      final masterKey = await E2ECryptoService.decryptMasterKey(kek, encMK);
      // Legacy install wrapped with the old fixed password: re-wrap with a
      // fresh random per-device secret now that we could open it.
      if (kekSecret == null) {
        try {
          await _persistEncryptedMasterKey(masterKey);
        } catch (e) {
          debugPrint('[Sync] Migração da KEK legada falhou (não fatal): $e');
        }
      }
      return _restoreIdentity(masterKey);
    } on Exception catch (e, st) {
      // Storage failure (e.g. keyring unavailable on Linux) — log but do not
      // delete the stored keys, since they may be recoverable in a later session.
      debugPrint(
        '[Sync] loadIdentity falhou ao acessar armazenamento: $e\n$st',
      );
      return null;
    } catch (e, st) {
      // Decryption error — stored keys are corrupted; purge and start fresh.
      debugPrint('[Sync] loadIdentity: chave corrompida, removendo. $e\n$st');
      try {
        await _storage.delete(key: _encMasterKeyKey);
        await _storage.delete(key: _kdfSaltKey);
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<({SyncIdentity identity, String mnemonic})> createIdentity() async {
    final (:mnemonic, :masterKey) = E2ECryptoService.generateIdentity();
    final identity = await _activateIdentity(masterKey);
    return (identity: identity, mnemonic: mnemonic);
  }

  @override
  Future<SyncIdentity> importIdentity(String mnemonic) async {
    final masterKey = E2ECryptoService.mnemonicToMasterKey(mnemonic);
    return _activateIdentity(masterKey);
  }

  @override
  Future<void> signOut() async {
    await _closeNostr();
    _masterKey = null;
    _keyPair = null;
    _identity = null;
    _seenDeviceIds.clear();
    await _storage.delete(key: _encMasterKeyKey);
    await _storage.delete(key: _kdfSaltKey);
    await _storage.delete(key: _kekSecretKey);
    _identityController.add(null);
  }

  /// Encerra a sessão de forma NÃO-BLOQUEANTE. Invalida a identidade em memória
  /// imediatamente (a UI para de ver uma sessão ativa e o onboarding não
  /// re-sincroniza) e agenda o trabalho pesado — fechar os WebSockets dos relays
  /// e apagar o armazenamento seguro — em segundo plano. Fechar sockets de
  /// relays lentos pode levar segundos ou travar; isso nunca deve bloquear a
  /// limpeza de dados do usuário nem o retorno ao onboarding.
  void signOutInBackground() {
    _masterKey = null;
    _keyPair = null;
    _identity = null;
    _seenDeviceIds.clear();
    if (!_identityController.isClosed) _identityController.add(null);

    // Captura e zera o estado de conexão de forma síncrona: se o onboarding
    // ativar uma nova identidade logo em seguida, a limpeza em segundo plano
    // não pode fechar a conexão nova nem apagar as chaves recém-gravadas.
    final stale = _nostr;
    final staleSub = _liveSubscription;
    _nostr = null;
    _liveSubscription = null;
    _relaysInitialized = false;
    _relayFailureCounts.clear();
    _relayCooldownUntil.clear();

    unawaited(_cleanupAfterSignOut(stale, staleSub));
  }

  Future<void> _cleanupAfterSignOut(
    Nostr? stale,
    NostrEventsStream? staleSub,
  ) async {
    try {
      staleSub?.close();
    } catch (_) {}
    if (stale != null) {
      try {
        await stale.relays.freeAllResources();
      } catch (e) {
        debugPrint('[Sync] freeAllResources em segundo plano falhou: $e');
      }
    }
    // Só apaga as chaves se nenhuma nova identidade foi ativada nesse meio-tempo
    // (evita corrida com createIdentity/importIdentity do onboarding).
    if (_masterKey == null) {
      try {
        await _storage.delete(key: _encMasterKeyKey);
        await _storage.delete(key: _kdfSaltKey);
        await _storage.delete(key: _kekSecretKey);
      } catch (e) {
        debugPrint('[Sync] delete storage em segundo plano falhou: $e');
      }
    }
  }

  @override
  Future<void> pushRecords(
    List<SyncRecord> records, {
    void Function(int sentCount, int bytesSent)? onProgress,
  }) async {
    if (!isReady) throw StateError('Identidade Nostr não carregada');
    final nostr = await _ensureConnected();

    var sent = 0;
    var bytesSent = 0;

    for (final record in records) {
      final encPayload = await E2ECryptoService.encryptPayload(
        _masterKey!,
        encodeSyncEnvelope(
          record.payload,
          schemaVersion: record.schemaVersion,
          entityType: record.entityType,
          entityId: record.entityId,
          isDeleted: record.isDeleted,
        ),
      );
      // Opaque, deterministic `d` tag: keeps NIP-33 replaceability without
      // exposing the entity id/type in plaintext (those now live encrypted
      // inside the envelope above).
      final dTag = await E2ECryptoService.deriveEntityTag(
        _masterKey!,
        record.entityType,
        record.entityId,
      );
      final publishedAt = DateTime.fromMillisecondsSinceEpoch(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) * 1000,
      );

      final event = NostrEvent.fromPartialData(
        kind: _nostrKind,
        content: encPayload,
        keyPairs: _keyPair!,
        tags: [
          ['d', dTag],
        ],
        createdAt: publishedAt,
      );

      // Persist locally before publishing (relay resilience)
      await _db.nostrEventLogDao.save(
        NostrEventLogItem(
          eventId: event.id!,
          entityType: record.entityType,
          entityId: record.entityId,
          payload: encPayload,
          updatedAt: record.updatedAt,
          isDeleted: record.isDeleted,
          published: false,
          createdAt: DateTime.now(),
        ),
      );

      try {
        final ok = await nostr.relays.sendEventToRelaysAsync(
          event,
          timeout: const Duration(seconds: 8),
        );
        if (ok.isEventAccepted ?? true) {
          await _db.nostrEventLogDao.markPublished(event.id!);
        } else {
          debugPrint(
            '[Sync] Relay rejeitou ${record.entityType}/${record.entityId}',
          );
        }
      } on StateError catch (e) {
        debugPrint(
          '[Sync] Relay não conectado ao publicar ${record.entityType}/'
          '${record.entityId}: $e',
        );
      } catch (e, st) {
        // Will be retried by replayUnpublished() on next connection
        debugPrint(
          '[Sync] Falha ao publicar ${record.entityType}/${record.entityId}: '
          '$e\n$st',
        );
      }

      sent++;
      bytesSent += utf8.encode(encPayload).length;
      onProgress?.call(sent, bytesSent);
    }
  }

  @override
  Future<List<SyncRecord>> pullRecords({
    required int since,
    void Function(int receivedCount, int bytesReceived)? onProgress,
  }) async {
    if (!isReady) throw StateError('Identidade Nostr não carregada');
    final nostr = await _ensureConnected();

    // Paginate backwards with `until` until a page brings nothing new.
    final seenEventIds = <String>{};
    final events = <NostrEvent>[];
    var bytesReceived = 0;
    int? until;

    for (var page = 0; page < _pullMaxPages; page++) {
      final filter = NostrFilter(
        authors: [_keyPair!.public],
        kinds: const [_nostrKind],
        since: DateTime.fromMillisecondsSinceEpoch(since * 1000),
        until: until != null
            ? DateTime.fromMillisecondsSinceEpoch(until * 1000)
            : null,
        limit: _pullPageSize,
      );

      List<NostrEvent> batch;
      try {
        batch = await _queryAllRelays(nostr, filter);
      } catch (e) {
        debugPrint('[Sync] Falha na página $page da paginação: $e');
        break;
      }

      final fresh = batch.where((e) => seenEventIds.add(e.id!)).toList();
      if (fresh.isEmpty) break;
      events.addAll(fresh);
      bytesReceived += fresh.fold<int>(
        0,
        (sum, e) => sum + utf8.encode(e.content ?? '').length,
      );
      onProgress?.call(events.length, bytesReceived);
      if (batch.length < _pullPageSize) break;
      until = fresh
          .map((e) => e.createdAt!.millisecondsSinceEpoch ~/ 1000)
          .reduce(min);
    }

    final localDeviceId = await _getOrCreateLocalDeviceId();
    final records = <SyncRecord>[];

    // A pull can only decrypt events sealed with our own master key, and those
    // are exactly the events signed by our own pubkey (privkey = HKDF(masterKey)).
    // Some relays don't strictly honour the `authors` filter and hand back other
    // clients' kind:30078 app-data, which would then flood the log with MAC
    // failures. Re-check authorship locally and count anything foreign vs. any
    // genuinely undecryptable own-events (e.g. stale blobs from an earlier build)
    // so a single summary replaces per-event stack traces.
    final ourPubkey = _keyPair!.public;
    var foreignSkipped = 0;
    var undecryptableOwn = 0;

    for (final event in events) {
      if (event.pubkey != ourPubkey) {
        foreignSkipped++;
        continue;
      }
      try {
        final plainPayload = await E2ECryptoService.decryptPayload(
          _masterKey!,
          event.content!,
        );
        final envelope = decodeSyncEnvelope(plainPayload);
        final tags = event.tags ?? [];

        // Current events carry entity metadata encrypted inside the envelope;
        // events from older builds carry it as plaintext `t`/`d`/`deleted`
        // tags. Prefer the envelope, fall back to the tags for old events.
        final tTag = tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 't',
          orElse: () => [],
        );
        final dTag = tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'd',
          orElse: () => [],
        );
        final entityType =
            envelope.entityType ?? (tTag.length >= 2 ? tTag[1] : null);
        final entityId =
            envelope.entityId ?? (dTag.length >= 2 ? dTag[1] : null);
        final isDeleted =
            envelope.isDeleted ??
            tags.any(
              (t) => t.length >= 2 && t[0] == 'deleted' && t[1] == 'true',
            );
        if (entityType == null || entityId == null) continue;

        if (entityType == 'device_presence') {
          if (entityId != localDeviceId && !_seenDeviceIds.contains(entityId)) {
            _seenDeviceIds.add(entityId);
            try {
              _peerConnectionsController.add(
                DevicePresenceInfo.fromJson(
                  jsonDecode(envelope.payload) as Map<String, dynamic>,
                ),
              );
            } catch (_) {
              _peerConnectionsController.add(
                DevicePresenceInfo(
                  deviceId: entityId,
                  platform: 'unknown',
                  connectedAt: event.createdAt ?? DateTime.now(),
                ),
              );
            }
          }
          continue;
        }

        records.add(
          SyncRecord(
            entityId: entityId,
            entityType: entityType,
            payload: envelope.payload,
            updatedAt: event.createdAt!.millisecondsSinceEpoch ~/ 1000,
            isDeleted: isDeleted,
            schemaVersion: envelope.schemaVersion,
          ),
        );
      } catch (_) {
        // Own event we can't open: either a stale blob from an earlier build or
        // corrupted content. Count it — a per-event stack trace here just floods
        // the log on every sync since these events persist on the relay.
        undecryptableOwn++;
      }
    }

    if (foreignSkipped > 0 || undecryptableOwn > 0) {
      debugPrint(
        '[Sync] Pull: ${records.length} registros; '
        '$foreignSkipped eventos de outros autores ignorados, '
        '$undecryptableOwn eventos próprios não decodificáveis '
        '(chave antiga ou payload corrompido).',
      );
    }

    return records;
  }

  /// Runs a single filtered query against every connected relay and returns the
  /// union of their events, deduplicated by event id.
  ///
  /// `startEventsSubscriptionAsync` resolves on the *first* relay's EOSE, so a
  /// fast relay that happens to hold none of the author's events makes the whole
  /// query return empty — the exact reason a freshly-paired device reported
  /// "connected" and "syncing" yet pulled nothing. Here we instead wait until
  /// every connected relay has signalled EOSE (or an overall timeout elapses)
  /// and merge everything they returned, so a single empty relay can no longer
  /// short-circuit the pull.
  Future<List<NostrEvent>> _queryAllRelays(
    Nostr nostr,
    NostrFilter filter,
  ) async {
    final connectedCount = _relayStatuses.values
        .where((r) => r.status == RelayStatus.connected)
        .length;
    final expectedEose = connectedCount > 0 ? connectedCount : 1;

    final events = <NostrEvent>[];
    final seen = <String>{};
    final eosed = <String>{};
    final completer = Completer<List<NostrEvent>>();

    final sub = nostr.relays.startEventsSubscription(
      request: NostrRequest(filters: [filter]),
      onEose: (relay, _) {
        if (eosed.add(relay) &&
            eosed.length >= expectedEose &&
            !completer.isCompleted) {
          completer.complete(events);
        }
      },
    );

    final listener = sub.stream.listen((event) {
      if (event.id != null && seen.add(event.id!)) events.add(event);
    });

    // A relay that never sends EOSE (or a dead socket still counted as
    // connected) must not hang the pull — fall back to whatever arrived.
    final timer = Timer(const Duration(seconds: _queryTimeoutSeconds), () {
      if (!completer.isCompleted) completer.complete(events);
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await listener.cancel();
      sub.close();
    }
  }

  /// Re-publish events that were saved locally but not yet confirmed by a relay.
  @override
  Future<void> replayUnpublished() async {
    if (!isReady) return;
    final nostr = await _ensureConnected();
    final pending = await _db.nostrEventLogDao.getUnpublished();

    for (final item in pending) {
      try {
        // Rebuild the event in the current format (entity metadata encrypted
        // inside the envelope, opaque `d` tag) by re-encrypting the stored
        // content. This keeps replays from leaking the entity via plaintext
        // tags even for events that were queued by an older build.
        final plain = await E2ECryptoService.decryptPayload(
          _masterKey!,
          item.payload,
        );
        final inner = decodeSyncEnvelope(plain);
        final encPayload = await E2ECryptoService.encryptPayload(
          _masterKey!,
          encodeSyncEnvelope(
            inner.payload,
            schemaVersion: inner.schemaVersion,
            entityType: item.entityType,
            entityId: item.entityId,
            isDeleted: item.isDeleted,
          ),
        );
        final dTag = await E2ECryptoService.deriveEntityTag(
          _masterKey!,
          item.entityType,
          item.entityId,
        );
        // Use current time so relays don't filter out this event with `since`.
        final event = NostrEvent.fromPartialData(
          kind: _nostrKind,
          content: encPayload,
          keyPairs: _keyPair!,
          tags: [
            ['d', dTag],
          ],
          createdAt: DateTime.now(),
        );
        final ok = await nostr.relays.sendEventToRelaysAsync(
          event,
          timeout: const Duration(seconds: 8),
        );
        if (ok.isEventAccepted ?? true) {
          await _db.nostrEventLogDao.markPublished(item.eventId);
        }
      } on StateError catch (e) {
        debugPrint(
          '[Sync] Relay não conectado ao reenviar ${item.entityType}/'
          '${item.entityId}: $e',
        );
      } catch (e, st) {
        // Try again next cycle
        debugPrint(
          '[Sync] Falha ao reenviar evento pendente ${item.entityType}/'
          '${item.entityId}: $e\n$st',
        );
      }
    }
  }

  /// Opens a long-lived subscription for events authored by us from now on
  /// and keeps it open past EOSE (unlike [_queryAllRelays], which closes as
  /// soon as it has a page). Every subsequent event — i.e. a change pushed by
  /// another device — emits on [liveEvents], letting the caller trigger a
  /// pull immediately instead of waiting for the next periodic poll.
  ///
  /// Safe to call repeatedly: a no-op once a subscription is already open.
  Future<void> startLiveSync() async {
    if (_liveSubscription != null) return;
    if (!isReady) return;
    final nostr = await _ensureConnected();

    final filter = NostrFilter(
      authors: [_keyPair!.public],
      kinds: const [_nostrKind],
      since: DateTime.now(),
    );
    final sub = nostr.relays.startEventsSubscription(
      request: NostrRequest(filters: [filter]),
    );
    _liveSubscription = sub;
    sub.stream.listen((_) {
      if (!_liveEventController.isClosed) _liveEventController.add(null);
    });
  }

  /// Signals whenever the live subscription (see [startLiveSync]) observes a
  /// new event. Carries no payload — the listener re-syncs through the
  /// normal push/pull pipeline to keep merge logic in one place.
  Stream<void> get liveEvents => _liveEventController.stream;

  /// Emits whenever the developer publishes a new version that is strictly
  /// newer than the current [kAppVersion]. The subscription is kept open so
  /// updates are delivered in real time without waiting for the next periodic
  /// sync. Safe to call repeatedly — no-op once the subscription is open.
  Stream<AppUpdateInfo> get appUpdateEvents => _appUpdateController.stream;

  /// Opens a long-lived subscription for app_update events published by the
  /// developer Nostr keypair. Requires at least one relay to be reachable;
  /// silently no-ops when there is no relay connection yet.
  Future<void> startUpdateListener() async {
    if (_updateSubscription != null) return;
    try {
      final nostr = await _ensureConnected();
      const filter = NostrFilter(
        authors: [kDeveloperNostrPubkey],
        kinds: [_nostrKind],
        // Replaceable events use the d-tag 'app_update', so only the most
        // recent event per d-tag survives on NIP-33-compliant relays.
        limit: 5,
      );
      final sub = nostr.relays.startEventsSubscription(
        request: NostrRequest(filters: const [filter]),
      );
      _updateSubscription = sub;
      sub.stream.listen((event) {
        // Extra client-side authorship check — some relays don't honour the
        // authors filter strictly.
        if (event.pubkey != kDeveloperNostrPubkey) return;
        try {
          final info = AppUpdateInfo.fromJson(
            jsonDecode(event.content!) as Map<String, dynamic>,
          );
          if (_isNewerVersion(info.version, kAppVersion)) {
            _appUpdateController.add(info);
          }
        } catch (e) {
          debugPrint('[Sync] Falha ao parsear evento de atualização: $e');
        }
      });
    } catch (e) {
      debugPrint('[Sync] Falha ao iniciar listener de atualização: $e');
    }
  }

  /// Returns true when [candidate] is strictly newer than [current], using
  /// semver major.minor.patch ordering. Non-numeric segments are treated as 0.
  static bool _isNewerVersion(String candidate, String current) {
    List<int> parse(String v) => v
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final c = parse(candidate);
    final r = parse(current);
    for (var i = 0; i < 3; i++) {
      final cv = i < c.length ? c[i] : 0;
      final rv = i < r.length ? r[i] : 0;
      if (cv > rv) return true;
      if (cv < rv) return false;
    }
    return false;
  }

  Future<void> _stopUpdateListener() async {
    final sub = _updateSubscription;
    _updateSubscription = null;
    if (sub != null) {
      try {
        sub.close();
      } catch (_) {}
    }
  }

  Future<void> _stopLiveSync() async {
    final sub = _liveSubscription;
    _liveSubscription = null;
    if (sub != null) {
      try {
        sub.close();
      } catch (_) {}
    }
  }

  @override
  Future<void> pushPresence() async {
    if (!isReady) return;
    final nostr = await _ensureConnected();
    final deviceId = await _getOrCreateLocalDeviceId();
    final platformName = defaultTargetPlatform.name;
    final shortId = deviceId.substring(0, 4);

    final info = DevicePresenceInfo(
      deviceId: deviceId,
      deviceName: '$platformName • $shortId',
      platform: platformName,
      connectedAt: DateTime.now(),
      schemaVersion: kSyncSchemaVersion,
    );

    const presenceType = 'device_presence';
    final encPayload = await E2ECryptoService.encryptPayload(
      _masterKey!,
      encodeSyncEnvelope(
        jsonEncode(info.toJson()),
        entityType: presenceType,
        entityId: deviceId,
      ),
    );
    final dTag = await E2ECryptoService.deriveEntityTag(
      _masterKey!,
      presenceType,
      deviceId,
    );

    final event = NostrEvent.fromPartialData(
      kind: _nostrKind,
      content: encPayload,
      keyPairs: _keyPair!,
      tags: [
        ['d', dTag],
      ],
      createdAt: DateTime.now(),
    );

    try {
      await nostr.relays.sendEventToRelaysAsync(
        event,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint('[Sync] Falha ao publicar presença: $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  // Restore identity from already-decrypted masterKey without touching storage.
  Future<SyncIdentity> _restoreIdentity(Uint8List masterKey) async {
    _masterKey = masterKey;
    // Reuse existing instance when available (e.g. called from loadIdentity
    // after the app already had an instance from a previous operation).
    _nostr ??= Nostr()..disableLogs();
    final privkeyHex = await E2ECryptoService.deriveNostrPrivkey(masterKey);
    _keyPair = _nostr!.keys.generateKeyPairFromExistingPrivateKey(privkeyHex);
    _identity = SyncIdentity(publicKey: _keyPair!.public);
    _identityController.add(_identity);
    return _identity!;
  }

  Future<SyncIdentity> _activateIdentity(Uint8List masterKey) async {
    await _closeNostr(); // force re-init with new key, closing stale sockets
    _seenDeviceIds.clear();
    final identity = await _restoreIdentity(masterKey);

    // Persist encrypted masterKey for recovery without mnemonic re-entry.
    await _persistEncryptedMasterKey(masterKey);

    return identity;
  }

  /// Wraps [masterKey] with a KEK derived from a fresh random per-device secret
  /// and stores the blob, secret and salt in secure storage. Used both when a
  /// new identity is activated and when migrating an identity wrapped by an
  /// older build's fixed password.
  Future<void> _persistEncryptedMasterKey(List<int> masterKey) async {
    final secret = _generateKekSecret();
    final salt = _generateHexSalt();
    final kek = await E2ECryptoService.deriveKEK(secret, salt);
    final encMK = await E2ECryptoService.encryptMasterKey(kek, masterKey);
    await _storage.write(key: _kekSecretKey, value: secret);
    await _storage.write(key: _kdfSaltKey, value: salt);
    await _storage.write(key: _encMasterKeyKey, value: encMK);
  }

  // 32 random bytes, base64 — the KDF password for wrapping the master key.
  static String _generateKekSecret() {
    final rng = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  // Backoff bookkeeping — see [_relayBackoffBase]. A rate-limit NOTICE counts
  // as 3 failures at once so a relay that explicitly asked us to slow down
  // backs off harder than a plain dropped connection.
  void _markRelayFailure(String url, {bool rateLimited = false}) {
    final next = (_relayFailureCounts[url] ?? 0) + (rateLimited ? 3 : 1);
    _relayFailureCounts[url] = next;
    final exponent = next.clamp(1, 6) - 1;
    var backoff = _relayBackoffBase * (1 << exponent);
    if (backoff > _relayBackoffMax) backoff = _relayBackoffMax;
    final jitterMs = Random().nextInt(
      (backoff.inMilliseconds * 0.2).round() + 1,
    );
    _relayCooldownUntil[url] = DateTime.now().add(
      backoff + Duration(milliseconds: jitterMs),
    );
  }

  void _markRelaySuccess(String url) {
    _relayFailureCounts.remove(url);
    _relayCooldownUntil.remove(url);
  }

  bool _isRelayCoolingDown(String url) {
    final until = _relayCooldownUntil[url];
    return until != null && until.isAfter(DateTime.now());
  }

  void _handleRelayNotice(String relayUrl, Object? socket, NostrNotice notice) {
    final msg = notice.message.toLowerCase();
    final isRateLimit =
        msg.contains('rate') ||
        msg.contains('limit') ||
        msg.contains('too many') ||
        msg.contains('slow down');
    if (!isRateLimit) return;
    debugPrint(
      '[Sync] Relay $relayUrl sinalizou rate limit: ${notice.message}',
    );
    _markRelayFailure(relayUrl, rateLimited: true);
    _relayStatuses[relayUrl] = RelayConnectionInfo(
      url: relayUrl,
      status: RelayStatus.error,
      errorMessage: 'Rate limited',
    );
    _emitRelayStatuses();
  }

  /// Excludes relays currently in their failure cooldown from the list
  /// dart_nostr uses to auto-reconnect on every push/pull/subscribe call —
  /// without this, a permanently unreachable relay gets retried on every
  /// single sync cycle with no backoff at all.
  void _syncActiveRelayList() {
    if (_nostr == null) return;
    _nostr!.relays.relaysList = relays
        .where((url) => !_isRelayCoolingDown(url))
        .toList();
  }

  /// Reconciles our own [_relayStatuses] against dart_nostr's live websocket
  /// registry. Needed because reconnect attempts triggered internally by the
  /// package (via its own auto-retry-on-send) don't carry our
  /// onRelayConnectionError/Done callbacks, so a drop or recovery that
  /// happens after the initial connect would otherwise go unnoticed.
  void _reconcileRelayHealth() {
    if (_nostr == null) return;
    final registry = _nostr!.relays.relaysWebSocketsRegistry;
    var changed = false;
    for (final url in relays) {
      final wasConnected = _relayStatuses[url]?.status == RelayStatus.connected;
      final isConnected = registry.containsKey(url);
      if (isConnected && !wasConnected && !_isRelayCoolingDown(url)) {
        _markRelaySuccess(url);
        _relayStatuses[url] = RelayConnectionInfo(
          url: url,
          status: RelayStatus.connected,
        );
        changed = true;
      } else if (!isConnected && wasConnected) {
        _markRelayFailure(url);
        _relayStatuses[url] = RelayConnectionInfo(
          url: url,
          status: RelayStatus.error,
          errorMessage: 'Conexão perdida',
        );
        changed = true;
      }
    }
    if (changed) _emitRelayStatuses();
  }

  /// Returns the Nostr instance with relays initialized, initializing them
  /// on first call. Lazy: relay connections are not established until the
  /// first push or pull so that loadIdentity() is non-blocking.
  // ── Relay list management ─────────────────────────────────────────────────

  /// Loads the persisted custom relay list into [relays] on first use. No-op
  /// when relays were injected explicitly (tests) or already loaded.
  Future<void> _ensureRelaysLoaded() async {
    if (_relaysLoaded || _relaysExplicit) return;
    _relaysLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_customRelaysKey);
      if (stored != null && stored.isNotEmpty) relays = stored;
    } catch (e) {
      debugPrint('[Sync] Falha ao carregar relays customizados: $e');
    }
  }

  /// Returns the currently configured relays (persisted custom list, or the
  /// defaults). Ensures the persisted list is loaded first.
  Future<List<String>> loadConfiguredRelays() async {
    await _ensureRelaysLoaded();
    return List.unmodifiable(relays);
  }

  /// Replaces the relay list, persists it, and reconnects so the next sync
  /// (and the live UI status) uses the new set. Invalid/duplicate URLs are
  /// dropped; if nothing valid remains, falls back to [defaultRelays].
  Future<void> updateRelays(List<String> urls) async {
    final cleaned = <String>[];
    for (final u in urls) {
      final n = normalizeRelayUrl(u);
      if (n != null && !cleaned.contains(n)) cleaned.add(n);
    }
    final next = cleaned.isEmpty ? List<String>.from(defaultRelays) : cleaned;

    _relaysLoaded = true;
    relays = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_customRelaysKey, next);
    } catch (e) {
      debugPrint('[Sync] Falha ao persistir relays customizados: $e');
    }
    await _reconnectWithNewRelays();
  }

  /// Clears the custom relay list and reverts to [defaultRelays].
  Future<void> resetRelaysToDefaults() async {
    _relaysLoaded = true;
    relays = List<String>.from(defaultRelays);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_customRelaysKey);
    } catch (e) {
      debugPrint('[Sync] Falha ao limpar relays customizados: $e');
    }
    await _reconnectWithNewRelays();
  }

  // Drops current sockets/statuses so the new relay set takes effect, then
  // eagerly re-opens (when an identity is loaded) so the UI shows fresh
  // per-relay statuses without waiting for the next periodic sync.
  Future<void> _reconnectWithNewRelays() async {
    await _closeNostr();
    _relayStatuses.clear();
    _emitRelayStatuses();
    if (isReady) {
      try {
        await _ensureConnected();
      } catch (e) {
        debugPrint('[Sync] Reconexão após troca de relays falhou: $e');
      }
    }
  }

  /// Validates and normalizes a relay URL. Returns null when invalid. Accepts
  /// `ws://`/`wss://`; a bare host gets `wss://` prefixed. Strips trailing `/`.
  static String? normalizeRelayUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) s = 'wss://$s';
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    if (uri.scheme != 'ws' && uri.scheme != 'wss') return null;
    if (uri.host.isEmpty) return null;
    // Normalize: keep scheme + authority + path without a trailing slash.
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return '${uri.scheme}://${uri.authority}$path';
  }

  Future<Nostr> _ensureConnected() async {
    await _ensureRelaysLoaded();
    _nostr ??= Nostr()..disableLogs();
    _syncActiveRelayList();
    if (!_relaysInitialized) {
      _relayStatuses
        ..clear()
        ..addEntries(
          relays.map(
            (url) => MapEntry(
              url,
              RelayConnectionInfo(url: url, status: RelayStatus.connecting),
            ),
          ),
        );
      _emitRelayStatuses();

      try {
        // dart_nostr connects to all relays in parallel with a 5s per-relay
        // timeout, but that guarantee lives in a third-party package — an
        // explicit outer timeout here ensures a misbehaving relay can never
        // hang the whole sync (and by extension the onboarding screen) with
        // no feedback.
        //
        // Note: onRelayListening only fires when a relay pushes unsolicited
        // data (e.g. a NOTICE), NOT on a bare successful connection — a
        // freshly connected relay that hasn't been sent a REQ yet stays
        // silent, so it is *not* used here to detect success. Success is
        // read from the websocket registry after init() settles instead.
        await _nostr!.relays
            .init(
              relaysUrl: relays,
              onRelayConnectionError: (relayUrl, error, socket) {
                _markRelayFailure(relayUrl);
                _relayStatuses[relayUrl] = RelayConnectionInfo(
                  url: relayUrl,
                  status: RelayStatus.error,
                  errorMessage: error?.toString(),
                );
                _emitRelayStatuses();
              },
              onRelayConnectionDone: (relayUrl, socket) {
                _markRelayFailure(relayUrl);
                _relayStatuses[relayUrl] = RelayConnectionInfo(
                  url: relayUrl,
                  status: RelayStatus.error,
                  errorMessage: 'Conexão encerrada',
                );
                _emitRelayStatuses();
              },
              onNoticeMessageFromRelay: _handleRelayNotice,
            )
            .timeout(const Duration(seconds: 10));
      } catch (e, st) {
        debugPrint('[Sync] Falha ao inicializar relays: $e\n$st');
      }

      // A relay that connected successfully but never sent anything and
      // never errored/closed has no callback to hang this off of — its
      // socket is registered the moment the handshake completes, so that
      // registry is the actual source of truth for "connected".
      final connectedRegistry = _nostr!.relays.relaysWebSocketsRegistry;
      for (final url in relays) {
        if (_relayStatuses[url]?.status == RelayStatus.error) continue;
        if (connectedRegistry.containsKey(url)) {
          _markRelaySuccess(url);
          _relayStatuses[url] = RelayConnectionInfo(
            url: url,
            status: RelayStatus.connected,
          );
        } else if (_relayStatuses[url]?.status == RelayStatus.connecting) {
          _markRelayFailure(url);
          _relayStatuses[url] = RelayConnectionInfo(
            url: url,
            status: RelayStatus.error,
            errorMessage: 'Tempo esgotado',
          );
        }
      }
      _emitRelayStatuses();

      // Nostr relays are redundant by design — proceed as long as at least
      // one relay is reachable instead of failing the whole sync because a
      // handful of the 20 configured relays are slow or offline.
      final anyConnected = _relayStatuses.values.any(
        (r) => r.status == RelayStatus.connected,
      );
      _relaysInitialized = anyConnected;
    } else {
      // Already initialized: dart_nostr auto-reconnects unconnected relays on
      // every push/pull/subscribe call internally, without our callbacks —
      // reconcile against its registry so drops/recoveries still update our
      // status map and cooldown bookkeeping.
      _reconcileRelayHealth();
    }
    if (!_relaysInitialized) {
      throw StateError('Falha ao conectar a qualquer relay Nostr');
    }
    return _nostr!;
  }

  Future<void> _closeNostr() async {
    await _stopLiveSync();
    await _stopUpdateListener();
    final stale = _nostr;
    _nostr = null;
    _relaysInitialized = false;
    _relayFailureCounts.clear();
    _relayCooldownUntil.clear();
    if (stale == null) return;
    try {
      await stale.relays.freeAllResources();
    } catch (e) {
      // Best-effort cleanup; a new instance will be created on next use.
      debugPrint('[Sync] Falha ao fechar conexões com relays: $e');
    }
  }

  Future<String> _getOrCreateLocalDeviceId() async {
    if (_localDeviceId != null) return _localDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_localDeviceIdKey);
    if (stored != null) {
      _localDeviceId = stored;
      return stored;
    }
    final id = _generateHexSalt();
    await prefs.setString(_localDeviceIdKey, id);
    _localDeviceId = id;
    return id;
  }

  static String _generateHexSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> dispose() async {
    await _closeNostr();
    await _identityController.close();
    await _peerConnectionsController.close();
    await _relayStatusController.close();
    await _liveEventController.close();
    await _appUpdateController.close();
  }
}
