import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/widgets/category_multi_select_button.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

class GoalCategorySelector extends ConsumerWidget {
  final List<String> selectedCategoryIds;
  final ValueChanged<List<String>> onChanged;

  const GoalCategorySelector({
    super.key,
    required this.selectedCategoryIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFlat = ref.watch(allFlatCategoriesProvider);
    final candidates = allFlat.where((c) => !c.isArchived).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    if (candidates.isEmpty) return const SizedBox.shrink();

    return CategoryMultiSelectButton(
      selectedIds: selectedCategoryIds,
      onChanged: onChanged,
      candidates: candidates,
      label: 'Categorias absorvidas',
    );
  }
}
