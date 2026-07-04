import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/features/budgets/domain/models/budget_model.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/budgets/presentation/providers/budgets_provider.dart';

Future<void> showBudgetFormSheet(
  BuildContext context, {
  BudgetModel? existing,
  required int year,
  required int month,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
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
  final _amountController = TextEditingController();
  CategoryModel? _selectedCategory;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _amountController.text = CurrencyFormatter.centsToInputString(
        widget.existing!.amount,
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountText = _amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final amount = (double.tryParse(amountText) ?? 0) * 100;

    if (amount <= 0) {
      setState(() => _error = 'Informe um valor válido');
      return;
    }
    if (_selectedCategory == null && widget.existing == null) {
      setState(() => _error = 'Selecione uma categoria');
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
          amount.round(),
        );
      } else {
        await ref.read(createBudgetProvider)(
          categoryId: _selectedCategory!.id,
          year: widget.year,
          month: widget.month,
          amount: amount.round(),
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
              isEditing ? 'Editar Envelope' : 'Novo Envelope',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            if (!isEditing) ...[
              Text(
                'Categoria',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _CategorySelector(
                selected: _selectedCategory,
                onSelected: (cat) => setState(() {
                  _selectedCategory = cat;
                  _error = null;
                }),
                cs: cs,
                tt: tt,
              ),
              const SizedBox(height: 20),
            ] else ...[
              Text(
                widget.existing!.categoryName ?? 'Categoria',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 20),
            ],
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppLoadingIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Salvar' : 'Criar Envelope'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final CategoryModel? selected;
  final ValueChanged<CategoryModel> onSelected;
  final ColorScheme cs;
  final TextTheme tt;

  const _CategorySelector({
    required this.selected,
    required this.onSelected,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final cat = await showCategoryPicker(context, typeFilter: 'expense');
        if (cat != null) onSelected(cat);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected?.name ?? 'Toque para selecionar',
                style: tt.bodyMedium?.copyWith(
                  color: selected != null ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
