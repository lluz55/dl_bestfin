import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

Future<CategoryModel?> showCategoryPicker(
  BuildContext context, {
  String? typeFilter,
  String? selectedCategoryId,
}) {
  return showModalBottomSheet<CategoryModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategoryPickerSheet(
      typeFilter: typeFilter,
      selectedCategoryId: selectedCategoryId,
    ),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({this.typeFilter, this.selectedCategoryId});
  final String? typeFilter;
  final String? selectedCategoryId;

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  String _query = '';
  final Set<String> _expandedIds = {};

  void _toggleExpand(String id) => setState(
    () => _expandedIds.contains(id)
        ? _expandedIds.remove(id)
        : _expandedIds.add(id),
  );

  // Builds the visible list:
  //  - no query  → roots always visible; children visible only if parent is expanded
  //  - with query → all categories that match are shown (collapse state ignored)
  List<CategoryModel> _buildItems(List<CategoryModel> roots) {
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final result = <CategoryModel>[];
      void collect(CategoryModel cat) {
        if (cat.name.toLowerCase().contains(q)) result.add(cat);
        for (final child in cat.children) {
          collect(child);
        }
      }

      for (final root in roots) {
        collect(root);
      }
      return result;
    }

    final result = <CategoryModel>[];
    void addWithExpansion(CategoryModel cat) {
      result.add(cat);
      if (cat.hasChildren && _expandedIds.contains(cat.id)) {
        for (final child in cat.children) {
          addWithExpansion(child);
        }
      }
    }

    for (final root in roots) {
      addWithExpansion(root);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final tt = context.textTheme;

    final asyncTree = widget.typeFilter != null
        ? ref.watch(categoriesByTypeProvider(widget.typeFilter!))
        : ref.watch(categoriesTreeProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: shapes.bottomSheet,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categoria',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SearchBar(
                      hintText: 'Buscar categoria...',
                      leading: const Icon(Icons.search),
                      onChanged: (v) => setState(() => _query = v),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(
                        cs.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: asyncTree.when(
                  loading: () =>
                      const Center(child: AppLoadingIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                  data: (roots) {
                    final items = _buildItems(roots);

                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma categoria encontrada'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final category = items[i];
                        final isSelected =
                            category.id == widget.selectedCategoryId;
                        final isExpanded = _expandedIds.contains(category.id);

                        return _CategoryPickerTile(
                          category: category,
                          isSelected: isSelected,
                          isExpanded: isExpanded,
                          onTap: () => Navigator.of(context).pop(category),
                          onExpandToggle: category.hasChildren
                              ? () => _toggleExpand(category.id)
                              : null,
                          cs: cs,
                          tt: tt,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPickerTile extends StatelessWidget {
  const _CategoryPickerTile({
    required this.category,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    this.onExpandToggle,
    required this.cs,
    required this.tt,
  });

  final CategoryModel category;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onExpandToggle;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final Widget? trailing;
    if (onExpandToggle != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.check_circle_rounded,
                color: cs.primary,
                size: 20,
              ),
            ),
          IconButton(
            icon: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: cs.onSurfaceVariant,
            ),
            onPressed: onExpandToggle,
          ),
        ],
      );
    } else {
      trailing = isSelected
          ? Icon(Icons.check_circle_rounded, color: cs.primary)
          : null;
    }

    return ListTile(
      contentPadding: EdgeInsets.only(
        left: category.parentIds.length * 32.0,
        right: 0,
      ),
      leading: CategoryIcon(
        icon: category.icon,
        color: category.color,
        parentIcon: category.parentIcon,
        parentColor: category.parentColor,
        size: 40,
      ),
      title: Text(
        category.displayName,
        style: tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isSelected ? cs.primary : cs.onSurface,
        ),
      ),
      subtitle: Text(
        category.typeLabel,
        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
