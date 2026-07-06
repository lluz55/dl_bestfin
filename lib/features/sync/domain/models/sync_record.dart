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

/// Wraps a plaintext entity payload in the versioned wire envelope that gets
/// encrypted into the Nostr event content.
String encodeSyncEnvelope(
  String payload, {
  int schemaVersion = kSyncSchemaVersion,
}) => jsonEncode({'v': schemaVersion, 'payload': payload});

/// Inverse of [encodeSyncEnvelope]. Events published before the envelope
/// existed carry the entity JSON directly; those decode as version 1 (the
/// envelope was introduced while the payload shape was still v1, so the two
/// forms are equivalent).
({int schemaVersion, String payload}) decodeSyncEnvelope(String plain) {
  try {
    final decoded = jsonDecode(plain);
    if (decoded is Map<String, dynamic> &&
        decoded.length == 2 &&
        decoded['v'] is int &&
        decoded['payload'] is String) {
      return (
        schemaVersion: decoded['v'] as int,
        payload: decoded['payload'] as String,
      );
    }
  } catch (_) {}
  return (schemaVersion: 1, payload: plain);
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
