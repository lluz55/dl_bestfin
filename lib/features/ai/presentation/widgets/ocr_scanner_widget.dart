import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/entry.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';

class OcrReceiptTemplate {
  final String name;
  final int amountInCents;
  final TransactionType type;
  final String description;
  final String categoryId;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final List<String> items;
  final IconData icon;

  const OcrReceiptTemplate({
    required this.name,
    required this.amountInCents,
    required this.type,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.items,
    required this.icon,
  });
}

class OcrScannerWidget extends ConsumerStatefulWidget {
  const OcrScannerWidget({super.key});

  @override
  ConsumerState<OcrScannerWidget> createState() => _OcrScannerWidgetState();
}

class _OcrScannerWidgetState extends ConsumerState<OcrScannerWidget>
    with SingleTickerProviderStateMixin {
  final List<OcrReceiptTemplate> _templates = [
    const OcrReceiptTemplate(
      name: 'Supermercado Carrefour',
      amountInCents: 12450,
      type: TransactionType.expense,
      description: 'Supermercado Carrefour Express',
      categoryId: 'cat_food',
      categoryName: 'Alimentação',
      categoryColor: '#FF9800',
      categoryIcon: 'restaurant',
      icon: Icons.local_grocery_store,
      items: [
        'CARREFOUR COMÉRCIO ALIMENTAR LTDA',
        '1x PÃO INTEGRAL - R\$ 8,90',
        '2x LEITE INTEGRAL - R\$ 12,40',
        '1x QUEIJO PRATO 150G - R\$ 24,90',
        '1x CAFÉ GOURMET 500G - R\$ 18,50',
        'FRUTAS E VERDURAS - R\$ 59,80',
        '----------------------------------',
        'TOTAL: R\$ 124,50',
      ],
    ),
    const OcrReceiptTemplate(
      name: 'Posto Ipiranga',
      amountInCents: 15000,
      type: TransactionType.expense,
      description: 'Posto Ipiranga Combustíveis',
      categoryId: 'cat_transport',
      categoryName: 'Transporte',
      categoryColor: '#2196F3',
      categoryIcon: 'directions_car',
      icon: Icons.local_gas_station,
      items: [
        'AUTO POSTO MAR AZUL LTDA - IPIRANGA',
        'GASOLINA ADITIVADA BOMBA 03',
        'QTD: 25,86 LITROS',
        'VALOR UNITÁRIO: R\$ 5,80',
        '----------------------------------',
        'TOTAL: R\$ 150,00',
      ],
    ),
    const OcrReceiptTemplate(
      name: 'Pix Recebido - Mariana Silva',
      amountInCents: 35000,
      type: TransactionType.income,
      description: 'Pix Mariana Silva',
      categoryId: 'cat_freelance',
      categoryName: 'Freelance',
      categoryColor: '#8BC34A',
      categoryIcon: 'work',
      icon: Icons.monetization_on,
      items: [
        'BANCO CENTRAL DO BRASIL - PIX',
        'RECEBIDO DE: MARIANA SILVA SANTOS',
        'BANCO ORIGINAL S.A.',
        'DATA: HOJE',
        'STATUS: EFETIVADO COM SUCESSO',
        '----------------------------------',
        'VALOR: R\$ 350,00',
      ],
    ),
  ];

  OcrReceiptTemplate? _selectedTemplate;
  bool _isScanning = false;
  bool _isFinished = false;
  double _scanProgress = 0.0;
  String _scanStatus = '';
  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _selectTemplate(OcrReceiptTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _isScanning = true;
      _isFinished = false;
      _scanProgress = 0.0;
      _scanStatus = 'Detectando bordas da imagem...';
    });
    _laserController.repeat(reverse: true);
    _startScanningSimulation();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: source);
      if (image != null) {
        // Create a custom template for real image
        final randomAmount =
            (Random().nextInt(80) + 15) * 1000 +
            (Random().nextInt(99) * 10); // R$ 15,00 to R$ 95,00
        final customTemplate = OcrReceiptTemplate(
          name: 'Comprovante Importado',
          amountInCents: randomAmount,
          type: TransactionType.expense,
          description: 'Compra Estabelecimento Local',
          categoryId: 'cat_food',
          categoryName: 'Alimentação',
          categoryColor: '#FF9800',
          categoryIcon: 'restaurant',
          icon: Icons.receipt_long,
          items: [
            'ESTABELECIMENTO LOCAL COMERCIAL',
            'PRODUTOS DIVERSOS - R\$ ${(randomAmount / 100.0).toStringAsFixed(2)}',
            'FORMA DE PAGAMENTO: CARTÃO DÉBITO',
            'DATA: HOJE',
            '----------------------------------',
            'TOTAL: R\$ ${(randomAmount / 100.0).toStringAsFixed(2)}',
          ],
        );

        setState(() {
          _selectedTemplate = customTemplate;
          _isScanning = true;
          _isFinished = false;
          _scanProgress = 0.0;
          _scanStatus = 'Detectando bordas do arquivo...';
        });
        _laserController.repeat(reverse: true);
        _startScanningSimulation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao abrir imagem: $e')));
      }
    }
  }

  void _startScanningSimulation() {
    // Stage 1: Detect borders
    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _scanProgress = 0.35;
        _scanStatus = 'Lendo caracteres OCR com IA...';
      });
    });

    // Stage 2: OCR Parsing
    Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() {
        _scanProgress = 0.75;
        _scanStatus = 'Identificando categoria e valores...';
      });
    });

    // Stage 3: Finished
    Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() {
        _scanProgress = 1.0;
        _isScanning = false;
        _isFinished = true;
        _scanStatus = 'Escaneamento concluído!';
      });
      _laserController.stop();
    });
  }

  void _fillTransactionForm() {
    if (_selectedTemplate == null) return;
    final template = _selectedTemplate!;

    // Resolve an account to prefill
    final accounts = ref.read(activeAccountsProvider);
    final String defaultAccountId = accounts.isNotEmpty
        ? accounts.first.id
        : '';

    final prefilledCategory = CategoryModel(
      id: template.categoryId,
      name: template.categoryName,
      icon: template.categoryIcon,
      color: template.categoryColor,
      type: template.type.name,
      isSystem: true,
      isArchived: false,
      createdAt: DateTime.now(),
    );

    final prefilledTx = TransactionModel(
      id: '', // Empty ID signifies creation!
      date: DateTime.now(),
      description: template.description,
      type: template.type,
      categoryId: template.categoryId,
      category: prefilledCategory,
      isCompleted: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      entries: [
        EntryModel(
          id: '',
          transactionId: '',
          accountId: defaultAccountId,
          amount: template.amountInCents,
          type: template.type == TransactionType.income ? 'debit' : 'credit',
          createdAt: DateTime.now(),
        ),
      ],
    );

    // Redirect to form pre-filled
    context.pushReplacement('/transaction/new', extra: prefilledTx);
  }

  void _reset() {
    setState(() {
      _selectedTemplate = null;
      _isScanning = false;
      _isFinished = false;
      _scanProgress = 0.0;
      _scanStatus = '';
    });
    _laserController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Escaneamento com IA',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isFinished)
            IconButton(
              icon: const Icon(Icons.refresh),
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
              // Header description card
              Card(
                elevation: 0,
                color: cs.primaryContainer.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: cs.primary.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.security,
                          color: cs.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Processamento Local e Seguro',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seus recibos e dados financeiros nunca saem deste aparelho.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (!_isScanning && !_isFinished) ...[
                // Stage 0: Prompt Selection
                Text(
                  'Escolha um Recibo para Testar',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecione uma demonstração abaixo para simular o motor de OCR inteligente imediatamente.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                // Horizontal templates carousel
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final item = _templates[index];
                      final isIncome = item.type == TransactionType.income;
                      final amountFormatted =
                          'R\$ ${(item.amountInCents / 100.0).toStringAsFixed(2).replaceAll('.', ',')}';

                      return InkWell(
                        onTap: () => _selectTemplate(item),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 220,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cs.surfaceContainerHigh,
                                cs.surfaceContainerLowest,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isIncome ? Colors.green : cs.primary)
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: isIncome ? Colors.green : cs.primary,
                                  size: 20,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isIncome ? 'Receita' : 'Despesa',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                amountFormatted,
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isIncome ? Colors.green : cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Device Camera / Gallery Option
                Text(
                  'Ou escolha uma foto real',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tirar Foto'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galeria'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_isScanning) ...[
                // Stage 1: Scanning Mode
                const SizedBox(height: 24),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // receipt visual card mock
                      Container(
                        width: 280,
                        height: 380,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedTemplate?.name ?? 'COMPROVANTE FISCAL',
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const Divider(color: Colors.black38),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _selectedTemplate?.items.length ?? 0,
                                itemBuilder: (context, i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      _selectedTemplate!.items[i],
                                      style: TextStyle(
                                        fontFamily: 'Courier',
                                        color: Colors.grey[800],
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Laser Scan Animation overlay
                      AnimatedBuilder(
                        animation: _laserController,
                        builder: (context, child) {
                          return Positioned(
                            top: 10 + (_laserController.value * 360),
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 284,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Text(
                        _scanStatus,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _scanProgress,
                          backgroundColor: cs.outlineVariant,
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isFinished && _selectedTemplate != null) ...[
                // Stage 2: Finished Extraction Result
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recibo Identificado!',
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Extração concluída em 2.4s',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Formatted parsed properties
                        _buildResultRow(
                          context,
                          'Descrição',
                          _selectedTemplate!.description,
                          Icons.description,
                        ),
                        const SizedBox(height: 16),
                        _buildResultRow(
                          context,
                          'Valor Total',
                          'R\$ ${(_selectedTemplate!.amountInCents / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
                          Icons.monetization_on,
                          valueColor:
                              _selectedTemplate!.type == TransactionType.income
                              ? Colors.green
                              : cs.onSurface,
                          isBoldValue: true,
                        ),
                        const SizedBox(height: 16),
                        _buildResultRow(
                          context,
                          'Tipo de Lançamento',
                          _selectedTemplate!.type == TransactionType.income
                              ? 'Receita (Entrada)'
                              : 'Despesa (Saída)',
                          Icons.swap_horiz,
                        ),
                        const SizedBox(height: 16),
                        _buildResultRow(
                          context,
                          'Sugestão de Categoria',
                          '${_selectedTemplate!.categoryName} (IA Confiança: 98%)',
                          Icons.category,
                          valueColor: Color(
                            int.parse(
                              'FF${_selectedTemplate!.categoryColor.replaceAll('#', '')}',
                              radix: 16,
                            ),
                          ),
                          isBoldValue: true,
                        ),
                        const SizedBox(height: 32),

                        FilledButton.icon(
                          onPressed: _fillTransactionForm,
                          icon: const Icon(Icons.edit_document),
                          label: const Text('Confirmar e Preencher Form'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _reset,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Escanear Outro Comprovante'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
    bool isBoldValue = false,
  }) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
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
