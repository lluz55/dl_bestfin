/// Gera um par de chaves Nostr e exibe em hex e bech32 (npub/nsec).
///
/// Uso:
///   nix develop -c dart run scripts/generate_keypair.dart
library;

// Script de linha de comando: a saída via print() é a UI da ferramenta.
// ignore_for_file: avoid_print

import 'package:dart_nostr/dart_nostr.dart';

void main() {
  final n = Nostr()..disableLogs();
  final kp = n.keys.generateKeyPair();

  final npub = n.bech32.encodePublicKeyToNpub(kp.public);
  final nsec = n.bech32.encodePrivateKeyToNsec(kp.private);

  print('Hex (privada):  ${kp.private}');
  print('Hex (pública):  ${kp.public}');
  print('nsec:           $nsec');
  print('npub:           $npub');
}
