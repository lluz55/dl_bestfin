import 'dart:convert';

/// Version of the sync payload format published to relays.
///
/// Bump this whenever the payload of ANY synced entity changes shape —
/// including just adding a field. Devices running an older app defer (skip
/// now, re-read after updating) any record whose version is above their own
/// instead of applying it. Without the bump, a stale device would merge the
/// snapshot minus the fields it doesn't know, then republish it on the next
/// local edit — silently wiping those fields for every peer.
const kSyncSchemaVersion = 1;

// Keys allowed inside an envelope object. Used to tell an envelope apart from
// a raw pre-envelope entity JSON (which would carry its own domain fields).
const _envelopeKeys = {'v', 'payload', 't', 'id', 'del'};

/// Wraps a plaintext entity payload in the versioned wire envelope that gets
/// encrypted into the Nostr event content.
///
/// [entityType], [entityId] and [isDeleted] are embedded here — inside the
/// encrypted content — instead of being published as plaintext Nostr tags, so
/// a relay/observer can no longer read what kind of entities a user has, their
/// ids, or when they are deleted. The event's `d` tag carries only an opaque
/// HMAC of the entity (see E2ECryptoService.deriveEntityTag) for replaceability.
String encodeSyncEnvelope(
  String payload, {
  int schemaVersion = kSyncSchemaVersion,
  String? entityType,
  String? entityId,
  bool? isDeleted,
}) => jsonEncode({
  'v': schemaVersion,
  'payload': payload,
  't': ?entityType,
  'id': ?entityId,
  'del': ?isDeleted,
});

/// Inverse of [encodeSyncEnvelope]. Events published before the envelope
/// existed carry the entity JSON directly; those decode as version 1 (the
/// envelope was introduced while the payload shape was still v1, so the two
/// forms are equivalent). [entityType]/[entityId]/[isDeleted] are null for
/// events written by builds that still published them as plaintext tags — the
/// caller falls back to the event's tags in that case.
({
  int schemaVersion,
  String payload,
  String? entityType,
  String? entityId,
  bool? isDeleted,
})
decodeSyncEnvelope(String plain) {
  try {
    final decoded = jsonDecode(plain);
    if (decoded is Map<String, dynamic> &&
        decoded['v'] is int &&
        decoded['payload'] is String &&
        decoded.keys.every(_envelopeKeys.contains)) {
      return (
        schemaVersion: decoded['v'] as int,
        payload: decoded['payload'] as String,
        entityType: decoded['t'] as String?,
        entityId: decoded['id'] as String?,
        isDeleted: decoded['del'] as bool?,
      );
    }
  } catch (_) {}
  return (
    schemaVersion: 1,
    payload: plain,
    entityType: null,
    entityId: null,
    isDeleted: null,
  );
}

class SyncRecord {
  final String entityType;
  final String entityId;
  final String payload;
  final int updatedAt;
  final bool isDeleted;

  /// Payload format version this record was written with (see
  /// [kSyncSchemaVersion]). Records pulled from a peer on a newer app carry a
  /// higher value and must not be merged by this build.
  final int schemaVersion;

  const SyncRecord({
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.isDeleted,
    this.schemaVersion = kSyncSchemaVersion,
  });

  Map<String, dynamic> toJson() => {
    'entity_type': entityType,
    'entity_id': entityId,
    'payload': payload,
    'updated_at': updatedAt,
    'is_deleted': isDeleted,
    'schema_version': schemaVersion,
  };

  factory SyncRecord.fromJson(Map<String, dynamic> json) => SyncRecord(
    entityType: json['entity_type'] as String? ?? '',
    entityId: json['entity_id'] as String? ?? '',
    payload: json['payload'] as String? ?? '{}',
    updatedAt: json['updated_at'] as int? ?? 0,
    isDeleted: json['is_deleted'] as bool? ?? false,
    schemaVersion: json['schema_version'] as int? ?? 1,
  );
}
