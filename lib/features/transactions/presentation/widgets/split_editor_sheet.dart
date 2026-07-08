import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/widgets/category_picker.dart';
import 'package:bestfin/features/transactions/domain/models/split_entry.dart';

class SplitEditorSheet extends StatefulWidget {
  const SplitEditorSheet({super.key, required this.totalAmount});

  final int totalAmount; // centavos

  @override
  State<SplitEditorSheet> createState() => _SplitEditorSheetState();
}

class _SplitEditorSheetState extends State<SplitEditorSheet> {
  final List<_SplitRowState> _rows = [];

  int get _allocated => _rows.fold(0, (sum, r) => sum + r.amount);
  int get _remaining => widget.totalAmount - _allocated;

  void _addRow() {
    setState(() => _rows.add(_SplitRowState()));
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index));
  }

  void _confirm() {
    final splits = _rows
        .map(
          (r) => SplitEntry(
            categoryId: r.categoryId,
            categoryName: r.categoryName,
            categoryColor: r.categoryColor,
            categoryIcon: r.categoryIcon,
            amount: r.amount,
            description: null,
          ),
        )
        .toList();
    Navigator.of(context).pop(splits);
  }

  @override
  void initState() {
    super.initState();
    // Start with two empty rows
    _rows.add(_SplitRowState());
    _rows.add(_SplitRowState());
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final remaining = _remaining;
    final canConfirm =
        remaining == 0 &&
        _rows.isNotEmpty &&
        _rows.every((r) => r.categoryId != null);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Dividir ${CurrencyFormatter.formatCents(widget.totalAmount)} entre categorias',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _rows.length; i++)
                      _SplitRowWidget(
                        key: ValueKey(i),
                        row: _rows[i],
                        onChanged: () => setState(() {}),
                        onRemove: _rows.length > 1 ? () => _removeRow(i) : null,
                      ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRow,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Adicionar divisão'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Restante: ',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCents(remaining),
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: remaining == 0 ? cs.primary : cs.error,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total: ${CurrencyFormatter.formatCents(widget.totalAmount)}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: canConfirm ? _confirm : null,
                        child: const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitRowState {
  String? categoryId;
  String? categoryName;
  String? categoryColor;
  String? categoryIcon;
  int amount = 0;
}

class _SplitRowWidget extends StatefulWidget {
  const _SplitRowWidget({
    super.key,
    required this.row,
    required this.onChanged,
    this.onRemove,
  });

  final _SplitRowState row;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_SplitRowWidget> createState() => _SplitRowWidgetState();
}

class _SplitRowWidgetState extends State<_SplitRowWidget> {
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.row.amount > 0
          ? (widget.row.amount / 100).toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final cat = await showCategoryPicker(
      context,
      typeFilter: 'expense',
      selectedCategoryId: widget.row.categoryId,
    );
    if (cat != null) {
      setState(() {
        widget.row.categoryId = cat.id;
        widget.row.categoryName = cat.displayName;
        widget.row.categoryColor = cat.color;
        widget.row.categoryIcon = cat.icon;
      });
      widget.onChanged();
    }
  }

  void _onAmountChanged(String raw) {
    final cleaned = raw.replaceAll('.', '').replaceAll(',', '');
    final cents = int.tryParse(cleaned) ?? 0;
    widget.row.amount = cents;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final hasCategory = widget.row.categoryId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category selector
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: _pickCategory,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasCategory
                        ? cs.primary.withValues(alpha: 0.3)
                        : cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasCategory ? Icons.label_rounded : Icons.label_outline,
                      size: 18,
                      color: hasCategory ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.row.categoryName ?? 'Categoria',
                        style: tt.bodySmall?.copyWith(
                          color: hasCategory
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                          fontWeight: hasCategory ? FontWeight.w600 : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Amount field
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
              ],
              onChanged: _onAmountChanged,
              style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
              ),
            ),
          ),
          // Remove button
          if (widget.onRemove != null)
            IconButton(
              onPressed: widget.onRemove,
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                color: cs.error,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}
