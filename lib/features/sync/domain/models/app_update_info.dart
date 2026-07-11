class AppUpdateInfo {
  final String version;
  final String? changelog;
  final String? downloadUrl;
  final DateTime publishedAt;

  /// When true the release contains a breaking change (e.g. schema migration
  /// that older clients can't read). The UI may choose to surface this more
  /// prominently, but the app never forces an update — the user decides.
  final bool isCritical;

  const AppUpdateInfo({
    required this.version,
    this.changelog,
    this.downloadUrl,
    required this.publishedAt,
    this.isCritical = false,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'changelog': changelog,
    'download_url': downloadUrl,
    'published_at': publishedAt.millisecondsSinceEpoch ~/ 1000,
    'is_critical': isCritical,
  };

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) => AppUpdateInfo(
    version: json['version'] as String,
    changelog: json['changelog'] as String?,
    downloadUrl: json['download_url'] as String?,
    publishedAt: json['published_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (json['published_at'] as int) * 1000,
          )
        : DateTime.now(),
    isCritical: json['is_critical'] as bool? ?? false,
  );

  /// Returns true when this update's version is strictly newer than [current].
  bool isNewerThan(String current) => _compareVersions(version, current) > 0;

  static int _compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final ap = parts(a);
    final bp = parts(b);
    for (var i = 0; i < 3; i++) {
      final diff = (i < ap.length ? ap[i] : 0) - (i < bp.length ? bp[i] : 0);
      if (diff != 0) return diff;
    }
    return 0;
  }
}
