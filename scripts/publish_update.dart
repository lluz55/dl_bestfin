/// Publica um evento de notificação de nova versão nos relays Nostr.
///
/// Uso:
///   BESTFIN_DEV_NOSTR_PRIVKEY=<hex|nsec> dart run scripts/publish_update.dart \
///     --version 1.2.0 \
///     [--changelog "Descrição das mudanças"] \
///     [--download-url "https://github.com/user/bestfin/releases/tag/v1.2.0"] \
///     [--critical]
///
/// A chave privada do desenvolvedor deve ser fornecida via variável de ambiente
/// BESTFIN_DEV_NOSTR_PRIVKEY (nunca commite a chave no repositório).
/// Aceita hex (64 chars), nsec (bech32) ou caminho de arquivo.
///
/// Modo utilitário:
///   dart run scripts/publish_update.dart --to-hex <npub|nsec|hex>
///   Converte qualquer formato de chave para hex e imprime na stdout.
///
/// Evento kind:30078, d-tag 'app_update' (NIP-33, replaceable).
/// Conteúdo em JSON plain-text — sem cifragem: são anúncios públicos.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';

const _nostrKind = 30078;

const _defaultRelays = [
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.primal.net',
  'wss://relay.nostr.info',
  'wss://relay.nostr.net',
  'wss://nostr-pub.wellorder.net',
  'wss://relay.snort.social',
  'wss://offchain.pub',
];

/// Converte bech32 (nsec/npub) para hex, se necessário.
/// Retorna o próprio input se já for hex (64 chars).
String _toHex(String key) {
  if (key.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(key)) {
    return key;
  }
  final n = Nostr()..disableLogs();
  if (key.startsWith('nsec1')) {
    return n.bech32.decodeNsecKeyToPrivateKey(key);
  }
  if (key.startsWith('npub1')) {
    return n.bech32.decodeNpubKeyToPublicKey(key);
  }
  throw ArgumentError('Formato de chave inválido: $key');
}

Future<void> main(List<String> args) async {
  // ── Modo utilitário: --to-hex converte qualquer chave para hex ──
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--to-hex' && i + 1 < args.length) {
      print(_toHex(args[i + 1]));
      return;
    }
  }

  String? version;
  String? changelog;
  String? downloadUrl;
  var isCritical = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--version' || '-v':
        version = args[++i];
      case '--changelog' || '-c':
        changelog = args[++i];
      case '--download-url' || '-u':
        downloadUrl = args[++i];
      case '--critical':
        isCritical = true;
    }
  }

  if (version == null) {
    stderr.writeln('Uso: dart run scripts/publish_update.dart --version X.Y.Z');
    exit(1);
  }

  final privkeyRaw = Platform.environment['BESTFIN_DEV_NOSTR_PRIVKEY'];
  if (privkeyRaw == null || privkeyRaw.isEmpty) {
    stderr.writeln('Erro: variável BESTFIN_DEV_NOSTR_PRIVKEY não definida.');
    exit(1);
  }

  final privkeyHex = _toHex(privkeyRaw);
  // Se veio como nsec, avisa que foi convertido
  if (privkeyRaw != privkeyHex) {
    stdout.writeln('Chave privada convertida de bech32 para hex.');
  }

  final payload = jsonEncode({
    'version': version,
    if (changelog != null) 'changelog': changelog,
    if (downloadUrl != null) 'download_url': downloadUrl,
    'published_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'is_critical': isCritical,
  });

  stdout.writeln('Publicando atualização v$version nos relays Nostr...');

  final nostr = Nostr()..disableLogs();
  final kp = nostr.keys.generateKeyPairFromExistingPrivateKey(privkeyHex);
  stdout.writeln('Pubkey: ${kp.public}');

  await nostr.relays.init(relaysUrl: _defaultRelays).timeout(
    const Duration(seconds: 10),
  );

  final event = NostrEvent.fromPartialData(
    kind: _nostrKind,
    content: payload,
    keyPairs: kp,
    tags: [
      ['d', 'app_update'],
      ['t', 'app_update'],
    ],
    createdAt: DateTime.now(),
  );

  final result = await nostr.relays
      .sendEventToRelaysAsync(event, timeout: const Duration(seconds: 15));

  if (result.isEventAccepted ?? true) {
    stdout.writeln('OK — evento ${event.id} aceito pelos relays.');
  } else {
    stderr.writeln('AVISO: nenhum relay confirmou o evento.');
  }

  await nostr.relays.freeAllResources();
}
