import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

Future<CategoryModel?> showCategoryPicker(
  BuildContext context, {
  String? typeFilter,
  String? selectedCategoryId,
}) {
  return showAdaptiveModal<CategoryModel>(
    context: context,
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
    return roots;
  }

  void _openSubcategoryPicker(
    BuildContext context,
    CategoryModel parent,
  ) async {
    final selected = await showAdaptiveModal<CategoryModel>(
      context: context,
      builder: (_) => SubcategoryPickerSheet(
        parent: parent,
        selectedCategoryId: widget.selectedCategoryId,
      ),
    );
    if (!context.mounted) return;
    if (selected != null) {
      Navigator.of(context).pop(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final asyncTree = widget.typeFilter != null
        ? ref.watch(categoriesByTypeProvider(widget.typeFilter!))
        : ref.watch(categoriesTreeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categoria',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
            data: (roots) {
              final items = _buildItems(roots);

              if (items.isEmpty) {
                return const Center(
                  child: Text('Nenhuma categoria encontrada'),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final category = items[i];
                        final isSelected =
                            category.id == widget.selectedCategoryId;

                        return _CategoryPickerTile(
                          category: category,
                          isSelected: isSelected,
                          onTap: category.hasChildren
                              ? () => _openSubcategoryPicker(context, category)
                              : () => Navigator.of(context).pop(category),
                          cs: cs,
                          tt: tt,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
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
    final Widget? trailing;
    if (category.hasChildren) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.check_circle_rounded,
                color: cs.primary,
                size: 20,
              ),
            ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ],
      );
    } else {
      trailing = isSelected
          ? Icon(Icons.check_circle_rounded, color: cs.primary)
          : null;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CategoryIcon(
        icon: category.icon,
        color: category.color,
        parentIcon: category.parentIcon,
        parentColor: category.parentColor,
        size: 40,
      ),
      title: _TitleWithOptionalSubtitle(
        displayName: category.displayName,
        typeLabel: category.typeLabel,
        isSelected: isSelected,
        cs: cs,
        tt: tt,
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _TitleWithOptionalSubtitle extends StatelessWidget {
  const _TitleWithOptionalSubtitle({
    required this.displayName,
    required this.typeLabel,
    required this.isSelected,
    required this.cs,
    required this.tt,
  });

  final String displayName;
  final String typeLabel;
  final bool isSelected;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final namePainter = TextPainter(
          text: TextSpan(
            text: displayName,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? cs.primary : cs.onSurface,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);

        final showSubtitle = !namePainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? cs.primary : cs.onSurface,
              ),
            ),
            if (showSubtitle)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  typeLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SubcategoryPickerSheet extends StatelessWidget {
  const SubcategoryPickerSheet({super.key, required this.parent, this.selectedCategoryId});

  final CategoryModel parent;
  final String? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parent.name,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: parent.children.length,
            itemBuilder: (context, i) {
              final child = parent.children[i];
              final isSelected = child.id == selectedCategoryId;

              return _CategoryPickerTile(
                category: child,
                isSelected: isSelected,
                onTap: child.hasChildren
                    ? () async {
                        final selected = await showAdaptiveModal<CategoryModel>(
                          context: context,
                          builder: (_) => SubcategoryPickerSheet(
                            parent: child,
                            selectedCategoryId: selectedCategoryId,
                          ),
                        );
                        if (!context.mounted) return;
                        if (selected != null) {
                          Navigator.of(context).pop(selected);
                        }
                      }
                    : () => Navigator.of(context).pop(child),
                cs: cs,
                tt: tt,
              );
            },
          ),
        ),
      ],
    );
  }
}
