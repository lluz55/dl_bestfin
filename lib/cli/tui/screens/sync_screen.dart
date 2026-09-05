import 'package:bestfin/cli/tui/qr.dart';
import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/sync_engine.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/sync/data/services/e2e_crypto_service.dart';
import 'package:bestfin/features/sync/domain/models/relay_connection_info.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;

/// Sincronização: usa o engine residente da sessão ([TuiSyncEngine]) —
/// live subscription, fila, identidade Nostr, relays e pareamento por QR.
///
/// A identidade e a lista de relays vivem no armazenamento seguro do sistema
/// (o mesmo que a GUI usa). Quando esse armazenamento não está acessível a
/// partir do terminal, as ações que dependem dele falham com uma mensagem
/// clara — o restante da tela (fila, histórico) continua funcionando, já que
/// lê direto do banco.
class SyncScreen extends Screen {
  SyncScreen(super.ctx);

  @override
  String get title => 'Sincronização';

  @override
  Future<void> run() async {
    // Garante o engine residente mesmo quando a tela é aberta direta
    // (`bestfin tui sincronização`).
    await ctx.sync.start();

    while (true) {
      final st = ctx.sync.state;
      final pending = await _pendingCount();
      final synced = await _syncedCount();

      final choice = Term.select(
        title,
        items: const [
          'Ver fila de sincronização',
          'Sincronizar agora',
          'Status ao vivo (relays e dispositivos)',
          'Identidade (chave Nostr)',
          'Parear por QR (Android escaneia esta tela)',
          'Relays',
          'Histórico de eventos',
        ],
        subtitle:
            '${st.statusLine(onlineRelays: ctx.sync.onlineRelays, peers: ctx.sync.peers.length)} • '
            '$pending item(ns) pendente(s) • $synced já sincronizado(s)',
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          await _queue();
        case 1:
          await _syncNow();
        case 2:
          await _liveStatus();
        case 3:
          await _identity();
        case 4:
          await _pairingQr();
        case 5:
          await _relays();
        case 6:
          await _eventLog();
      }
    }
  }

  Future<int> _pendingCount() async {
    final rows = await (ctx.db.select(
      ctx.db.syncQueue,
    )..where((t) => t.synced.equals(false))).get();
    return rows.length;
  }

  Future<int> _syncedCount() async {
    final rows = await (ctx.db.select(
      ctx.db.syncQueue,
    )..where((t) => t.synced.equals(true))).get();
    return rows.length;
  }

  Future<void> _queue() async {
    final rows =
        await (ctx.db.select(ctx.db.syncQueue)
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(500))
            .get();

    Term.pager(
      'Fila de sincronização',
      [
        '',
        if (rows.isEmpty)
          '  ${Term.gray}Fila vazia — tudo publicado.${Term.reset}',
        ...rows.map(
          (r) =>
              '  ${r.synced ? Term.c('✓', Term.green) : Term.c('•', Term.yellow)} '
              '${Term.formatDate(r.createdAt)}  '
              '${Term.pad(r.entityType, 16)} '
              '${Term.pad(r.operation, 8)} '
              '${Term.gray}${Term.truncate(r.entityId, 38)}${Term.reset}'
              '${r.attempts > 0 ? ' ${Term.c('${r.attempts} tentativa(s)', Term.yellow)}' : ''}',
        ),
        '',
      ],
      subtitle: '${rows.length} registro(s) mais recentes',
    );
  }

  Future<void> _syncNow() async {
    Term.clear();
    Term.header('Sincronizar agora');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Publica a fila local nos relays e busca as alterações '
      'dos outros dispositivos. O engine residente continua sincronizando '
      'em segundo plano.${Term.reset}',
    );
    Term.writeln();
    if (!Term.confirm('Iniciar?', defaultYes: true)) return;
    Term.writeln();

    await guard(() async {
      if (!ctx.sync.state.hasIdentity) {
        throw const _SyncUnavailable(
          'Nenhuma identidade de sincronização carregada. '
          'Configure-a em "Identidade" ou pelo app gráfico.',
        );
      }
      await ctx.sync.syncNow();
      final st = ctx.sync.state;
      Term.writeln();
      if (st.status == TuiSyncStatus.error) {
        Term.error(st.errorMessage ?? 'Falha ao sincronizar.');
      } else {
        Term.success(
          'Enviados ${st.lastPushed} • recebidos ${st.lastPulled} • '
          'falhas ${st.lastFailed}'
          '${st.lastDeferred > 0 ? ' • adiados ${st.lastDeferred} (atualize o app)' : ''}',
        );
      }
    });
    Term.pause();
  }

  /// Painel ao vivo: relays e dispositivos conhecidos, com os mesmos dados
  /// que a GUI mostra (`relayStatuses` + presença de peers).
  Future<void> _liveStatus() async {
    Term.clear();
    Term.header('Status ao vivo da sincronização');
    Term.writeln();

    final engine = ctx.sync;
    if (!engine.state.hasIdentity) {
      Term.writeln(
        '  ${Term.gray}Sem identidade — o sync residente está inativo. '
        'A TUI segue funcionando offline.${Term.reset}',
      );
      Term.pause();
      return;
    }

    final st = engine.state;
    Term.writeln(
      '  Estado: ${st.statusLine(onlineRelays: engine.onlineRelays, peers: engine.peers.length)}',
    );
    if (st.lastSyncAt != null) {
      Term.writeln('  Última sync: ${Term.formatDate(st.lastSyncAt!)}');
    }
    if (st.updateRequired) {
      Term.writeln();
      Term.warn(
        'Há ${st.lastDeferred} registro(s) de uma versão mais nova do app — '
        'atualize o BestFin para recebê-los.',
      );
    }
    Term.writeln();
    Term.writeln('  ${Term.bold}Relays${Term.reset}');
    final statuses = engine.transport.relayStatuses;
    if (statuses.isEmpty) {
      Term.writeln(
        '    ${Term.gray}nenhum status ainda — aguarde uma sync${Term.reset}',
      );
    }
    for (final r in statuses.values) {
      final color = switch (r.status) {
        RelayStatus.connected => Term.green,
        RelayStatus.connecting => Term.yellow,
        RelayStatus.error => Term.red,
      };
      Term.writeln(
        '    ${Term.c('●', color)} ${Term.pad(r.url, 34)} ${r.status.name}'
        '${r.errorMessage != null ? ' ${Term.gray}${r.errorMessage}${Term.reset}' : ''}',
      );
    }
    Term.writeln();
    Term.writeln('  ${Term.bold}Dispositivos${Term.reset}');
    if (engine.peers.isEmpty) {
      Term.writeln(
        '    ${Term.gray}nenhum outro dispositivo visto nesta sessão${Term.reset}',
      );
    }
    for (final p in engine.peers.values) {
      Term.writeln(
        '    ${Term.c('●', Term.green)} ${Term.pad(p.deviceName ?? p.deviceId, 24)} '
        '${Term.pad(p.platform, 10)} visto ${Term.formatDate(p.connectedAt)}',
      );
    }
    Term.writeln();
    Term.pause();
  }

  Future<void> _identity() async {
    Term.clear();
    Term.header('Identidade de sincronização');
    Term.writeln();

    try {
      final transport = ctx.nostr;
      final identity = await transport.loadIdentity();
      if (identity == null) {
        Term.writeln(
          '  ${Term.gray}Nenhuma identidade configurada.${Term.reset}',
        );
      } else {
        Term.writeln('  Chave pública: ${identity.publicKey}');
        if (identity.displayName != null) {
          Term.writeln('  Nome:          ${identity.displayName}');
        }
      }
      Term.writeln();

      final choice = Term.select(
        'Identidade',
        items: const [
          'Criar nova identidade',
          'Importar identidade (12 palavras ou código BESTFIN:1)',
          'Sair da identidade atual',
        ],
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          if (identity != null &&
              !Term.confirm('Já existe uma identidade. Substituir?')) {
            return;
          }
          final created = await transport.createIdentity();
          Term.clear();
          Term.header('Nova identidade criada');
          Term.writeln();
          Term.writeln('  Chave pública: ${created.identity.publicKey}');
          Term.writeln();
          Term.warn('Anote as 12 palavras — é a única forma de recuperar:');
          Term.writeln();
          Term.writeln('  ${Term.bold}${created.mnemonic}${Term.reset}');
          Term.writeln();
          Term.pause();
        case 1:
          final raw = Term.input(
            'Frase de 12 palavras ou código BESTFIN:1:…:',
            allowEmpty: false,
          );
          if (raw == null || raw.trim().isEmpty) return;
          // Aceita tanto o mnemônico quanto o payload do QR de pareamento
          // (para quem escaneou o QR da GUI com outro app — task 57).
          final normalized = E2ECryptoService.qrPayloadToMnemonic(raw.trim());
          if (normalized == null) {
            Term.error(
              'Conteúdo inválido — nem frase de backup nem código de pareamento BestFin.',
            );
            Term.pause();
            return;
          }
          final imported = await transport.importIdentity(normalized);
          Term.writeln();
          Term.success('Identidade importada: ${imported.publicKey}');
          Term.pause();
        case 2:
          if (!Term.confirm('Sair da identidade neste dispositivo?')) return;
          await transport.signOut();
          Term.writeln();
          Term.success('Identidade removida deste dispositivo.');
          Term.pause();
      }
    } catch (e) {
      Term.writeln();
      Term.error(_describeSyncError(e));
      Term.pause();
    }
  }

  /// QR de pareamento no terminal (task 57) — mesmo payload `BESTFIN:1:<hex>`
  /// da task 80, que o scanner do Android já decodifica.
  Future<void> _pairingQr() async {
    Term.clear();
    Term.header('Pareamento por QR');
    Term.writeln();

    try {
      final transport = ctx.nostr;
      final identity = await transport.loadIdentity();
      if (identity == null) {
        Term.writeln(
          '  ${Term.gray}Nenhuma identidade configurada — crie ou importe uma '
          'em "Identidade" primeiro.${Term.reset}',
        );
        Term.pause();
        return;
      }
      final masterKey = transport.masterKey;
      if (masterKey == null) {
        Term.error('Chave de sincronização não carregada neste momento.');
        Term.pause();
        return;
      }

      Term.writeln('  Chave pública: ${identity.publicKey}');
      Term.writeln();
      Term.warn(
        'O QR abaixo CONTÉM a chave de sincronização deste dispositivo. '
        'Qualquer pessoa que escanear terá acesso aos seus dados financeiros.',
      );
      if (!Term.confirm('Revelar o QR agora?', defaultYes: false)) return;

      Term.clear();
      Term.header('Pareamento por QR — escaneie com o BestFin no Android');
      Term.writeln();
      final payload = E2ECryptoService.masterKeyToQrPayload(masterKey);
      Term.writeQr(renderQr(payload));
      Term.writeln();
      Term.writeln(
        '  ${Term.gray}No Android: Sincronização → Parear por QR. '
        'Aumente o zoom do terminal se não escanear.${Term.reset}',
      );
      Term.pause();
    } catch (e) {
      Term.error(_describeSyncError(e));
      Term.pause();
    }
  }

  Future<void> _relays() async {
    try {
      final transport = ctx.nostr;
      final relays = await transport.loadConfiguredRelays();

      final choice = Term.select(
        'Relays',
        items: [
          ...relays.map((r) => r),
          '${Term.gray}—${Term.reset}',
          'Adicionar relay',
          'Remover relay',
          'Restaurar padrões',
        ],
        subtitle: '${relays.length} relay(s) configurado(s)',
      );
      if (choice == null) return;

      if (choice == relays.length + 1) {
        final url = Term.input('URL do relay (wss://…):', allowEmpty: false);
        if (url == null || url.trim().isEmpty) return;
        await transport.updateRelays([...relays, url.trim()]);
        Term.success('Relay adicionado.');
        Term.pause();
      } else if (choice == relays.length + 2) {
        final target = Term.pick<String>(
          'Remover qual relay?',
          relays,
          (r) => r,
        );
        if (target == null) return;
        await transport.updateRelays(relays.where((r) => r != target).toList());
        Term.success('Relay removido.');
        Term.pause();
      } else if (choice == relays.length + 3) {
        if (!Term.confirm('Restaurar a lista padrão de relays?')) return;
        await transport.resetRelaysToDefaults();
        Term.success('Relays restaurados.');
        Term.pause();
      }
    } catch (e) {
      Term.error(_describeSyncError(e));
      Term.pause();
    }
  }

  Future<void> _eventLog() async {
    final rows =
        await (ctx.db.select(ctx.db.nostrEventLog)
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(300))
            .get();

    Term.pager('Histórico de eventos Nostr', [
      '',
      if (rows.isEmpty) '  ${Term.gray}Nenhum evento registrado.${Term.reset}',
      ...rows.map(
        (r) =>
            '  ${Term.formatDate(r.createdAt)}  '
            '${Term.gray}${Term.truncate(r.eventId, 24)}${Term.reset}',
      ),
      '',
    ], subtitle: '${rows.length} evento(s)');
  }

  /// O caso comum de falha aqui é o armazenamento seguro do sistema não estar
  /// acessível fora da GUI — vale dizer isso em vez de vazar a exceção crua.
  String _describeSyncError(Object e) {
    if (e is _SyncUnavailable) return e.message;
    final text = e.toString();
    if (text.contains('MissingPluginException') ||
        text.contains('secure_storage') ||
        text.contains('No implementation found')) {
      return 'O armazenamento seguro (onde a chave de sincronização fica '
          'guardada) não está acessível a partir do terminal. '
          'Use o app gráfico para gerenciar identidade e relays — a fila '
          'local criada aqui é publicada normalmente na próxima sync.';
    }
    return Screen.describeError(e);
  }
}

class _SyncUnavailable implements Exception {
  const _SyncUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
