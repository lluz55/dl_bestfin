import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/domain/usecases/delete_category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/categories/presentation/widgets/category_tree.dart';
import 'package:bestfin/features/categories/presentation/widgets/category_detail_panel.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _isReorderMode = false;
  CategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isExpanded = Breakpoints.isExpanded(context);

    final bool enableSidePanel = isExpanded;

    Widget treeWidget = CategoryTree(
      isReorderMode: _isReorderMode,
      selectedCategory: _selectedCategory,
      onSelect: (category) {
        if (enableSidePanel) {
          setState(() => _selectedCategory = category);
        } else {
          _openForm(context, category);
        }
      },
      onEdit: (category) => _openForm(context, category),
      onDelete: (category) => _confirmDelete(context, category),
    );

    Widget body;
    if (enableSidePanel) {
      final hasSelection = _selectedCategory != null;
      body = LayoutBuilder(
        builder: (context, constraints) {
          const double sidebarMin = 300;
          const double sidebarMax = 440;
          const double sidebarFraction = 0.30;
          final sidebarWidth =
              (constraints.maxWidth * sidebarFraction).clamp(sidebarMin, sidebarMax);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: sidebarWidth, child: treeWidget),
              const VerticalDivider(width: 1, thickness: 0.5),
              Expanded(
                child: hasSelection
                    ? _SelectedDetailPanel(
                        category: _selectedCategory!,
                        onEdit: () => _openForm(context, _selectedCategory),
                        onDelete: () => _confirmDelete(context, _selectedCategory!),
                        key: ValueKey(_selectedCategory!.id),
                      )
                    : _EmptyDetailPanel(
                        onNew: () => _openForm(context, null),
                      ),
              ),
            ],
          );
        },
      );
    } else {
      body = Column(
        children: [
          Expanded(child: treeWidget),
        ],
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Categorias',
        infoDescription: 'Organize suas finanças com categorias e subcategorias personalizadas. Atribua ícones e cores para identificar visualmente cada tipo de transação.',
        infoFeatures: const [
          'Categorias pai e filho hierárquicas',
          'Ícones e cores personalizados',
          'Reordenação por arrasto',
        ],
        actions: [
          if (!enableSidePanel) ...[
            IconButton(
              icon: Icon(
                _isReorderMode ? Icons.check : Icons.reorder,
                color: _isReorderMode ? cs.primary : null,
              ),
              tooltip:
                  _isReorderMode ? 'Concluir reordenação' : 'Reordenar',
              onPressed: () {
                setState(() {
                  _isReorderMode = !_isReorderMode;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Nova categoria',
              onPressed: () => _openForm(context, null),
            ),
          ],
        ],
      ),
      body: body,
    );
  }

  void _openForm(BuildContext context, CategoryModel? categoryToEdit) {
    if (categoryToEdit != null) {
      context.push('/categories/edit', extra: categoryToEdit);
    } else {
      context.push('/categories/new');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryModel category,
  ) async {
    final tt = context.textTheme;

    if (category.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Categorias do sistema não podem ser excluídas.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${category.name}"?'),
        content: Text(
          category.hasChildren
              ? 'Esta categoria tem subcategorias. Todas serão excluídas ou arquivadas.'
              : 'Se houver transações vinculadas, a categoria será arquivada em vez de excluída.',
          style: tt.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.compact,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleteUseCase = ref.read(deleteCategoryProvider);
    final result = await deleteUseCase(category);

    if (context.mounted) {
      final message = switch (result) {
        DeleteCategoryResult.deleted => 'Categoria excluída.',
        DeleteCategoryResult.archived =>
            'Categoria arquivada (possui transações vinculadas).',
        DeleteCategoryResult.systemProtected =>
            'Categoria do sistema não pode ser excluída.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _EmptyDetailPanel extends StatelessWidget {
  const _EmptyDetailPanel({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 80,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma categoria selecionada',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Clique em uma categoria ao lado para ver detalhes, '
              'editar ou gerenciar suas subcategorias.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova categoria'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDetailPanel extends ConsumerWidget {
  const _SelectedDetailPanel({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final CategoryModel category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: CategoryDetailPanel(
        category: category,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}