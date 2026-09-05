import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/backup/domain/backup_crypto.dart';
import 'package:bestfin/features/backup/domain/usecases/export_csv.dart';
import 'package:bestfin/features/backup/domain/usecases/export_json.dart';
import 'package:bestfin/features/backup/domain/usecases/export_pdf.dart';
import 'package:bestfin/features/backup/domain/usecases/import_data.dart';

/// Backup e dados: exportação (CSV/JSON/PDF/SQLite, com opção criptografada),
/// importação de CSV/JSON e restauração de um backup completo.
///
/// Diferente da GUI, aqui os caminhos de arquivo são digitados — não há
/// seletor nativo no terminal.
class BackupScreen extends Screen {
  BackupScreen(super.ctx);

  @override
  String get title => 'Backup e dados';

  @override
  Future<void> run() async {
    while (true) {
      final choice = Term.select(
        title,
        items: const [
          'Exportar CSV (lançamentos)',
          'Exportar JSON (backup completo)',
          'Exportar PDF (extrato)',
          'Copiar banco SQLite',
          'Backup criptografado (.bfenc)',
          'Importar CSV',
          'Importar/restaurar JSON',
          'Restaurar backup (.sqlite ou .bfenc)',
        ],
        subtitle: 'Banco: ${ctx.dbPath}',
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          await _exportCsv();
        case 1:
          await _exportJson();
        case 2:
          await _exportPdf();
        case 3:
          await _copySqlite();
        case 4:
          await _encryptedBackup();
        case 5:
          await _importCsv();
        case 6:
          await _importJson();
        case 7:
          await _restore();
      }
    }
  }

  // ── Caminhos ───────────────────────────────────────────────────────

  String _defaultPath(String extension) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final home = Platform.environment['HOME'] ?? '.';
    return p.join(home, 'bestfin_backup_$stamp.$extension');
  }

  /// Pergunta o destino e garante que o diretório existe.
  String? _askDestination(String extension) {
    final path = Term.input(
      'Salvar em:',
      initial: _defaultPath(extension),
      allowEmpty: false,
    );
    if (path == null || path.trim().isEmpty) return null;
    final resolved = _expandHome(path.trim());
    final dir = Directory(p.dirname(resolved));
    if (!dir.existsSync()) {
      Term.error('Diretório não existe: ${dir.path}');
      Term.pause();
      return null;
    }
    if (File(resolved).existsSync() &&
        !Term.confirm('Arquivo já existe. Sobrescrever?')) {
      return null;
    }
    return resolved;
  }

  String? _askSource(String what) {
    final path = Term.input('Caminho do $what:', allowEmpty: false);
    if (path == null || path.trim().isEmpty) return null;
    final resolved = _expandHome(path.trim());
    if (!File(resolved).existsSync()) {
      Term.error('Arquivo não encontrado: $resolved');
      Term.pause();
      return null;
    }
    return resolved;
  }

  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home = Platform.environment['HOME'];
    if (home == null) return path;
    return p.join(home, path.substring(1).replaceFirst(RegExp(r'^/'), ''));
  }

  /// Período opcional aplicado às exportações que aceitam filtro.
  (DateTime?, DateTime?)? _askPeriod() {
    final i = Term.select(
      'Período da exportação',
      items: const [
        'Todo o histórico',
        'Mês atual',
        'Ano atual',
        'Personalizado',
      ],
    );
    if (i == null) return null;
    final now = DateTime.now();
    switch (i) {
      case 1:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
      case 2:
        return (
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31, 23, 59, 59),
        );
      case 3:
        final s = Term.inputDate('Início');
        if (s == null) return null;
        final e = Term.inputDate('Fim');
        if (e == null) return null;
        return (s, DateTime(e.year, e.month, e.day, 23, 59, 59));
      default:
        return (null, null);
    }
  }

  // ── Exportações ────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    final period = _askPeriod();
    if (period == null) return;
    final destination = _askDestination('csv');
    if (destination == null) return;

    await guard(() async {
      final csv = await ExportCsvUseCase(
        ctx.db,
      ).execute(startDate: period.$1, endDate: period.$2);
      await File(destination).writeAsString(csv, flush: true);
    }, successMessage: 'CSV salvo em $destination');
  }

  Future<void> _exportJson() async {
    final destination = _askDestination('json');
    if (destination == null) return;

    await guard(() async {
      final data = await ExportJsonUseCase(ctx.db).execute();
      await File(destination).writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
    }, successMessage: 'JSON salvo em $destination');
  }

  Future<void> _exportPdf() async {
    final period = _askPeriod();
    if (period == null) return;
    final destination = _askDestination('pdf');
    if (destination == null) return;

    await guard(() async {
      final bytes = await ExportPdfUseCase(
        ctx.db,
      ).execute(startDate: period.$1, endDate: period.$2);
      await File(destination).writeAsBytes(bytes, flush: true);
    }, successMessage: 'PDF salvo em $destination');
  }

  Future<void> _copySqlite() async {
    final destination = _askDestination('sqlite');
    if (destination == null) return;
    await guard(() async {
      final source = await _checkpointedDbFile();
      await source.copy(destination);
    }, successMessage: 'Banco copiado para $destination');
  }

  Future<void> _encryptedBackup() async {
    Term.clear();
    Term.header('Backup criptografado');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}AES-256-GCM com senha — sem a senha o arquivo é '
      'ilegível. Guarde-a: não há recuperação.${Term.reset}',
    );
    Term.writeln();

    final password = Term.input('Senha:', allowEmpty: false);
    if (password == null || password.isEmpty) return;
    final confirmation = Term.input('Repita a senha:', allowEmpty: false);
    if (confirmation == null) return;
    if (password != confirmation) {
      Term.error('As senhas não conferem.');
      Term.pause();
      return;
    }

    final destination = _askDestination('bfenc');
    if (destination == null) return;

    await guard(() async {
      final source = await _checkpointedDbFile();
      final bytes = await BackupCrypto.encrypt(
        await source.readAsBytes(),
        password,
      );
      await File(destination).writeAsBytes(bytes, flush: true);
    }, successMessage: 'Backup criptografado salvo em $destination');
  }

  /// Mescla o WAL no arquivo principal antes de copiar — sem isso a cópia
  /// sai sem os últimos lançamentos (mesmo cuidado do `BackupDatabaseUseCase`).
  Future<File> _checkpointedDbFile() async {
    await ctx.db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final file = File(ctx.dbPath);
    if (!file.existsSync()) {
      throw FileSystemException('Banco não encontrado', ctx.dbPath);
    }
    return file;
  }

  // ── Importações ────────────────────────────────────────────────────

  Future<void> _importCsv() async {
    final source = _askSource('arquivo CSV');
    if (source == null) return;

    final separatorIndex = Term.select(
      'Separador de campos',
      items: const ['Ponto e vírgula (;)', 'Vírgula (,)', 'Tabulação'],
    );
    if (separatorIndex == null) return;
    final separator = [';', ',', '\t'][separatorIndex];

    try {
      final content = await File(source).readAsString();
      final useCase = ImportDataUseCase(ctx.db);
      final preview = await useCase.previewCsv(content, separator: separator);

      Term.clear();
      Term.header('Pré-visualização da importação');
      Term.writeln();
      for (final entry in preview.entries) {
        Term.writeln('  ${Term.pad('${entry.key}:', 22)} ${entry.value}');
      }
      Term.writeln();
      if (!Term.confirm('Importar estes dados?')) return;

      await guard(() async {
        final count = await useCase.importCsv(content, separator: separator);
        Term.writeln();
        Term.success('$count lançamento(s) importado(s).');
      });
      Term.pause();
    } catch (e) {
      Term.error(Screen.describeError(e));
      Term.pause();
    }
  }

  Future<void> _importJson() async {
    final source = _askSource('arquivo JSON');
    if (source == null) return;

    try {
      final content = await File(source).readAsString();
      final useCase = ImportDataUseCase(ctx.db);
      final preview = await useCase.previewJson(content);

      Term.clear();
      Term.header('Pré-visualização da restauração');
      Term.writeln();
      for (final entry in preview.entries) {
        Term.writeln('  ${Term.pad('${entry.key}:', 22)} ${entry.value}');
      }
      Term.writeln();
      Term.warn('A restauração JSON substitui os dados atuais.');
      Term.writeln();
      if (!Term.confirm('Confirmar restauração?')) return;

      await guard(
        () => useCase.restoreJson(content),
        successMessage: 'Dados restaurados.',
      );
    } catch (e) {
      Term.error(Screen.describeError(e));
      Term.pause();
    }
  }

  /// Substitui o arquivo do banco. Como a conexão atual passa a apontar para
  /// um arquivo trocado, a TUI encerra em seguida.
  Future<void> _restore() async {
    final source = _askSource('backup (.sqlite ou .bfenc)');
    if (source == null) return;

    final encrypted = source.endsWith('.bfenc');
    String? password;
    if (encrypted) {
      password = Term.input('Senha do backup:', allowEmpty: false);
      if (password == null || password.isEmpty) return;
    }

    Term.clear();
    Term.header('Restaurar backup');
    Term.writeln();
    Term.warn('Todos os dados atuais serão substituídos pelos do backup.');
    Term.writeln(
      '  ${Term.gray}Uma cópia do banco atual é guardada ao lado, '
      'com sufixo .bak${Term.reset}',
    );
    Term.writeln();
    if (!Term.confirm('Confirmar restauração?')) return;

    final ok = await guard(() async {
      var bytes = await File(source).readAsBytes();
      if (encrypted) {
        bytes = await BackupCrypto.decrypt(bytes, password!);
      }
      _assertSqliteHeader(bytes);

      // Fecha a conexão antes de trocar o arquivo sob os pés do sqlite.
      await ctx.db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      await ctx.db.close();

      final current = File(ctx.dbPath);
      if (current.existsSync()) {
        await current.copy('${ctx.dbPath}.bak');
      }
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('${ctx.dbPath}$suffix');
        if (sidecar.existsSync()) await sidecar.delete();
      }
      await File(ctx.dbPath).writeAsBytes(bytes, flush: true);
    });

    if (ok) {
      Term.success('Backup restaurado. Reabra a TUI para usar os dados novos.');
      Term.pause();
      ctx.requestExit('Banco restaurado a partir de $source');
    }
  }

  /// Todo arquivo SQLite começa com "SQLite format 3\0" — barra restaurações
  /// de arquivos que não são banco antes de sobrescrever nada.
  static void _assertSqliteHeader(List<int> bytes) {
    const header = 'SQLite format 3';
    if (bytes.length < header.length + 1) {
      throw const FormatException('Arquivo pequeno demais para ser um banco.');
    }
    final actual = String.fromCharCodes(bytes.take(header.length));
    if (actual != header) {
      throw const FormatException(
        'O arquivo não é um banco SQLite válido (assinatura não confere).',
      );
    }
  }
}
