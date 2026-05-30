import 'package:flutter/material.dart';
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
    builder: (_) => ProviderScope(
      child: _CategoryPickerSheet(
        typeFilter: typeFilter,
        selectedCategoryId: selectedCategoryId,
      ),
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

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final shapes = context.shapes;
    final tt = context.textTheme;

    final asyncTree = widget.typeFilter != null
        ? ref.watch(categoriesByTypeProvider(widget.typeFilter!))
        : ref.watch(categoriesTreeProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: shapes.bottomSheet,
          ),
          child: Column(
            children: [
              // Handle
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
              Expanded(
                child: asyncTree.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                  data: (roots) {
                    final flat = _flatten(roots);
                    final filtered = _query.isEmpty
                        ? flat
                        : flat
                              .where(
                                (c) => c.name.toLowerCase().contains(
                                  _query.toLowerCase(),
                                ),
                              )
                              .toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma categoria encontrada'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final category = filtered[i];
                        final isSelected =
                            category.id == widget.selectedCategoryId;

                        return _CategoryPickerTile(
                          category: category,
                          isSelected: isSelected,
                          onTap: () => Navigator.of(context).pop(category),
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
        );
      },
    );
  }

  List<CategoryModel> _flatten(List<CategoryModel> roots) {
    final result = <CategoryModel>[];
    for (final root in roots) {
      result.add(root);
      result.addAll(root.children);
    }
    return result;
  }
}

class _CategoryPickerTile extends StatelessWidget {
  const _CategoryPickerTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: category.isRoot ? 0 : 32, right: 0),
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
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: cs.primary)
          : null,
      onTap: onTap,
    );
  }
}
