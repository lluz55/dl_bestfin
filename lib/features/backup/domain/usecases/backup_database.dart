import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'package:bestfin/features/backup/domain/backup_version.dart';

final backupDatabaseUseCaseProvider = Provider<BackupDatabaseUseCase>((ref) {
  return BackupDatabaseUseCase(ref.watch(databaseProvider));
});

class BackupDatabaseUseCase {
  final AppDatabase _db;

  BackupDatabaseUseCase(this._db);

  /// Locates the active SQLite database file in the application document directory
  Future<File> getDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'bestfin.sqlite'));
  }

  /// Prepares the active SQLite file for a byte-for-byte copy and returns it.
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
  Future<File> _prepareBackupSource() async {
    await _db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final dbFile = await getDatabaseFile();
    if (!await dbFile.exists()) {
      throw const FileSystemException(
        'Arquivo de banco de dados não encontrado no dispositivo.',
      );
    }
    return dbFile;
  }

  /// Copies the active SQLite file to a temporary location and triggers the native OS Share dialog
  Future<void> shareBackup() async {
    final dbFile = await _prepareBackupSource();
    final tempDir = await getTemporaryDirectory();
    final backupCopy = File(
      p.join(
        tempDir.path,
        'bestfin_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      ),
    );

    // Copy current DB file (WAL já mesclado por _prepareBackupSource)
    await dbFile.copy(backupCopy.path);

    // Open native Share dialog
    await Share.shareXFiles([
      XFile(backupCopy.path),
    ], subject: 'Backup do Banco de Dados BestFin');
  }

  /// Copies the active SQLite file to [destinationPath] (used on desktop, where
  /// the user picks the destination via "Salvar como" instead of OS Share).
  Future<void> saveBackupTo(String destinationPath) async {
    final dbFile = await _prepareBackupSource();
    await dbFile.copy(destinationPath);
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
        (header[60] << 24) | (header[61] << 16) | (header[62] << 8) | header[63];
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
