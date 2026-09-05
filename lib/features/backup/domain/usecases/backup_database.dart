import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/utils/app_paths.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:bestfin/features/backup/domain/backup_version.dart';
import 'package:bestfin/features/backup/domain/backup_crypto.dart';
import 'package:bestfin/core/database/db_encryption.dart';

final backupDatabaseUseCaseProvider = Provider<BackupDatabaseUseCase>((ref) {
  return BackupDatabaseUseCase(ref.watch(databaseProvider));
});

class BackupDatabaseUseCase {
  final AppDatabase _db;

  BackupDatabaseUseCase(this._db);

  /// Locates the active SQLite database file in the application document directory
  Future<File> getDatabaseFile() async {
    final dbFolder = await getAppDocumentsDirectory();
    return File(p.join(dbFolder.path, 'bestfin.sqlite'));
  }

  /// Returns a **plaintext** SQLite file suitable for export/backup.
  ///
  /// Dois problemas que isto resolve, ambos essenciais para um backup íntegro:
  /// 1. O banco roda em `journal_mode = WAL`, então dados já commitados podem
  ///    estar apenas no arquivo `-wal`. `wal_checkpoint(TRUNCATE)` mescla o WAL
  ///    no arquivo principal — sem isso, a cópia sai desatualizada e a
  ///    restauração perderia as transações mais recentes.
  /// 2. `AppDatabase` usa `LazyDatabase`: se nenhuma query tocou a instância
  ///    (ex.: logo após um `invalidate` no clear-all), o arquivo pode nem
  ///    existir no disco. O próprio `customStatement` força a abertura e cria o
  ///    arquivo antes de checarmos sua existência.
  ///
  /// No mobile o banco está cifrado em repouso (SQLCipher), então o arquivo
  /// físico não é um SQLite legível: decifra-se para uma cópia temporária via
  /// `sqlcipher_export` (chave vazia = sem criptografia). No desktop o próprio
  /// arquivo já é texto claro e é usado diretamente. Chame [_disposeExportSource]
  /// no arquivo retornado quando terminar, para remover a cópia temporária.
  Future<File> _plaintextExportSource() async {
    await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final dbFile = await getDatabaseFile();
    if (!await dbFile.exists()) {
      throw const FileSystemException(
        'Arquivo de banco de dados não encontrado no dispositivo.',
      );
    }
    if (!DbEncryption.isSupported) return dbFile;

    final tempDir = await getTemporaryDirectory();
    final plain = File(
      p.join(
        tempDir.path,
        'bestfin_plain_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      ),
    );
    if (await plain.exists()) await plain.delete();
    final escaped = plain.path.replaceAll("'", "''");
    await _db.customStatement("ATTACH DATABASE '$escaped' AS plaintext KEY '';");
    await _db.customStatement("SELECT sqlcipher_export('plaintext');");
    await _db.customStatement('DETACH DATABASE plaintext;');
    return plain;
  }

  /// Removes the temporary plaintext copy produced by [_plaintextExportSource]
  /// (no-op for the live database file used directly on desktop).
  Future<void> _disposeExportSource(File source) async {
    final dbFile = await getDatabaseFile();
    if (p.canonicalize(source.path) == p.canonicalize(dbFile.path)) return;
    try {
      await source.delete();
    } catch (_) {}
  }

  /// Copies the active SQLite file to a temporary location and triggers the native OS Share dialog
  Future<void> shareBackup() async {
    final source = await _plaintextExportSource();
    try {
      final tempDir = await getTemporaryDirectory();
      final backupCopy = File(
        p.join(
          tempDir.path,
          'bestfin_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite',
        ),
      );
      await source.copy(backupCopy.path);
      await Share.shareXFiles([
        XFile(backupCopy.path),
      ], subject: 'Backup do Banco de Dados BestFin');
    } finally {
      await _disposeExportSource(source);
    }
  }

  /// Copies the active SQLite file to [destinationPath] (used on desktop, where
  /// the user picks the destination via "Salvar como" instead of OS Share).
  Future<void> saveBackupTo(String destinationPath) async {
    final source = await _plaintextExportSource();
    try {
      await source.copy(destinationPath);
    } finally {
      await _disposeExportSource(source);
    }
  }

  /// Builds a password-encrypted backup of the active database (AES-256-GCM,
  /// see [BackupCrypto]). The returned bytes carry no readable financial data
  /// without the password — safe to store in the cloud or share by e-mail.
  Future<List<int>> buildEncryptedBackup(String password) async {
    final source = await _plaintextExportSource();
    try {
      final bytes = await source.readAsBytes();
      return await BackupCrypto.encrypt(bytes, password);
    } finally {
      await _disposeExportSource(source);
    }
  }

  /// Shares an encrypted backup through the native OS Share dialog (mobile).
  Future<void> shareEncryptedBackup(String password) async {
    final blob = await buildEncryptedBackup(password);
    final tempDir = await getTemporaryDirectory();
    final backupCopy = File(
      p.join(
        tempDir.path,
        'bestfin_backup_${DateTime.now().millisecondsSinceEpoch}.bfenc',
      ),
    );
    await backupCopy.writeAsBytes(blob, flush: true);
    await Share.shareXFiles([
      XFile(backupCopy.path),
    ], subject: 'Backup criptografado BestFin');
  }

  /// Writes an encrypted backup to [destinationPath] (desktop "Salvar como").
  Future<void> saveEncryptedBackupTo(
    String destinationPath,
    String password,
  ) async {
    final blob = await buildEncryptedBackup(password);
    await File(destinationPath).writeAsBytes(blob, flush: true);
  }

  /// Restores from a password-encrypted backup: decrypts to a temporary SQLite
  /// file, then reuses [restoreBackup] (which validates the SQLite header and
  /// schema version) before swapping it over the live database.
  Future<void> restoreEncryptedBackup(
    String selectedFilePath,
    String password,
  ) async {
    final blob = await File(selectedFilePath).readAsBytes();
    final plain = await BackupCrypto.decrypt(blob, password);
    final tempDir = await getTemporaryDirectory();
    final tmp = File(
      p.join(
        tempDir.path,
        'bestfin_restore_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      ),
    );
    await tmp.writeAsBytes(plain, flush: true);
    try {
      await restoreBackup(tmp.path);
    } finally {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

  /// Restores database by replacing the local sqlite file with the selected file.
  /// Validates SQLite file header signature before performing the replace.
  Future<void> restoreBackup(String selectedFilePath) async {
    final selectedFile = File(selectedFilePath);
    if (!await selectedFile.exists()) {
      throw const FileSystemException(
        'O arquivo de backup selecionado não existe.',
      );
    }

    // 1. Read the SQLite header. Bytes 0-15 carry the magic string and byte
    //    offset 60 carries `user_version` (4 bytes, big-endian) — que o Drift
    //    mantém igual ao `schemaVersion`. Um RandomAccessFile garante os 100
    //    bytes do header de uma vez (openRead pode fatiar em chunks menores).
    final raf = await selectedFile.open();
    final List<int> header;
    try {
      header = await raf.read(100);
    } finally {
      await raf.close();
    }
    if (header.length < 64) {
      throw const FormatException(
        'O arquivo selecionado está corrompido ou é muito curto.',
      );
    }

    // 1a. Validate SQLite magic signature (first 15 bytes must be "SQLite format 3")
    final magic = String.fromCharCodes(header.sublist(0, 15));
    if (magic != 'SQLite format 3') {
      throw const FormatException(
        'O arquivo selecionado não é um banco de dados SQLite válido do BestFin.',
      );
    }

    // 1b. Rejeita restaurar um banco de um app mais novo: o `user_version` do
    //     backup não pode ser maior que o schema desta build, senão o Drift
    //     falharia ao abrir (não há migração de downgrade).
    final backupSchemaVersion =
        (header[60] << 24) |
        (header[61] << 16) |
        (header[62] << 8) |
        header[63];
    if (backupSchemaVersion > _db.schemaVersion) {
      throw BackupIncompatibleException(
        'Este backup foi gerado por uma versão mais nova do BestFin '
        '(schema v$backupSchemaVersion, esta build usa v${_db.schemaVersion}). '
        'Atualize o app para restaurá-lo.',
      );
    }

    // 2. Reject the live database itself — the old flow deleted the target
    //    before copying, so selecting the active file destroyed the database.
    final dbFile = await getDatabaseFile();
    if (p.canonicalize(selectedFile.path) == p.canonicalize(dbFile.path)) {
      throw const FormatException(
        'O arquivo selecionado é o próprio banco de dados ativo do BestFin. '
        'Selecione um arquivo de backup exportado.',
      );
    }

    // 3. Close active database connection
    await _db.close();

    // 4. Copy to a temp file and rename over the database: the current
    //    database is only replaced after the copy fully succeeded.
    await dbFile.parent.create(recursive: true);
    final tmpFile = await selectedFile.copy('${dbFile.path}.restore-tmp');
    await tmpFile.rename(dbFile.path);

    // 5. Drop stale WAL/SHM journals from the previous database — sqlite
    //    would try to replay them over the restored file.
    for (final suffix in ['-wal', '-shm']) {
      final journal = File('${dbFile.path}$suffix');
      if (await journal.exists()) {
        await journal.delete();
      }
    }
  }
}
