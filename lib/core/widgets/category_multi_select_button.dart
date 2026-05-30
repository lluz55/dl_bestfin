import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';

/// Button that opens a modal bottom sheet checklist for multi-category selection.
class CategoryMultiSelectButton extends StatelessWidget {
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final List<CategoryModel> candidates;
  final String label;

  const CategoryMultiSelectButton({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    required this.candidates,
    this.label = 'Categorias',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = selectedIds.length;
    final preview =
        candidates.where((c) => selectedIds.contains(c.id)).take(3).toList();

    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.category_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
                  Text(
                    count == 0
                        ? 'Nenhuma selecionada'
                        : '$count selecionada${count > 1 ? 's' : ''}',
                    style: tt.labelSmall?.copyWith(
                      color: count > 0 ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (preview.isNotEmpty) ...[
              Row(
                children: [
                  for (final cat in preview)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: CategoryIcon(icon: cat.icon, color: cat.color, size: 26),
                    ),
                  if (count > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '+${count - 3}',
                        style: tt.labelSmall?.copyWith(color: cs.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryChecklistSheet(
        candidates: candidates,
        initialSelectedIds: Set<String>.from(selectedIds),
        onConfirm: (ids) => onChanged(ids.toList()),
      ),
    );
  }
}

class _CategoryChecklistSheet extends StatefulWidget {
  final List<CategoryModel> candidates;
  final Set<String> initialSelectedIds;
  final ValueChanged<Set<String>> onConfirm;

  const _CategoryChecklistSheet({
    required this.candidates,
    required this.initialSelectedIds,
    required this.onConfirm,
  });

  @override
  State<_CategoryChecklistSheet> createState() =>
      _CategoryChecklistSheetState();
}

class _CategoryChecklistSheetState extends State<_CategoryChecklistSheet> {
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelectedIds);
  }

  List<CategoryModel> get _filtered {
    if (_query.isEmpty) return widget.candidates;
    final q = _query.toLowerCase();
    return widget.candidates
        .where((c) => c.displayName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _Handle(cs: cs),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Selecionar Categorias',
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onConfirm(_selected);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SearchBar(
                  hintText: 'Buscar categoria...',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (v) => setState(() => _query = v),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor:
                      WidgetStatePropertyAll(cs.surfaceContainerHighest),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma categoria encontrada',
                          style:
                              tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final cat = _filtered[i];
                          final isSelected = _selected.contains(cat.id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(cat.id);
                              } else {
                                _selected.remove(cat.id);
                              }
                            }),
                            secondary: CategoryIcon(
                              icon: cat.icon,
                              color: cat.color,
                              size: 36,
                            ),
                            title: Text(cat.displayName, style: tt.bodyMedium),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            checkboxShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  final ColorScheme cs;
  const _Handle({required this.cs});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
