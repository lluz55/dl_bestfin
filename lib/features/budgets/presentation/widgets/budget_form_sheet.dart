import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/category_multi_select_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/budgets/domain/models/budget_model.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/budgets/presentation/providers/budgets_provider.dart';

Future<void> showBudgetFormSheet(
  BuildContext context, {
  BudgetModel? existing,
  required int year,
  required int month,
}) {
  return showAdaptiveModal<void>(
    context: context,
    builder: (ctx) =>
        _BudgetFormSheet(existing: existing, year: year, month: month),
  );
}

class _BudgetFormSheet extends ConsumerStatefulWidget {
  final BudgetModel? existing;
  final int year;
  final int month;

  const _BudgetFormSheet({
    this.existing,
    required this.year,
    required this.month,
  });

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  List<String> _selectedCategoryIds = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _amountController.text = CurrencyFormatter.centsToInputString(
        widget.existing!.amount,
      );
      _selectedCategoryIds = List.from(widget.existing!.categoryIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amountText = _amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = (double.tryParse(amountText) ?? 0) * 100;

    if (name.isEmpty) {
      setState(() => _error = 'Informe um nome para o orçamento');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Informe um valor válido');
      return;
    }
    if (_selectedCategoryIds.isEmpty) {
      setState(() => _error = 'Selecione pelo menos uma categoria');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.existing != null) {
        await ref.read(updateBudgetProvider)(
          widget.existing!.id,
          name: name,
          amount: amount.round(),
          categoryIds: _selectedCategoryIds,
        );
      } else {
        await ref.read(createBudgetProvider)(
          name: name,
          year: widget.year,
          month: widget.month,
          amount: amount.round(),
          categoryIds: _selectedCategoryIds,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isEditing = widget.existing != null;

    // Filtrar categorias de despesa para o seletor.
    final allCats = ref.watch(allFlatCategoriesProvider);
    final expenseCats = allCats
        .where((c) => c.type == 'expense' || c.type == 'both')
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'Editar orçamento' : 'Novo orçamento',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            // Nome do orçamento.
            Text(
              'Nome',
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Ex: Alimentação, Transporte...',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 20),
            // Categorias.
            Text(
              'Categorias',
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            CategoryMultiSelectButton(
              selectedIds: _selectedCategoryIds,
              onChanged: (ids) => setState(() {
                _selectedCategoryIds = ids;
                _error = null;
              }),
              candidates: expenseCats,
              label: 'Categorias de despesa',
            ),
            const SizedBox(height: 20),
            // Valor planejado.
            Text(
              'Valor planejado',
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                hintText: '0,00',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
            ],
            const SizedBox(height: 28),
            AppButton(
              label: isEditing ? 'Salvar' : 'Criar orçamento',
              expanded: true,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
