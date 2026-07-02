import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ndk/ndk.dart' as ndk;

import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';

const _encMasterKeyKey = 'nostr_encrypted_master_key';
const _kdfSaltKey = 'nostr_kdf_salt';

// kind:30078 — NIP-78 "application-specific data", replaceable by d-tag
const _nostrKind = 30078;

const defaultRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.nostr.band',
  'wss://relay.primal.net',
];

class NostrSyncService implements SyncTransport {
  static const _storage = FlutterSecureStorage();

  final AppDatabase _db;
  List<String> relays;

  Uint8List? _masterKey;
  String? _privkeyHex;
  String? _pubkeyHex;
  SyncIdentity? _identity;
  ndk.Ndk? _ndkInstance;

  final _identityController = StreamController<SyncIdentity?>.broadcast();

  NostrSyncService(this._db, {List<String>? relays})
      : relays = relays ?? defaultRelays;

  // ── SyncTransport interface ───────────────────────────────────────────────

  @override
  Stream<SyncIdentity?> get identityChanges async* {
    yield _identity;
    yield* _identityController.stream;
  }

  @override
  bool get isReady => _masterKey != null && _privkeyHex != null;

  @override
  Uint8List? get masterKey => _masterKey;

  @override
  Future<SyncIdentity?> loadIdentity() async {
    if (_identity != null) return _identity;
    final encMK = await _storage.read(key: _encMasterKeyKey);
    final kdfSalt = await _storage.read(key: _kdfSaltKey);
    if (encMK == null || kdfSalt == null) return null;
    try {
      final kek = await E2ECryptoService.deriveKEK('device-local', kdfSalt);
      final masterKey = await E2ECryptoService.decryptMasterKey(kek, encMK);
      return _restoreIdentity(masterKey);
    } catch (_) {
      await _storage.delete(key: _encMasterKeyKey);
      await _storage.delete(key: _kdfSaltKey);
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
    await _closeNdk();
    _masterKey = null;
    _privkeyHex = null;
    _pubkeyHex = null;
    _identity = null;
    await _storage.delete(key: _encMasterKeyKey);
    await _storage.delete(key: _kdfSaltKey);
    _identityController.add(null);
  }

  @override
  Future<void> pushRecords(List<SyncRecord> records) async {
    if (!isReady) throw StateError('Identidade Nostr não carregada');
    final ndkInst = _ensureNdk();

    for (final record in records) {
      final encPayload = await E2ECryptoService.encryptPayload(
        _masterKey!,
        record.payload,
      );

      final event = ndk.Nip01Event(
        pubKey: _pubkeyHex!,
        kind: _nostrKind,
        tags: [
          ['d', record.entityId],
          ['t', record.entityType],
          if (record.isDeleted) ['deleted', 'true'],
        ],
        content: encPayload,
        createdAt: record.updatedAt,
      );

      await ndkInst.config.eventSigner!.sign(event);

      // Persist locally before publishing (relay resilience)
      await _db.nostrEventLogDao.save(
        NostrEventLogItem(
          eventId: event.id,
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
        ndkInst.broadcast.broadcast(
          nostrEvent: event,
          specificRelays: relays,
        );
        await _db.nostrEventLogDao.markPublished(event.id);
      } catch (_) {
        // Will be retried by replayUnpublished() on next connection
      }
    }
  }

  @override
  Future<List<SyncRecord>> pullRecords({required int since}) async {
    if (!isReady) throw StateError('Identidade Nostr não carregada');
    final ndkInst = _ensureNdk();

    final filter = ndk.Filter(
      authors: [_pubkeyHex!],
      kinds: [_nostrKind],
      since: since,
    );

    final events = await ndkInst.requests.query(
      filters: [filter],
      explicitRelays: relays,
    ).future;

    final records = <SyncRecord>[];
    for (final event in events) {
      try {
        final plainPayload = await E2ECryptoService.decryptPayload(
          _masterKey!,
          event.content,
        );
        final dTag = event.tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'd',
          orElse: () => [],
        );
        final tTag = event.tags.firstWhere(
          (t) => t.isNotEmpty && t[0] == 't',
          orElse: () => [],
        );
        final isDeleted = event.tags.any(
          (t) => t.length >= 2 && t[0] == 'deleted' && t[1] == 'true',
        );
        if (dTag.length < 2 || tTag.length < 2) continue;

        records.add(SyncRecord(
          entityId: dTag[1],
          entityType: tTag[1],
          payload: plainPayload,
          updatedAt: event.createdAt,
          isDeleted: isDeleted,
        ));
      } catch (_) {
        // Skip events that cannot be decrypted (wrong key or corrupted)
      }
    }
    return records;
  }

  /// Re-publish events that were saved locally but not yet confirmed by a relay.
  Future<void> replayUnpublished() async {
    if (!isReady) return;
    final ndkInst = _ensureNdk();
    final pending = await _db.nostrEventLogDao.getUnpublished();
    for (final item in pending) {
      try {
        final event = ndk.Nip01Event(
          pubKey: _pubkeyHex!,
          kind: _nostrKind,
          tags: [
            ['d', item.entityId],
            ['t', item.entityType],
            if (item.isDeleted) ['deleted', 'true'],
          ],
          content: item.payload,
          createdAt: item.updatedAt,
        );
        await ndkInst.config.eventSigner!.sign(event);
        ndkInst.broadcast.broadcast(
          nostrEvent: event,
          specificRelays: relays,
        );
        await _db.nostrEventLogDao.markPublished(item.eventId);
      } catch (_) {
        // Try again next cycle
      }
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  // Restore identity from already-decrypted masterKey without touching storage.
  Future<SyncIdentity> _restoreIdentity(Uint8List masterKey) async {
    _masterKey = masterKey;
    _privkeyHex = await E2ECryptoService.deriveNostrPrivkey(masterKey);
    _pubkeyHex = E2ECryptoService.nostrPubkeyFromPrivkey(_privkeyHex!);
    _identity = SyncIdentity(publicKey: _pubkeyHex!);
    _identityController.add(_identity);
    return _identity!;
  }

  Future<SyncIdentity> _activateIdentity(Uint8List masterKey) async {
    await _closeNdk(); // force re-init with new signer, closing stale sockets
    _masterKey = masterKey;
    _privkeyHex = await E2ECryptoService.deriveNostrPrivkey(masterKey);
    _pubkeyHex = E2ECryptoService.nostrPubkeyFromPrivkey(_privkeyHex!);
    _identity = SyncIdentity(publicKey: _pubkeyHex!);

    // Persist encrypted masterKey for recovery without mnemonic re-entry.
    final salt = _generateHexSalt();
    // Use a fixed derivation for the storage KEK — actual PIN/biometric wrapping
    // can be layered on top by the caller; here we use a device-unique salt.
    final kek = await E2ECryptoService.deriveKEK('device-local', salt);
    final encMK = await E2ECryptoService.encryptMasterKey(kek, masterKey);
    await _storage.write(key: _encMasterKeyKey, value: encMK);
    await _storage.write(key: _kdfSaltKey, value: salt);

    _identityController.add(_identity);
    return _identity!;
  }

  ndk.Ndk _ensureNdk() {
    if (_ndkInstance != null) return _ndkInstance!;
    final signer = ndk.Bip340EventSigner(
      privateKey: _privkeyHex,
      publicKey: _pubkeyHex!,
    );
    _ndkInstance = ndk.Ndk(
      ndk.NdkConfig(
        eventVerifier: ndk.Bip340EventVerifier(),
        eventSigner: signer,
        cache: ndk.MemCacheManager(),
        bootstrapRelays: relays,
        engine: ndk.NdkEngine.RELAY_SETS,
      ),
    );
    return _ndkInstance!;
  }

  /// Closes the WebSocket transports of the current ndk instance before it's
  /// discarded, so stale relay connections don't keep delivering messages
  /// after the app has moved on (surfaces as "Cannot add event after
  /// closing" once the identity/signer has already changed).
  Future<void> _closeNdk() async {
    final stale = _ndkInstance;
    _ndkInstance = null;
    if (stale == null) return;
    try {
      await stale.relays.closeAllTransports();
    } catch (_) {
      // Best-effort cleanup; a new instance will be created on next use.
    }
  }

  static String _generateHexSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> dispose() async {
    await _closeNdk();
    await _identityController.close();
  }
}
