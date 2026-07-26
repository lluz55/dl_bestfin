import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// Criptografia do banco de dados em repouso (SQLCipher, AES-256).
///
/// Aplicada **apenas no Android/iOS**, onde a chave pode ser guardada com
/// segurança no Keystore/Keychain via `flutter_secure_storage`. No desktop
/// (Linux/Windows/macOS) o keyring pode estar indisponível — guardar a chave
/// ali arriscaria travar o app sem conseguir abrir o banco — então o banco
/// permanece em texto claro, protegido pelo sandbox do SO.
///
/// A migração de bancos em texto claro já existentes é feita uma única vez, de
/// forma não-destrutiva: o original só é substituído depois que a cópia
/// cifrada é gerada com sucesso; qualquer falha faz o app cair de volta para o
/// banco em texto claro (disponibilidade > confidencialidade), nunca travando
/// o acesso do usuário aos próprios dados.
class DbEncryption {
  DbEncryption._();

  static const _storage = FlutterSecureStorage();
  static const _dbKeyStorageKey = 'db_cipher_key_v1';

  // SQLCipher só é aplicado onde há armazenamento seguro confiável.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Abre o executor de banco do BestFin. No mobile, garante que o arquivo
  /// esteja cifrado (migrando se necessário) e o abre com a chave; no desktop
  /// mantém o comportamento original em texto claro.
  static Future<QueryExecutor> openExecutor(File file) async {
    if (!isSupported) {
      return NativeDatabase.createInBackground(file);
    }

    try {
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
      }
      _applyOpenOverride();

      final hexKey = await _getOrCreateKey();

      if (_looksLikePlaintextSqlite(file)) {
        await _migratePlaintextToEncrypted(file, hexKey);
      }

      return NativeDatabase.createInBackground(
        file,
        // O override de `open` é local ao isolate; o NativeDatabase em segundo
        // plano roda em outro isolate e precisa reaplicá-lo, senão carregaria o
        // sqlite do sistema (sem SQLCipher) e a PRAGMA key seria ignorada.
        isolateSetup: _applyOpenOverride,
        setup: (db) {
          db.execute('PRAGMA key = "x\'$hexKey\'";');
          // Força a validação imediata da chave/decodificação do header.
          db.execute('SELECT count(*) FROM sqlite_master;');
        },
      );
    } catch (e, st) {
      // Nunca trave o usuário fora dos próprios dados: se a criptografia falhar
      // (ex.: keyring indisponível, migração interrompida), abre em texto claro.
      debugPrint('[DbEncryption] Falha ao abrir banco cifrado, usando texto '
          'claro como fallback: $e\n$st');
      return NativeDatabase.createInBackground(file);
    }
  }

  // ── Chave ──────────────────────────────────────────────────────────────────

  static Future<String> _getOrCreateKey() async {
    final existing = await _storage.read(key: _dbKeyStorageKey);
    if (existing != null && existing.length == 64) return existing;

    final rng = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = rng.nextInt(256);
    }
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _dbKeyStorageKey, value: hex);
    return hex;
  }

  // ── Detecção / migração ─────────────────────────────────────────────────────

  // Um banco SQLite em texto claro começa com o header mágico "SQLite format 3".
  // Um banco SQLCipher tem os primeiros bytes cifrados (aparência aleatória),
  // então a ausência do header indica que já está cifrado (ou não existe).
  static bool _looksLikePlaintextSqlite(File file) {
    if (!file.existsSync()) return false;
    final raf = file.openSync();
    try {
      final header = raf.readSync(16);
      if (header.length < 16) return false;
      const magic = 'SQLite format 3\x00';
      for (var i = 0; i < 16; i++) {
        if (header[i] != magic.codeUnitAt(i)) return false;
      }
      return true;
    } finally {
      raf.closeSync();
    }
  }

  static Future<void> _migratePlaintextToEncrypted(
    File file,
    String hexKey,
  ) async {
    final encPath = '${file.path}.enc-migrate';
    final encFile = File(encPath);
    if (await encFile.exists()) await encFile.delete();

    // Abre o banco em texto claro (sem key) e exporta seu conteúdo para um novo
    // arquivo cifrado usando a função sqlcipher_export.
    final db = sqlite3.open(file.path);
    try {
      final escaped = encPath.replaceAll("'", "''");
      db.execute('ATTACH DATABASE \'$escaped\' AS enc KEY "x\'$hexKey\'";');
      db.execute("SELECT sqlcipher_export('enc');");
      db.execute('DETACH DATABASE enc;');
    } finally {
      db.dispose();
    }

    // Journals do banco em texto claro não valem para o arquivo cifrado.
    for (final suffix in ['-wal', '-shm']) {
      final j = File('${file.path}$suffix');
      if (await j.exists()) await j.delete();
    }

    // Swap seguro: preserva o original até o cifrado estar no lugar.
    final backup = File('${file.path}.plain-bak');
    if (await backup.exists()) await backup.delete();
    await file.rename(backup.path);
    try {
      await encFile.rename(file.path);
    } catch (e) {
      // Restaura o texto claro se o swap falhar, para não perder dados.
      await backup.rename(file.path);
      rethrow;
    }
    try {
      await backup.delete();
    } catch (_) {}
  }

  // Direciona o carregamento da biblioteca nativa para o SQLCipher. É puro Dart
  // e local ao isolate, então precisa ser chamado em cada isolate que abre o
  // banco (o principal, para a migração, e o de segundo plano do drift).
  static void _applyOpenOverride() {
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    } else if (Platform.isIOS) {
      open.overrideFor(OperatingSystem.iOS, DynamicLibrary.process);
    }
  }
}
