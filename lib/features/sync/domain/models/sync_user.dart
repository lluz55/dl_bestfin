class SyncUser {
  final String id;
  final String email;
  final String? displayName;
  final DateTime? createdAt;

  const SyncUser({
    required this.id,
    required this.email,
    this.displayName,
    this.createdAt,
  });
}
