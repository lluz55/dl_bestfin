class SyncRecord {
  final String entityType;
  final String entityId;
  final String payload;
  final int updatedAt;
  final bool isDeleted;

  const SyncRecord({
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.isDeleted,
  });

  Map<String, dynamic> toJson() => {
    'entity_type': entityType,
    'entity_id': entityId,
    'payload': payload,
    'updated_at': updatedAt,
    'is_deleted': isDeleted,
  };

  factory SyncRecord.fromJson(Map<String, dynamic> json) => SyncRecord(
    entityType: json['entity_type'] as String? ?? '',
    entityId: json['entity_id'] as String? ?? '',
    payload: json['payload'] as String? ?? '{}',
    updatedAt: json['updated_at'] as int? ?? 0,
    isDeleted: json['is_deleted'] as bool? ?? false,
  );
}
