import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/llm/domain/models/ai_model_type.dart';

const _ocrPrompt = '''Analise este comprovante ou recibo fiscal. Extraia EXATAMENTE um JSON válido com os seguintes campos:
{
  "amount": <valor total em reais como número, ex: 124.50>,
  "date": "<data no formato YYYY-MM-DD, ou null se não encontrada>",
  "description": "<nome do estabelecimento ou descrição resumida, máx 40 chars>",
  "type": "<expense ou income>",
  "category": "<uma das opções: alimentação, transporte, saúde, lazer, moradia, educação, vestuário, serviços, outros>"
}
Responda SOMENTE com o JSON, sem nenhum texto adicional, explicação ou markdown.''';

class OcrScannerWidget extends ConsumerStatefulWidget {
  const OcrScannerWidget({super.key});

  @override
  ConsumerState<OcrScannerWidget> createState() => _OcrScannerWidgetState();
}

class _OcrScannerWidgetState extends ConsumerState<OcrScannerWidget> {
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  String? _errorMessage;

  // Extracted data
  double? _amount;
  String? _description;
  String? _dateStr;
  String? _category;
  String? _type;

  bool get _hasResult => _amount != null && _description != null;

  void _reset() {
    setState(() {
      _imageBytes = null;
      _isAnalyzing = false;
      _errorMessage = null;
      _amount = null;
      _description = null;
      _dateStr = null;
      _category = null;
      _type = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _errorMessage = null;
        _amount = null;
        _description = null;
        _dateStr = null;
        _category = null;
        _type = null;
      });
      await _analyzeImage(bytes);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao abrir imagem: $e');
      }
    }
  }

  Future<void> _analyzeImage(Uint8List bytes) async {
    final llmService = ref.read(llmServiceProvider);
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final response = await llmService.analyzeImage(bytes, _ocrPrompt, maxTokens: 200);
      _parseResponse(response);
    } on UnsupportedError catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Erro ao analisar imagem: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _parseResponse(String response) {
    // Strip markdown fences if present
    final cleaned = response
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    try {
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final rawAmount = json['amount'];
      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount.toString().replaceAll(',', '.'));

      setState(() {
        _amount = amount;
        _description = json['description'] as String?;
        _dateStr = json['date'] as String?;
        _category = json['category'] as String?;
        _type = json['type'] as String?;
        _errorMessage = amount == null ? 'Não foi possível extrair o valor do comprovante.' : null;
      });
    } catch (_) {
      setState(() => _errorMessage = 'O modelo não retornou um JSON válido. Tente outra imagem.');
    }
  }

  String _mapCategoryId(String? category) {
    return switch (category?.toLowerCase()) {
      'alimentação' => 'cat_food',
      'transporte' => 'cat_transport',
      'saúde' => 'cat_health',
      'lazer' => 'cat_leisure',
      'moradia' => 'cat_housing',
      'educação' => 'cat_education',
      'vestuário' => 'cat_clothing',
      _ => '',
    };
  }

  String _mapCategoryName(String? category) =>
      category != null ? category[0].toUpperCase() + category.substring(1) : 'Outros';

  String _mapCategoryIcon(String? category) {
    return switch (category?.toLowerCase()) {
      'alimentação' => 'restaurant',
      'transporte' => 'directions_car',
      'saúde' => 'medical_services',
      'lazer' => 'sports_esports',
      'moradia' => 'home',
      'educação' => 'school',
      'vestuário' => 'checkroom',
      _ => 'category',
    };
  }

  String _mapCategoryColor(String? category) {
    return switch (category?.toLowerCase()) {
      'alimentação' => '#FF9800',
      'transporte' => '#2196F3',
      'saúde' => '#F44336',
      'lazer' => '#E91E63',
      'moradia' => '#4CAF50',
      'educação' => '#9C27B0',
      'vestuário' => '#795548',
      _ => '#607D8B',
    };
  }

  void _fillTransactionForm() {
    if (!_hasResult) return;
    final accounts = ref.read(activeAccountsProvider);
    final accountId = accounts.isNotEmpty ? accounts.first.id : '';
    final txType = _type == 'income' ? TransactionType.income : TransactionType.expense;
    final catId = _mapCategoryId(_category);
    final catName = _mapCategoryName(_category);
    final catColor = _mapCategoryColor(_category);
    final catIcon = _mapCategoryIcon(_category);
    final amountCents = ((_amount ?? 0) * 100).round();

    DateTime date = DateTime.now();
    if (_dateStr != null && _dateStr != 'null') {
      date = DateTime.tryParse(_dateStr!) ?? DateTime.now();
    }

    final category = catId.isNotEmpty
        ? CategoryModel(
            id: catId,
            name: catName,
            icon: catIcon,
            color: catColor,
            type: txType.name,
            isSystem: true,
            isArchived: false,
            createdAt: DateTime.now(),
          )
        : null;

    final tx = TransactionModel(
      id: '',
      date: date,
      description: _description ?? 'Comprovante digitalizado',
      type: txType,
      categoryId: catId.isNotEmpty ? catId : null,
      category: category,
      isCompleted: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      entries: [
        EntryModel(
          id: '',
          transactionId: '',
          accountId: accountId,
          amount: amountCents,
          type: txType == TransactionType.income ? 'debit' : 'credit',
          createdAt: DateTime.now(),
        ),
      ],
    );

    context.pushReplacement('/transaction/new', extra: tx);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final llmState = ref.watch(llmStateProvider);
    final visionAsync = ref.watch(visionAvailableProvider);
    final isVisionReady = visionAsync.value == true && llmState.status == LlmStatus.ready;
    final isModelReady = llmState.status == LlmStatus.ready;
    final mmProjProgress = ref.watch(mmProjDownloadProgressProvider);
    final selectedModel = ref.watch(selectedModelProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Escanear Comprovante',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_hasResult || _imageBytes != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reset,
              tooltip: 'Limpar',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Privacy info card
              _InfoCard(cs: cs, tt: tt),
              const SizedBox(height: 20),

              if (!isModelReady) ...[
                _ModelNotReadyCard(cs: cs, tt: tt, llmState: llmState),
              ] else if (!isVisionReady && selectedModel.hasVision) ...[
                _VisionNotReadyCard(
                  cs: cs,
                  tt: tt,
                  modelType: selectedModel,
                  mmProjProgress: mmProjProgress,
                  onDownload: () =>
                      ref.read(mmProjDownloadProgressProvider.notifier).download(),
                ),
              ] else if (!isVisionReady && !selectedModel.hasVision) ...[
                _TextModelOcrCard(cs: cs, tt: tt),
              ] else ...[
                // Vision is ready — show camera options
                if (_imageBytes == null && !_hasResult) ...[
                  _CameraPickerSection(
                    cs: cs,
                    tt: tt,
                    onCamera: () => _pickImage(ImageSource.camera),
                    onGallery: () => _pickImage(ImageSource.gallery),
                  ),
                ],

                if (_imageBytes != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      _imageBytes!,
                      height: 280,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_isAnalyzing) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          'Analisando comprovante com IA…',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Identificando valor, data e categoria',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar Outra Imagem'),
                  ),
                ],

                if (_hasResult && !_isAnalyzing) ...[
                  const SizedBox(height: 8),
                  _ExtractionResultCard(
                    cs: cs,
                    tt: tt,
                    amount: _amount!,
                    description: _description!,
                    dateStr: _dateStr,
                    category: _mapCategoryName(_category),
                    type: _type ?? 'expense',
                    onConfirm: _fillTransactionForm,
                    onReset: _reset,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.security, color: cs.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Processamento Local e Seguro',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'A IA analisa o comprovante diretamente neste aparelho. Nenhum dado sai do dispositivo.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelNotReadyCard extends StatelessWidget {
  const _ModelNotReadyCard({
    required this.cs,
    required this.tt,
    required this.llmState,
  });
  final ColorScheme cs;
  final TextTheme tt;
  final LlmState llmState;

  @override
  Widget build(BuildContext context) {
    final label = llmState.status == LlmStatus.uninitialized
        ? 'Modelo de IA não instalado. Instale o modelo nas configurações de IA para usar o escaneamento.'
        : 'Aguarde o modelo de IA terminar de carregar…';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            llmState.status == LlmStatus.uninitialized
                ? Icons.model_training
                : Icons.hourglass_top_rounded,
            size: 48,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(label, style: tt.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _VisionNotReadyCard extends StatelessWidget {
  const _VisionNotReadyCard({
    required this.cs,
    required this.tt,
    required this.modelType,
    required this.mmProjProgress,
    required this.onDownload,
  });
  final ColorScheme cs;
  final TextTheme tt;
  final AiModelType modelType;
  final double? mmProjProgress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Módulo de Visão necessário',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '~${modelType.mmProjSizeMb} MB adicionais',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Para escanear comprovantes com IA, é necessário baixar o módulo de visão (mmproj) do ${modelType.displayName}.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (mmProjProgress != null) ...[
            LinearProgressIndicator(
              value: mmProjProgress,
              backgroundColor: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              'Baixando módulo de visão… ${(mmProjProgress! * 100).toStringAsFixed(0)}%',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Baixar Módulo de Visão'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TextModelOcrCard extends StatelessWidget {
  const _TextModelOcrCard({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.image_not_supported_outlined, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Escaneamento não disponível com o modelo atual',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'O modelo de texto selecionado não suporta análise de imagens. Troque para o MiniCPM-V 4.6 (Multimodal) nas configurações.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CameraPickerSection extends StatelessWidget {
  const _CameraPickerSection({
    required this.cs,
    required this.tt,
    required this.onCamera,
    required this.onGallery,
  });
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escolha uma foto do comprovante',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'A IA irá extrair automaticamente o valor, data e sugerir uma categoria.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Câmera'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Galeria'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dica: Fotografe o comprovante com boa iluminação e na vertical para melhor resultado.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExtractionResultCard extends StatelessWidget {
  const _ExtractionResultCard({
    required this.cs,
    required this.tt,
    required this.amount,
    required this.description,
    required this.dateStr,
    required this.category,
    required this.type,
    required this.onConfirm,
    required this.onReset,
  });
  final ColorScheme cs;
  final TextTheme tt;
  final double amount;
  final String description;
  final String? dateStr;
  final String category;
  final String type;
  final VoidCallback onConfirm;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isIncome = type == 'income';
    final typeLabel = isIncome ? 'Receita (Entrada)' : 'Despesa (Saída)';
    String dateLabel = 'Hoje';
    if (dateStr != null && dateStr != 'null') {
      final d = DateTime.tryParse(dateStr!);
      if (d != null) dateLabel = DateFormat('dd/MM/yyyy').format(d);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprovante Identificado!',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Verifique os dados extraídos pela IA',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 28),
          _ResultRow(
            icon: Icons.description_outlined,
            label: 'Descrição',
            value: description,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 14),
          _ResultRow(
            icon: Icons.monetization_on_outlined,
            label: 'Valor Total',
            value: fmt.format(amount),
            cs: cs,
            tt: tt,
            valueColor: isIncome ? Colors.green : cs.onSurface,
            bold: true,
          ),
          const SizedBox(height: 14),
          _ResultRow(
            icon: Icons.calendar_today_outlined,
            label: 'Data',
            value: dateLabel,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 14),
          _ResultRow(
            icon: Icons.swap_horiz_rounded,
            label: 'Tipo',
            value: typeLabel,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 14),
          _ResultRow(
            icon: Icons.category_outlined,
            label: 'Categoria sugerida',
            value: category,
            cs: cs,
            tt: tt,
            bold: true,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.edit_document),
            label: const Text('Confirmar e Preencher Formulário'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Escanear Outro Comprovante'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
    this.valueColor,
    this.bold = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: valueColor ?? cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
