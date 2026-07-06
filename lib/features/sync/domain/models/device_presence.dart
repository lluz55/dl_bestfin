class DevicePresenceInfo {
  final String deviceId;
  final String? deviceName;
  final String platform;
  final DateTime connectedAt;

  /// Sync payload version the peer device publishes with (see
  /// [kSyncSchemaVersion]). Null for presence events from builds that predate
  /// the field. A value above our own means the peer runs a newer app.
  final int? schemaVersion;

  const DevicePresenceInfo({
    required this.deviceId,
    this.deviceName,
    required this.platform,
    required this.connectedAt,
    this.schemaVersion,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'device_name': deviceName,
    'platform': platform,
    'connected_at': connectedAt.millisecondsSinceEpoch ~/ 1000,
    'schema_version': schemaVersion,
  };

  factory DevicePresenceInfo.fromJson(Map<String, dynamic> json) =>
      DevicePresenceInfo(
        deviceId: json['device_id'] as String? ?? '',
        deviceName: json['device_name'] as String?,
        platform: json['platform'] as String? ?? 'unknown',
        connectedAt: json['connected_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (json['connected_at'] as int) * 1000,
              )
            : DateTime.now(),
        schemaVersion: json['schema_version'] as int?,
      );
}
