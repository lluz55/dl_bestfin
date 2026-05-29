import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

final backupDatabaseUseCaseProvider = Provider<BackupDatabaseUseCase>((ref) {
  return BackupDatabaseUseCase(ref.read(databaseProvider));
});

class BackupDatabaseUseCase {
  final AppDatabase _db;

  BackupDatabaseUseCase(this._db);

  /// Locates the active SQLite database file in the application document directory
  Future<File> getDatabaseFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return File(p.join(dbFolder.path, 'bestfin.sqlite'));
  }

  /// Copies the active SQLite file to a temporary location and triggers the native OS Share dialog
  Future<void> shareBackup() async {
    final dbFile = await getDatabaseFile();
    if (await dbFile.exists()) {
      final tempDir = await getTemporaryDirectory();
      final backupCopy = File(
        p.join(
          tempDir.path,
          'bestfin_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite',
        ),
      );

      // Copy current DB file
      await dbFile.copy(backupCopy.path);

      // Open native Share dialog
      await Share.shareXFiles([
        XFile(backupCopy.path),
      ], subject: 'Backup do Banco de Dados BestFin');
    } else {
      throw const FileSystemException(
        'Arquivo de banco de dados não encontrado no dispositivo.',
      );
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

    // 1. Validate SQLite magic header signature (first 15 bytes must be "SQLite format 3")
    final bytes = await selectedFile.openRead(0, 16).first;
    if (bytes.length < 15) {
      throw const FormatException(
        'O arquivo selecionado está corrompido ou é muito curto.',
      );
    }
    final header = String.fromCharCodes(bytes.sublist(0, 15));
    if (header != 'SQLite format 3') {
      throw const FormatException(
        'O arquivo selecionado não é um banco de dados SQLite válido do BestFin.',
      );
    }

    // 2. Close active database connection
    await _db.close();

    // 3. Overwrite the database file
    final dbFile = await getDatabaseFile();
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
    await selectedFile.copy(dbFile.path);
  }
}
