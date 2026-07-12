import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/categories/presentation/widgets/category_tile.dart';

class CategoryTree extends ConsumerWidget {
  const CategoryTree({
    super.key,
    required this.isReorderMode,
    this.selectedCategory,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isReorderMode;
  final CategoryModel? selectedCategory;
  final void Function(CategoryModel) onSelect;
  final void Function(CategoryModel) onEdit;
  final void Function(CategoryModel) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTree = ref.watch(categoriesTreeProvider);
    final reorder = ref.read(reorderCategoriesProvider);
    final isCompact = Breakpoints.isCompact(context);

    return asyncTree.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (roots) {
        if (roots.isEmpty) {
          return const EmptyState(
            title: 'Sem categorias',
            description: 'Adicione uma categoria para começar.',
            icon: Icons.category_outlined,
          );
        }

        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: EdgeInsets.only(
            bottom: isCompact ? 120 : 24,
            top: 8,
          ),
          itemCount: roots.length,
          onReorder: (oldIndex, newIndex) {
            final mutable = [...roots];
            if (newIndex > oldIndex) newIndex--;
            final item = mutable.removeAt(oldIndex);
            mutable.insert(newIndex, item);
            reorder.call(mutable.map((c) => c.id).toList());
          },
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final category = roots[index];
            final isSelected = selectedCategory?.id == category.id;
            return CategoryTile(
              key: ValueKey(category.id),
              category: category,
              index: index,
              isReorderMode: isReorderMode,
              isSelected: isSelected,
              onTap: () => onSelect(category),
              onEdit: () => onEdit(category),
              onDelete: () => onDelete(category),
            );
          },
        );
      },
    );
  }
}
