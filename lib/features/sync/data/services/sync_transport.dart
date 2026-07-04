import 'dart:typed_data';

import 'package:bestfin/features/sync/domain/models/device_presence.dart';
import 'package:bestfin/features/sync/domain/models/relay_connection_info.dart';
import 'package:bestfin/features/sync/domain/models/sync_identity.dart';
import 'package:bestfin/features/sync/domain/models/sync_record.dart';

export 'package:bestfin/features/sync/domain/models/device_presence.dart';
export 'package:bestfin/features/sync/domain/models/relay_connection_info.dart';
export 'package:bestfin/features/sync/domain/models/sync_record.dart';
export 'package:bestfin/features/sync/domain/models/sync_identity.dart';

abstract class SyncTransport {
  Stream<SyncIdentity?> get identityChanges;

  /// Currently loaded identity, or null when signed out.
  SyncIdentity? get identity;

  /// Emits whenever a peer device using the same identity comes online.
  Stream<DevicePresenceInfo> get peerConnections;

  /// True when identity is loaded and masterKey is available — safe to sync.
  bool get isReady;

  Uint8List? get masterKey;

  /// Per-relay connection status as of the last (re)connect attempt. Empty
  /// until the first sync call opens the relay websockets.
  Map<String, RelayConnectionInfo> get relayStatuses;

  /// Emits the full relay status map whenever any individual relay's status
  /// changes. Replays the current snapshot to new listeners.
  Stream<Map<String, RelayConnectionInfo>> get relayStatusChanges;

  /// Load identity from secure storage. Returns null if no identity exists yet.
  Future<SyncIdentity?> loadIdentity();

  /// Generate a new masterKey + mnemonic and persist identity locally.
  Future<({SyncIdentity identity, String mnemonic})> createIdentity();

  /// Import identity from a 24-word mnemonic and persist locally.
  Future<SyncIdentity> importIdentity(String mnemonic);

  Future<void> signOut();

  /// [onProgress] reports, after each record is processed, how many records
  /// have been sent so far and the cumulative ciphertext bytes transmitted.
  Future<void> pushRecords(
    List<SyncRecord> records, {
    void Function(int sentCount, int bytesSent)? onProgress,
  });

  /// [onProgress] reports, as pages of events arrive from the relays, how
  /// many raw events have been received so far and the cumulative ciphertext
  /// bytes downloaded (before decryption/filtering).
  Future<List<SyncRecord>> pullRecords({
    required int since,
    void Function(int receivedCount, int bytesReceived)? onProgress,
  });

  /// Publish this device's presence so peers can detect it on their next pull.
  Future<void> pushPresence();

  /// Re-attempt delivery of records that were persisted locally but never
  /// confirmed as published (e.g. relay unreachable at the time).
  Future<void> replayUnpublished();
}
