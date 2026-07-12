import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/investments/presentation/providers/investments_provider.dart';
import 'package:bestfin/features/investments/domain/models/investment.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';

class InvestmentFormScreen extends ConsumerStatefulWidget {
  final Investment? existingInvestment;
  final VoidCallback? onClose;

  const InvestmentFormScreen({
    super.key,
    this.existingInvestment,
    this.onClose,
  });

  @override
  ConsumerState<InvestmentFormScreen> createState() =>
      _InvestmentFormScreenState();
}

class _InvestmentFormScreenState extends ConsumerState<InvestmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.existingInvestment != null;

  late String _type;
  late int _investedAmountCents;
  late int _currentYieldCents;
  bool _isProfit = true; // True for positive yield, false for loss
  DateTime? _maturityDate;

  final _nameController = TextEditingController();

  final List<Map<String, String>> _types = [
    {'value': 'fixed_income', 'label': 'Renda Fixa'},
    {'value': 'stocks', 'label': 'Ações'},
    {'value': 'fiis', 'label': 'FIIs'},
    {'value': 'crypto', 'label': 'Criptomoedas'},
    {'value': 'savings', 'label': 'Poupança'},
    {'value': 'cdb', 'label': 'CDB'},
    {'value': 'tesouro', 'label': 'Tesouro Direto'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final inv = widget.existingInvestment!;
      _nameController.text = inv.name;
      _type = inv.type;
      _investedAmountCents = inv.investedAmount;
      _currentYieldCents = inv.currentYield.abs();
      _isProfit = inv.currentYield >= 0;
      _maturityDate = inv.maturityDate;
    } else {
      _type = 'fixed_income';
      _investedAmountCents = 0;
      _currentYieldCents = 0;
      _isProfit = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectMaturityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _maturityDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
    if (picked != null) {
      setState(() {
        _maturityDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_investedAmountCents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe o valor aplicado')));
      return;
    }

    final repo = ref.read(investmentRepositoryProvider);
    final name = _nameController.text.trim();
    final finalYield = _isProfit ? _currentYieldCents : -_currentYieldCents;

    try {
      if (_isEditing) {
        await repo.updateInvestment(
          id: widget.existingInvestment!.id,
          name: name,
          type: _type,
          investedAmount: _investedAmountCents,
          currentYield: finalYield,
          maturityDate: _maturityDate,
        );
      } else {
        await repo.createInvestment(
          name: name,
          type: _type,
          investedAmount: _investedAmountCents,
          currentYield: finalYield,
          maturityDate: _maturityDate,
        );
      }

      ref.invalidate(investmentsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Investimento atualizado!'
                  : 'Investimento cadastrado!',
            ),
            backgroundColor: context.colorScheme.primary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final isInModal = widget.onClose != null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: isInModal
          ? null
          : AppPageAppBar(
              title: _isEditing ? 'Editar Ativo' : 'Novo Investimento',
            ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome do Investimento',
                hintText: 'Ex: Tesouro Selic 2029, Ações PETR4',
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Informe o nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Type Dropdown
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                labelText: 'Tipo de Ativo',
                prefixIcon: const Icon(Icons.pie_chart_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: _types.map((t) {
                return DropdownMenuItem<String>(
                  value: t['value'],
                  child: Text(t['label']!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _type = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Invested Amount
            AmountInput(
              amountInCents: _investedAmountCents,
              label: 'Valor Aplicado',
              color: context.colorScheme.primary,
              onChanged: (val) => setState(() => _investedAmountCents = val),
            ),
            const SizedBox(height: 24),

            // Current Yield Card
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cs.outlineVariant, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rendimento Acumulado (Opcional)',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lucro ou perda acumulado sobre o valor aplicado',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Toggle Profit/Loss
                        ToggleButtons(
                          isSelected: [_isProfit, !_isProfit],
                          onPressed: (index) {
                            setState(() {
                              _isProfit = index == 0;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          constraints: const BoxConstraints(
                            minHeight: 48,
                            minWidth: 64,
                          ),
                          selectedColor: _isProfit
                              ? context.customColors.income
                              : context.customColors.expense,
                          fillColor: _isProfit
                              ? context.customColors.income.withValues(alpha: 0.1)
                              : context.customColors.expense.withValues(alpha: 0.1),
                          children: const [
                            Text(
                              'Lucro (+)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Perda (-)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AmountInput(
                            amountInCents: _currentYieldCents,
                            label: 'Rendimento',
                            color: context.colorScheme.primary,
                            onChanged: (val) =>
                                setState(() => _currentYieldCents = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Maturity Date Selection
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant, width: 1),
              ),
              leading: const Icon(Icons.calendar_month_rounded),
              title: const Text('Data de Vencimento'),
              subtitle: Text(
                _maturityDate == null
                    ? 'Sem vencimento (Ex: Ações, Cripto)'
                    : '${_maturityDate!.day.toString().padLeft(2, '0')}/${_maturityDate!.month.toString().padLeft(2, '0')}/${_maturityDate!.year}',
              ),
              trailing: _maturityDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _maturityDate = null),
                    )
                  : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: _selectMaturityDate,
            ),
            const SizedBox(height: 32),

            // Save Button
            AppButton(
              label: _isEditing
                  ? 'Salvar Alterações'
                  : 'Cadastrar Investimento',
              expanded: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
