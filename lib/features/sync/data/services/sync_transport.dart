import 'dart:typed_data';

import 'package:bestfin/features/sync/domain/models/sync_identity.dart';
import 'package:bestfin/features/sync/domain/models/sync_record.dart';

export 'package:bestfin/features/sync/domain/models/sync_record.dart';
export 'package:bestfin/features/sync/domain/models/sync_identity.dart';

abstract class SyncTransport {
  Stream<SyncIdentity?> get identityChanges;

  /// True when identity is loaded and masterKey is available — safe to sync.
  bool get isReady;

  Uint8List? get masterKey;

  /// Load identity from secure storage. Returns null if no identity exists yet.
  Future<SyncIdentity?> loadIdentity();

  /// Generate a new masterKey + mnemonic and persist identity locally.
  Future<({SyncIdentity identity, String mnemonic})> createIdentity();

  /// Import identity from a 24-word mnemonic and persist locally.
  Future<SyncIdentity> importIdentity(String mnemonic);

  Future<void> signOut();

  Future<void> pushRecords(List<SyncRecord> records);
  Future<List<SyncRecord>> pullRecords({required int since});
}
