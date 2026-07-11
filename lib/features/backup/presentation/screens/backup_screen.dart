import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/backup/domain/usecases/export_csv.dart';
import 'package:bestfin/features/backup/domain/usecases/export_json.dart';
import 'package:bestfin/features/backup/domain/usecases/export_pdf.dart';
import 'package:bestfin/features/backup/domain/usecases/import_data.dart';
import 'package:bestfin/features/backup/domain/usecases/backup_database.dart';
import 'package:bestfin/features/backup/presentation/widgets/export_button.dart';
import 'package:bestfin/features/backup/presentation/widgets/import_progress_widget.dart';
import 'package:intl/intl.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: const AppPageAppBar(
        title: 'Export & Backup',
        infoDescription: 'Faça backup completo dos seus dados ou exporte relatórios em CSV, JSON e PDF. Importe backups de versões anteriores com segurança.',
        infoFeatures: [
          'Backup completo em JSON',
          'Exportação em CSV e PDF',
          'Importação de backup seguro',
          'Relatório mensal em PDF',
        ],
      ),
      body: const BackupView(),
    );
  }
}

/// Conteúdo de exportação/importação sem `Scaffold`/`AppBar`, para poder ser
/// usado tanto na rota `/backup` quanto no painel de detalhe das Configurações
/// em telas grandes (master-detail).
class BackupView extends ConsumerStatefulWidget {
  const BackupView({super.key, this.selectedCategory, this.onSelectCategory});

  final String? selectedCategory;
  final void Function(String)? onSelectCategory;

  @override
  ConsumerState<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends ConsumerState<BackupView> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPreset;
  String _csvSeparator = ';';
  bool _isLoading = false;
  String _loadingMessage = '';

  static const _periodPresets = [
    'Este mês',
    'Mês anterior',
    'Últimos 3 meses',
    'Este ano',
  ];

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    switch (preset) {
      case 'Este mês':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case 'Mês anterior':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0, 23, 59, 59);
      case 'Últimos 3 meses':
        start = DateTime(now.year, now.month - 2, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case 'Este ano':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
    }
    setState(() {
      _selectedPreset = preset;
      _startDate = start;
      _endDate = end;
    });
  }

  void _showLoading(String message) {
    setState(() {
      _isLoading = true;
      _loadingMessage = message;
    });
  }

  void _hideLoading() {
    setState(() {
      _isLoading = false;
      _loadingMessage = '';
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: context.colorScheme),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = null;
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedPreset = null;
      _startDate = null;
      _endDate = null;
    });
  }

  /// Compartilha o arquivo no Android/iOS; no desktop (Linux/Windows/macOS),
  /// onde o share_plus não suporta arquivos, abre um diálogo "Salvar como".
  Future<void> _saveOrShareFile({
    required List<int> bytes,
    required String fileName,
    required String shareSubject,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final tempDir = await getTemporaryDirectory();
      final file = File(pJoin(tempDir.path, fileName));
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], subject: shareSubject);
    } else {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar arquivo',
        fileName: fileName,
      );
      if (savePath == null) return; // usuário cancelou
      await File(savePath).writeAsBytes(bytes);
      if (!mounted) return;
      _showSuccessSnackBar('Arquivo salvo em $savePath');
    }
  }

  Future<void> _handleExportCsv() async {
    _showLoading('Gerando planilha CSV...');
    try {
      final exportCsv = ref.read(exportCsvUseCaseProvider);

      // Sem compute(): a closure capturaria o AppDatabase, cujos handles
      // nativos do SQLite não podem ser enviados a outro isolate.
      final csvString = await exportCsv.execute(
        startDate: _startDate,
        endDate: _endDate,
        separator: _csvSeparator,
      );

      _hideLoading();

      await _saveOrShareFile(
        bytes: utf8.encode(csvString),
        fileName: 'bestfin_export_${DateTime.now().millisecondsSinceEpoch}.csv',
        shareSubject: 'Relatório CSV BestFin',
      );
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao exportar CSV: $e\n$st');
      _showErrorSnackBar('Erro ao exportar CSV: $e');
    }
  }

  Future<void> _handleExportJson() async {
    _showLoading('Estruturando dados em JSON...');
    try {
      final exportJson = ref.read(exportJsonUseCaseProvider);
      final jsonMap = await exportJson.execute();

      // Stringify in isolate (Map de primitivos é enviável entre isolates)
      final jsonString = await compute((Map<String, dynamic> data) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }, jsonMap);

      _hideLoading();

      await _saveOrShareFile(
        bytes: utf8.encode(jsonString),
        fileName:
            'bestfin_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        shareSubject: 'Backup JSON BestFin',
      );
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao exportar JSON: $e\n$st');
      _showErrorSnackBar('Erro ao exportar JSON: $e');
    }
  }

  Future<void> _handleExportPdf() async {
    _showLoading('Gerando relatório PDF de alta qualidade...');
    try {
      final exportPdf = ref.read(exportPdfUseCaseProvider);

      // Sem compute(): a closure capturaria o AppDatabase, cujos handles
      // nativos do SQLite não podem ser enviados a outro isolate.
      final pdfBytes = await exportPdf.execute(
        startDate: _startDate,
        endDate: _endDate,
      );

      _hideLoading();

      await _saveOrShareFile(
        bytes: pdfBytes,
        fileName:
            'bestfin_relatorio_${DateTime.now().millisecondsSinceEpoch}.pdf',
        shareSubject: 'Relatório PDF BestFin',
      );
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao exportar PDF: $e\n$st');
      _showErrorSnackBar('Erro ao exportar PDF: $e');
    }
  }

  Future<void> _handleDatabaseBackup() async {
    _showLoading('Preparando backup do banco de dados...');
    try {
      final backupUseCase = ref.read(backupDatabaseUseCaseProvider);
      if (Platform.isAndroid || Platform.isIOS) {
        _hideLoading();
        await backupUseCase.shareBackup();
      } else {
        _hideLoading();
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Salvar backup do banco de dados',
          fileName:
              'bestfin_backup_${DateTime.now().millisecondsSinceEpoch}.sqlite',
        );
        if (savePath == null) return; // usuário cancelou
        await backupUseCase.saveBackupTo(savePath);
        if (!mounted) return;
        _showSuccessSnackBar('Backup salvo em $savePath');
      }
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao criar backup do banco: $e\n$st');
      _showErrorSnackBar('Erro ao criar backup do banco: $e');
    }
  }

  Future<void> _handleEncryptedBackup() async {
    final password = await _promptPassword(
      title: 'Definir senha do backup',
      message:
          'Escolha uma senha forte. Ela será exigida para restaurar este '
          'backup — não há como recuperá-la se for esquecida.',
      confirm: true,
    );
    if (password == null) return;

    _showLoading('Criptografando backup...');
    try {
      final backupUseCase = ref.read(backupDatabaseUseCaseProvider);
      final bytes = await backupUseCase.buildEncryptedBackup(password);
      _hideLoading();
      await _saveOrShareFile(
        bytes: bytes,
        fileName:
            'bestfin_backup_${DateTime.now().millisecondsSinceEpoch}.bfenc',
        shareSubject: 'Backup criptografado BestFin',
      );
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao criar backup criptografado: $e\n$st');
      _showErrorSnackBar('Erro ao criar backup criptografado: $e');
    }
  }

  Future<void> _handleEncryptedRestore() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;
      final filePath = result.files.single.path!;

      final password = await _promptPassword(
        title: 'Restaurar backup criptografado',
        message:
            'Digite a senha usada para criptografar este backup. A restauração '
            'substituirá COMPLETAMENTE todos os dados atuais.',
        confirm: false,
      );
      if (password == null) return;

      _showLoading('Descriptografando e restaurando...');
      final backupUseCase = ref.read(backupDatabaseUseCaseProvider);
      await backupUseCase.restoreEncryptedBackup(filePath, password);

      ref.invalidate(databaseProvider);
      _hideLoading();
      _showSuccessSnackBar('Backup criptografado restaurado com sucesso!');
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao restaurar backup criptografado: $e\n$st');
      _showErrorSnackBar(
        'Erro ao restaurar backup: ${e is FormatException ? e.message : e}',
      );
    }
  }

  /// Prompts for a backup password. Returns the entered password, or null if
  /// cancelled. When [confirm] is true, requires a matching confirmation field.
  Future<String?> _promptPassword({
    required String title,
    required String message,
    required bool confirm,
  }) {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscure = true;

    return showDialog<String>(
      context: context,
      builder: (context) {
        final cs = context.colorScheme;
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      obscureText: obscure,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          onPressed: () => setLocal(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'A senha deve ter ao menos 6 caracteres'
                          : null,
                    ),
                    if (confirm) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: confirmController,
                        obscureText: obscure,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar senha',
                        ),
                        validator: (v) => v != controller.text
                            ? 'As senhas não coincidem'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                AppButton(
                  label: 'Confirmar',
                  size: AppButtonSize.compact,
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context, controller.text);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleImportCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.single.path == null) return;

      _showLoading('Analisando planilha...');
      final file = File(result.files.single.path!);
      final csvString = await file.readAsString(encoding: utf8);

      final importUseCase = ref.read(importDataUseCaseProvider);
      final preview = await importUseCase.previewCsv(
        csvString,
        separator: _csvSeparator,
      );

      _hideLoading();

      // Show preview confirmation modal
      if (!mounted) return;
      final confirm = await _showImportPreviewDialog(
        title: 'Confirmar Importação de CSV',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewRow(
              'Total de linhas detectadas:',
              '${preview['total_rows']}',
            ),
            _buildPreviewRow('Transações válidas:', '${preview['valid_rows']}'),
            const SizedBox(height: 12),
            const Text(
              'As transações serão importadas e vinculadas às contas e categorias mapeadas. Se a categoria ou a conta não existir, ela será criada automaticamente.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );

      if (confirm == true) {
        _showLoading('Importando transações...');
        final importedCount = await importUseCase.importCsv(
          csvString,
          separator: _csvSeparator,
        );
        _hideLoading();
        _showSuccessSnackBar('$importedCount transações importadas!');
      }
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao importar CSV: $e\n$st');
      _showErrorSnackBar(
        'Erro ao importar CSV: ${e is FormatException ? e.message : e}',
      );
    }
  }

  Future<void> _handleRestoreJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      _showLoading('Analisando arquivo JSON...');
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString(encoding: utf8);

      final importUseCase = ref.read(importDataUseCaseProvider);
      final preview = await importUseCase.previewJson(jsonString);

      _hideLoading();

      if (!mounted) return;

      final counts = preview['counts'] as Map<String, int>;
      final countsWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: counts.entries.map((e) {
          final label = _translateTableName(e.key);
          return _buildPreviewRow(label, '${e.value}');
        }).toList(),
      );

      final confirm = await _showImportPreviewDialog(
        title: 'Confirmar Restauração',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewRow(
              'Exportado em:',
              '${_formatIsoString(preview['exported_at'])}',
            ),
            if (preview['schema_version'] != null)
              _buildPreviewRow(
                'Versão dos dados:',
                'schema v${preview['schema_version']} • formato v${preview['version']}',
              ),
            const SizedBox(height: 12),
            const Text(
              'Atenção: A restauração de dados irá substituir COMPLETAMENTE todas as informações atuais do banco de dados pelos dados deste backup.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Registros encontrados:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            countsWidget,
          ],
        ),
        danger: true,
      );

      if (confirm == true) {
        _showLoading('Restaurando banco de dados a partir do JSON...');
        await importUseCase.restoreJson(jsonString);

        // Fecha a conexão antiga antes de invalidar — evita duas instâncias
        // do AppDatabase abertas ao mesmo tempo sobre o mesmo arquivo.
        await ref.read(databaseProvider).close();
        ref.invalidate(databaseProvider);

        _hideLoading();
        _showSuccessSnackBar('Banco de dados restaurado!');
      }
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao restaurar JSON: $e\n$st');
      _showErrorSnackBar(
        'Erro ao restaurar JSON: ${e is FormatException ? e.message : e}',
      );
    }
  }

  Future<void> _handleDatabaseRestore() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          final cs = context.colorScheme;
          return AlertDialog(
            title: const Text('Substituir Banco de Dados?'),
            content: const Text(
              'Você está prestes a substituir fisicamente o arquivo do banco de dados SQLite. '
              'Esta ação apagará todos os dados atuais e reiniciará a conexão com o novo banco de dados.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              AppButton(
                label: 'Substituir',
                variant: AppButtonVariant.destructive,
                size: AppButtonSize.compact,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        _showLoading('Restaurando arquivo SQLite...');
        final backupUseCase = ref.read(backupDatabaseUseCaseProvider);

        await backupUseCase.restoreBackup(filePath);

        // Invalidate the provider to rebuild database schema connection
        ref.invalidate(databaseProvider);

        _hideLoading();
        _showSuccessSnackBar(
          'Arquivo do banco de dados substituído com sucesso!',
        );
      }
    } catch (e, st) {
      _hideLoading();
      debugPrint('Erro ao substituir banco: $e\n$st');
      _showErrorSnackBar(
        'Erro ao substituir banco: ${e is FormatException ? e.message : e}',
      );
    }
  }

  Future<bool?> _showImportPreviewDialog({
    required String title,
    required Widget content,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = context.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          content: SingleChildScrollView(child: content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            AppButton(
              label: danger ? 'Restaurar' : 'Confirmar',
              variant: danger
                  ? AppButtonVariant.destructive
                  : AppButtonVariant.primary,
              size: AppButtonSize.compact,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _translateTableName(String key) {
    switch (key) {
      case 'accounts':
        return 'Contas';
      case 'categories':
        return 'Categorias';
      case 'transactions':
        return 'Transações';
      case 'entries':
        return 'Lançamentos Contábeis';
      case 'credit_cards':
        return 'Cartões de Crédito';
      case 'goals':
        return 'Metas';
      case 'investments':
        return 'Investimentos';
      case 'financings':
        return 'Financiamentos';
      case 'recurring_rules':
        return 'Recorrentes';
      case 'badges':
        return 'Conquistas';
      case 'streaks':
        return 'Sequências';
      default:
        return key;
    }
  }

  String _formatIsoString(dynamic isoString) {
    if (isoString is! String) return '';
    try {
      final parsed = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
    } catch (_) {
      return isoString;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.customColors.income,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String pJoin(String part1, String part2) {
    return '$part1${Platform.pathSeparator}$part2';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final isWide = Breakpoints.isWide(context);

    final df = DateFormat('dd/MM/yyyy');
    final dateRangeLabel = _startDate != null && _endDate != null
        ? '${df.format(_startDate!)} - ${df.format(_endDate!)}'
        : 'Todo o Período';

    final exportSection = _buildExportSection(cs, tt, dateRangeLabel);
    final backupSection = _buildBackupSection(cs, tt);
    final importSection = _buildImportSection(cs, tt);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                exportSection,
                const SizedBox(height: 20),
                backupSection,
                const SizedBox(height: 20),
                importSection,
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 0.5),
          SizedBox(
            width: 380,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Informações',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sobre',
                          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'BestFin é um aplicativo de finanças pessoais multiplataforma que utiliza contabilidade de partida dobrada para gerenciar suas finanças com total controle e transparência.',
                          style: tt.bodySmall?.copyWith(color: cs.onSurface),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Recomendações',
                          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Use backups criptografados para seus dados financeiros\n• Mantenha cópias de segurança em locais diferentes\n• Revise as importações antes de confirmar',
                          style: tt.bodySmall?.copyWith(color: cs.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            exportSection,
            const SizedBox(height: 20),
            backupSection,
            const SizedBox(height: 20),
            importSection,
            const SizedBox(height: 48),
          ],
        ),

        if (_isLoading)
          Container(
            color: Colors.black54,
            child: ImportProgressWidget(message: _loadingMessage),
          ),
      ],
    );
  }

  Widget _buildExportSection(ColorScheme cs, TextTheme tt, String dateRangeLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtro de Exportação',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final preset in _periodPresets)
                      ChoiceChip(
                        label: Text(preset),
                        selected: _selectedPreset == preset,
                        onSelected: (_) => _applyPreset(preset),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text(
                          dateRangeLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_startDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _clearDateRange,
                        icon: const Icon(Icons.clear_rounded),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Separador CSV',
                  style: tt.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: ';',
                      label: Text('Ponto e Vírgula ( ; )'),
                    ),
                    ButtonSegment<String>(
                      value: ',',
                      label: Text('Vírgula ( , )'),
                    ),
                  ],
                  selected: {_csvSeparator},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _csvSeparator = newSelection.first;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Formatos de Exportação',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),

        ExportButton(
          icon: Icons.picture_as_pdf_rounded,
          label: 'Relatório Financeiro',
          format: 'PDF',
          color: Colors.red.shade700,
          onTap: _handleExportPdf,
        ),
        const SizedBox(height: 12),
        ExportButton(
          icon: Icons.table_chart_rounded,
          label: 'Planilha de Transações',
          format: 'CSV',
          color: Colors.green.shade700,
          onTap: _handleExportCsv,
        ),
        const SizedBox(height: 12),
        ExportButton(
          icon: Icons.code_rounded,
          label: 'Backup de Dados Estruturados',
          format: 'JSON',
          color: Colors.orange.shade800,
          onTap: _handleExportJson,
        ),
      ],
    );
  }

  Widget _buildBackupSection(ColorScheme cs, TextTheme tt) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  'Cópia de Segurança SQLite',
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Crie um backup do banco de dados completo do BestFin. '
              'O backup criptografado protege seus dados com uma senha '
              '(recomendado); o .sqlite puro sai sem proteção e só deve '
              'ser guardado em local seguro.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _handleEncryptedBackup,
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Exportar Backup Criptografado'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleDatabaseBackup,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Exportar .sqlite (sem senha)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection(ColorScheme cs, TextTheme tt) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_backup_restore_rounded,
                  color: cs.secondary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Importação e Restauração',
                  style: tt.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Importe transações de outras planilhas em CSV ou restaure dados completos '
              'a partir de arquivos de backup JSON ou arquivos de banco de dados SQLite.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleImportCsv,
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('Importar CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleRestoreJson,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restaurar JSON'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleEncryptedRestore,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Restaurar Backup Criptografado'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/pdf-import'),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Importar Fatura PDF'),
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Substituir Arquivo SQLite',
              icon: Icons.settings_system_daydream_rounded,
              variant: AppButtonVariant.destructiveOutlined,
              expanded: true,
              onPressed: _handleDatabaseRestore,
            ),
          ],
        ),
      ),
    );
  }
}
