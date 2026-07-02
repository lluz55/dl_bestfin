class SyncIdentity {
  /// Nostr public key — hex, 64 chars. Derived deterministically from masterKey.
  final String publicKey;
  final String? displayName;

  const SyncIdentity({required this.publicKey, this.displayName});
}
