import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/account_selector.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/recurring/presentation/widgets/frequency_selector.dart';
import 'package:bestfin/features/transactions/presentation/widgets/amount_input.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_type_tabs.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';

/// Tela de criação de uma nova regra de recorrência.
/// Quando [prefillTransactionId] é fornecido, usa a transação existente como base.
class RecurringFormScreen extends ConsumerStatefulWidget {
  final String? prefillTransactionId;
  final int? prefillAmountInCents;
  final String? prefillDescription;
  final TransactionType? prefillType;
  final String? prefillAccountId;
  final String? prefillToAccountId;
  final String? prefillCategoryId;
  final String? prefillCategoryName;
  final String? prefillCategoryColor;
  final String? prefillCategoryIcon;
  final Map<String, dynamic>? prefillData;
  final VoidCallback? onClose;

  const RecurringFormScreen({
    super.key,
    this.prefillTransactionId,
    this.prefillAmountInCents,
    this.prefillDescription,
    this.prefillType,
    this.prefillAccountId,
    this.prefillToAccountId,
    this.prefillCategoryId,
    this.prefillCategoryName,
    this.prefillCategoryColor,
    this.prefillCategoryIcon,
    this.prefillData,
    this.onClose,
  });

  @override
  ConsumerState<RecurringFormScreen> createState() =>
      _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  late TransactionType _type;
  late int _amountInCents;
  late TextEditingController _descriptionController;
  String? _accountId;
  String? _toAccountId;

  String? _categoryId;
  String? _categoryName;
  String? _categoryColor;
  String? _categoryIcon;

  late DateTime _startDate;
  DateTime? _endDate;

  RecurringFrequency _frequency = RecurringFrequency.monthly;
  bool _autoConfirm = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final pd = widget.prefillData;
    _type =
        widget.prefillType ??
        (pd?['type'] as TransactionType?) ??
        TransactionType.expense;
    _amountInCents =
        widget.prefillAmountInCents ?? (pd?['amountInCents'] as int?) ?? 0;
    _descriptionController = TextEditingController(
      text: widget.prefillDescription ?? pd?['description'] as String? ?? '',
    );
    _accountId = widget.prefillAccountId ?? pd?['accountId'] as String?;
    _toAccountId = widget.prefillToAccountId ?? pd?['toAccountId'] as String?;
    _categoryId = widget.prefillCategoryId ?? pd?['categoryId'] as String?;
    _categoryName =
        widget.prefillCategoryName ?? pd?['categoryName'] as String?;
    _categoryColor =
        widget.prefillCategoryColor ?? pd?['categoryColor'] as String?;
    _categoryIcon =
        widget.prefillCategoryIcon ?? pd?['categoryIcon'] as String?;
    _startDate = DateTime.now();
    if (_accountId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _accountId != null) return;
        final accounts = ref.read(activeAccountsProvider);
        if (accounts.isEmpty) return;
        final defaultId = ref.read(defaultAccountIdProvider);
        setState(() {
          if (accounts.length == 1) {
            _accountId = accounts.first.id;
          } else if (defaultId != null &&
              accounts.any((a) => a.id == defaultId)) {
            _accountId = defaultId;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final cat = await showCategoryPicker(
      context,
      typeFilter: _type == TransactionType.transfer ? null : _type.name,
      selectedCategoryId: _categoryId,
    );
    if (cat != null) {
      setState(() {
        _categoryId = cat.id;
        _categoryName = cat.name;
        _categoryColor = cat.color;
        _categoryIcon = cat.icon;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
      helpText: 'Data de encerramento (opcional)',
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    if (_amountInCents <= 0) {
      _showError('Insira um valor maior que R\$ 0,00');
      return;
    }
    if (_type != TransactionType.transfer &&
        _descriptionController.text.trim().isEmpty) {
      _showError('Informe uma descrição para a recorrência.');
      return;
    }
    if (_accountId == null) {
      _showError('Selecione uma conta.');
      return;
    }
    if (_type == TransactionType.transfer) {
      if (_toAccountId == null) {
        _showError('Selecione a conta de destino.');
        return;
      }
      if (_accountId == _toAccountId) {
        _showError('As contas de origem e destino devem ser diferentes.');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      String baseTransactionId;

      String description = _descriptionController.text.trim();
      if (description.isEmpty && _type == TransactionType.transfer) {
        final accounts = ref.read(activeAccountsProvider);
        final account = accounts.where((a) => a.id == _accountId).firstOrNull;
        final toAccount = accounts
            .where((a) => a.id == _toAccountId)
            .firstOrNull;
        description =
            'Transferência: ${account?.name ?? "Origem"} -> ${toAccount?.name ?? "Destino"}';
      } else if (description.isEmpty) {
        description = 'Recorrência';
      }

      if (widget.prefillTransactionId != null) {
        baseTransactionId = widget.prefillTransactionId!;
      } else {
        // Cria a transação-base primeiro
        baseTransactionId = await ref.read(createTransactionProvider)(
          date: _startDate,
          description: description,
          type: _type.name,
          amount: _amountInCents,
          categoryId: _categoryId,
          entityId: null,
          accountId: _accountId!,
          toAccountId: _type == TransactionType.transfer ? _toAccountId : null,
          sentiment: null,
          notes: null,
          isCompleted: false,
        );
      }

      await ref.read(createRecurringRuleProvider)(
        baseTransactionId: baseTransactionId,
        frequency: _frequency,
        interval: 1,
        startDate: _startDate,
        endDate: _endDate,
        autoConfirm: _type == TransactionType.transfer ? false : _autoConfirm,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recorrência criada com sucesso!')),
        );
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) _showError('Erro ao criar recorrência: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final isInModal = widget.onClose != null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: isInModal ? null : const AppPageAppBar(title: 'Nova Recorrência'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        children: [
          TransactionTypeTabs(
            selectedType: _type,
            onTypeChanged: (type) {
              setState(() {
                _type = type;
                _categoryId = null;
                _categoryName = null;
                _categoryIcon = null;
                _categoryColor = null;
              });
            },
          ),
          const SizedBox(height: 24),

          AmountInput(
            amountInCents: _amountInCents,
            color: _type == TransactionType.income
                ? context.customColors.income
                : context.customColors.expense,
            onChanged: (val) => setState(() => _amountInCents = val),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Descrição',
              hintText: 'Ex: Netflix, Aluguel, Salário...',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _type == TransactionType.transfer ? 'Conta de origem' : 'Conta',
            style: tt.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          AccountSelector(
            selectedAccountId: _accountId,
            onAccountSelected: (acc) => setState(() => _accountId = acc?.id),
            hint: _type == TransactionType.transfer
                ? 'Conta de origem'
                : 'Selecione uma conta',
          ),
          const SizedBox(height: 16),

          if (_type == TransactionType.transfer) ...[
            Text(
              'Conta de destino',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            AccountSelector(
              selectedAccountId: _toAccountId,
              onAccountSelected: (acc) =>
                  setState(() => _toAccountId = acc?.id),
              hint: 'Conta de destino',
            ),
            const SizedBox(height: 16),
          ],

          if (_type != TransactionType.transfer) ...[
            Text(
              'Categoria',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCategory,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    if (_categoryId != null &&
                        _categoryIcon != null &&
                        _categoryColor != null) ...[
                      CategoryIcon(
                        icon: _categoryIcon!,
                        color: _categoryColor!,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _categoryName!,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.category_outlined, color: cs.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Selecione uma categoria',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          Text(
            'Frequência',
            style: tt.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          FrequencySelector(
            selected: _frequency,
            onChanged: (freq) => setState(() => _frequency = freq),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Início',
                  date: _startDate,
                  icon: Icons.play_circle_outline_rounded,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Término (opcional)',
                  date: _endDate,
                  icon: Icons.stop_circle_outlined,
                  placeholder: 'Indefinido',
                  onTap: _pickEndDate,
                  onClear: _endDate != null
                      ? () => setState(() => _endDate = null)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: SwitchListTile(
              title: Text(
                'Confirmar automaticamente',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _type == TransactionType.transfer
                    ? 'Transferências recorrentes sempre exigem aprovação manual por segurança'
                    : 'Transações geradas já serão marcadas como confirmadas',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              value: _type == TransactionType.transfer ? false : _autoConfirm,
              onChanged: _type == TransactionType.transfer
                  ? null
                  : (val) => setState(() => _autoConfirm = val),
              secondary: Icon(
                Icons.auto_fix_high_rounded,
                color: _type == TransactionType.transfer
                    ? cs.onSurfaceVariant.withOpacity(0.5)
                    : (_autoConfirm ? cs.primary : cs.onSurfaceVariant),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Criar Recorrência',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final String? placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
    this.placeholder,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fmt = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    date != null ? fmt.format(date!) : (placeholder ?? '—'),
                    style: tt.bodySmall?.copyWith(
                      color: date != null ? cs.onSurface : cs.onSurfaceVariant,
                      fontWeight: date != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
