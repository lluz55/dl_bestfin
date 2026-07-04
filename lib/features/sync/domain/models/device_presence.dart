class DevicePresenceInfo {
  final String deviceId;
  final String? deviceName;
  final String platform;
  final DateTime connectedAt;

  const DevicePresenceInfo({
    required this.deviceId,
    this.deviceName,
    required this.platform,
    required this.connectedAt,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'device_name': deviceName,
    'platform': platform,
    'connected_at': connectedAt.millisecondsSinceEpoch ~/ 1000,
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
      );
}
