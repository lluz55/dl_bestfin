import 'dart:async';
import 'dart:io';

import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:bestfin/features/sync/data/services/nostr_sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/cli/tui/sync_engine.dart';

/// `bestfin syncd` — daemon headless de sincronização (task 61).
///
/// Roda o mesmo [TuiSyncEngine] da TUI (live subscription Nostr, push com
/// debounce e poll de 1min) sem terminal nem janela, feito para um serviço
/// systemd (módulo NixOS). A identidade vem de um arquivo de chave externo
/// (`--key-file` ou `BESTFIN_SYNC_KEYFILE`) contendo o payload de pareamento
/// `BESTFIN:1:<hex>` ou o mnemônico BIP39. O arquivo pode estar em texto
/// plano ou cifrado com SOPS (YAML/JSON) — a descriptografia é feita pelo
/// próprio daemon via `sops -d`, que usa `SOPS_AGE_KEY_FILE`/`SOPS_AGE_KEY`
/// (mesmo mecanismo do devShell e do sops-nix). A chave nunca é lida nem
/// gravada pelo armazenamento seguro do app.
///
/// Exit codes: 0 shutdown limpo, 1 erro, 2 uso inválido.
Future<int> runSyncDaemon({
  required AppDatabase db,
  String? keyFile,
}) async {
  // 1. Identidade: arquivo de chave obrigatório no modo daemon.
  final keyPath = keyFile ?? Platform.environment['BESTFIN_SYNC_KEYFILE'];
  if (keyPath == null || keyPath.trim().isEmpty) {
    stderr.writeln(
      'syncd: informe a identidade via --key-file <path> '
      '(ou env BESTFIN_SYNC_KEYFILE). O arquivo deve conter o payload '
      'BESTFIN:1:<hex> ou o mnemônico de 24 palavras — em texto plano '
      'ou cifrado com SOPS.',
    );
    await db.close();
    return 2;
  }
  final keyContent = _readKeyFile(keyPath);
  if (keyContent == null) {
    stderr.writeln('syncd: arquivo de chave ilegível ou vazio (path omitido).');
    await db.close();
    return 1;
  }
  var identity = extractIdentityContent(keyContent);
  if (identity == null) {
    // Não é um payload válido — pode ser um arquivo cifrado com SOPS.
    final decrypted = await decryptKeyFileWithSops(keyPath);
    if (decrypted != null) {
      identity = extractIdentityContent(decrypted);
    }
  }
  if (identity == null) {
    stderr.writeln(
      'syncd: conteúdo inválido — esperado BESTFIN:1:<hex> ou mnemônico BIP39 '
      '(em texto plano ou cifrado com SOPS; o sops -d falhou, não está no '
      'PATH ou o conteúdo descriptografado não contém o payload).',
    );
    await db.close();
    return 1;
  }

  final transport = NostrSyncService(db);
  final engine = TuiSyncEngine(
    db,
    transport,
    syncService: SyncService(db, transport),
    startLiveSync: transport.startLiveSync,
    liveEvents: transport.liveEvents,
  );
  final stateSub = engine.stateStream.listen(_logState);
  final noticeSub = engine.notices.listen((n) => stdout.writeln('sync: $n'));

  try {
    // Ativa a identidade em memória (bypass do secure storage). O start() do
    // engine então a encontra via loadIdentity() e segue o fluxo normal.
    final masterKey = E2ECryptoService.mnemonicToMasterKey(identity);
    await transport.useMasterKey(masterKey);
    await engine.start();
    if (!engine.state.hasIdentity) {
      stderr.writeln('syncd: identidade não ativada — abortando.');
      return 1;
    }
    stdout.writeln('syncd: ativo (pull ao vivo, push com debounce, poll 1min).');

    // Shutdown gracioso em SIGTERM/SIGINT — systemd envia SIGTERM no stop.
    final shutdown = Completer<int>();
    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) {
        if (!shutdown.isCompleted) shutdown.complete(0);
      });
    }
    ProcessSignal.sigint.watch().listen((_) {
      if (!shutdown.isCompleted) shutdown.complete(0);
    });
    final code = await shutdown.future;
    stdout.writeln('syncd: encerrando…');
    return code;
  } catch (e) {
    stderr.writeln('syncd: erro fatal: $e');
    return 1;
  } finally {
    await stateSub.cancel();
    await noticeSub.cancel();
    try {
      await engine.dispose();
    } catch (_) {}
    try {
      await transport.dispose();
    } catch (_) {}
    try {
      await db.close();
    } catch (_) {}
  }
}

/// Lê o arquivo de chave. O conteúdo nunca é logado nem impresso — só
/// validado. Retorna null se ilegível/vazio.
String? _readKeyFile(String path) {
  try {
    final f = File(path);
    if (!f.existsSync()) return null;
    final content = f.readAsStringSync().trim();
    return content.isEmpty ? null : content;
  } catch (_) {
    return null;
  }
}

/// Extrai o payload de identidade de um conteúdo já descriptografado.
///
/// Aceita o payload solto (`BESTFIN:1:<hex>` ou mnemônico) ou um documento
/// estruturado (YAML/JSON cifrado pelo SOPS como mapa — o SOPS não cifra
/// strings soltas), ex: `identity: BESTFIN:1:...`. Retorna null se nada
/// casar.
String? extractIdentityContent(String content) {
  final direct = E2ECryptoService.qrPayloadToMnemonic(content);
  if (direct != null) return direct;
  // Payload BESTFIN:1 em qualquer lugar do documento (valor de chave YAML/JSON).
  final payload = RegExp(r'BESTFIN:1:[0-9A-Fa-f]{64}').firstMatch(content);
  if (payload != null) {
    return E2ECryptoService.qrPayloadToMnemonic(payload.group(0)!);
  }
  // Mnemônico como valor de uma chave (`identity: palavra1 ... palavra24`).
  for (final line in content.split('\n')) {
    final idx = line.indexOf(':');
    if (idx <= 0) continue;
    final value = line.substring(idx + 1).trim().replaceAll('"', '').trim();
    final mnemonic = E2ECryptoService.qrPayloadToMnemonic(value);
    if (mnemonic != null) return mnemonic;
  }
  return null;
}

/// Descriptografa um key-file cifrado com SOPS (`sops -d <path>`).
///
/// O `sops` resolve a chave age por conta própria (`SOPS_AGE_KEY_FILE`,
/// `SOPS_AGE_KEY` ou `~/.config/sops/age/keys.txt`) — o mesmo mecanismo do
/// devShell Nix e do sops-nix em produção. O conteúdo descriptografado é
/// mantido apenas em memória. Retorna null em qualquer falha; a mensagem de
/// erro do sops vai para o stderr do daemon (sem material da chave).
Future<String?> decryptKeyFileWithSops(String path) async {
  try {
    final result = await Process.run('sops', ['-d', path]);
    if (result.exitCode != 0) return null;
    final out = (result.stdout as String).trim();
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

/// Log estruturado de uma linha (capturado pelo journald). Nunca inclui
/// caminhos de banco nem material da chave.
void _logState(TuiSyncState s) {
  final parts = <String>[
    switch (s.status) {
      TuiSyncStatus.syncing => 'syncing',
      TuiSyncStatus.success => 'ok',
      TuiSyncStatus.error => 'error',
      TuiSyncStatus.idle => 'idle',
      TuiSyncStatus.inactive => 'inactive',
    },
    if (s.pendingCount > 0) 'pending=${s.pendingCount}',
    if (s.lastPushed > 0) 'pushed=${s.lastPushed}',
    if (s.lastPulled > 0) 'pulled=${s.lastPulled}',
    if (s.lastFailed > 0) 'failed=${s.lastFailed}',
    if (s.lastDeferred > 0) 'deferred=${s.lastDeferred}',
    if (s.updateRequired) 'update_required=true',
    if (s.errorMessage != null) 'error=${s.errorMessage}',
  ];
  stdout.writeln('syncd: ${parts.join(' ')}');
}
