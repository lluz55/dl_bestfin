import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/color_schemes.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/pdf_import/presentation/providers/pdf_import_provider.dart';

class PdfImportScreen extends ConsumerStatefulWidget {
  const PdfImportScreen({super.key});

  @override
  ConsumerState<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends ConsumerState<PdfImportScreen> {
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );
    if (result == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Lendo PDF...';
    });

    try {
      Uint8List bytes;
      if (kIsWeb || result.files.single.bytes != null) {
        bytes = result.files.single.bytes!;
      } else {
        bytes = await File(result.files.single.path!).readAsBytes();
      }

      setState(() => _statusMessage = 'Analisando transações...');

      final useCase = ref.read(importPdfUseCaseProvider);
      final transactions = await useCase(bytes);

      if (!mounted) return;
      await context.push('/pdf-import/review', extra: transactions);
    } on FormatException catch (e) {
      _showSnack(e.message, error: true);
    } catch (e) {
      _showSnack('Erro ao processar PDF: $e', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : (Theme.of(context).extension<CustomColors>()?.income ??
                Theme.of(context).colorScheme.primary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(
        title: 'Importar Fatura / Recibo PDF',
        infoDescription: 'Importe extratos bancários e faturas de cartão de crédito em PDF de forma automática. O app extrai os dados e você revisa antes de importar.',
        infoFeatures: [
          'Suporte a Nubank, Banco do Brasil e outros',
          'Extração automática de dados',
          'Revisão antes de importar',
          'Fallback para LLM on-device',
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Icon banner
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 48,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Importar PDF Bancário',
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'Selecione uma fatura de cartão de crédito ou comprovante de transferência/Pix para importar as transações automaticamente.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Supported formats
              _SupportedFormatCard(cs: cs, tt: tt),
              const SizedBox(height: 32),

              // Loading state or pick button
              if (_isLoading) ...[
                const Center(child: AppLoadingIndicator()),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ] else
                AppButton(
                  label: 'Selecionar PDF',
                  icon: Icons.upload_file_rounded,
                  expanded: true,
                  onPressed: _pickAndParse,
                ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportedFormatCard extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _SupportedFormatCard({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formatos suportados',
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _FormatRow(
            icon: Icons.credit_card_rounded,
            color: cs.primary,
            label: 'Nubank Fatura',
            detail: 'Fatura mensal do cartão de crédito',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 8),
          _FormatRow(
            icon: Icons.pix_rounded,
            color: cs.primary,
            label: 'Nubank Comprovante / Pix',
            detail: 'Recibos de Pix e transferências',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 8),
          _FormatRow(
            icon: Icons.account_balance_rounded,
            color: (Theme.of(context).extension<CustomColors>()?.warning ?? cs.tertiary),
            label: 'Banco do Brasil Comprovante',
            detail: 'Comprovantes de Pix e transferências',
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }
}

class _FormatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  final ColorScheme cs;
  final TextTheme tt;

  const _FormatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                detail,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, size: 18, color: color),
      ],
    );
  }
}
