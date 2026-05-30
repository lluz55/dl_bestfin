import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/domain/usecases/delete_category.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/categories/presentation/widgets/category_tree.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _isReorderMode = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Categorias',
        actions: [
          IconButton(
            icon: Icon(
              _isReorderMode ? Icons.check : Icons.reorder,
              color: _isReorderMode ? cs.primary : null,
            ),
            tooltip: _isReorderMode ? 'Concluir reordenação' : 'Reordenar',
            onPressed: () {
              setState(() {
                _isReorderMode = !_isReorderMode;
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria'),
      ),
      body: CategoryTree(
        isReorderMode: _isReorderMode,
        onEdit: (category) => _openForm(context, ref, categoryToEdit: category),
        onDelete: (category) => _confirmDelete(context, ref, category),
      ),
    );
  }

  void _openForm(
    BuildContext context,
    WidgetRef ref, {
    CategoryModel? categoryToEdit,
  }) {
    if (categoryToEdit != null) {
      context.push('/categories/edit', extra: categoryToEdit);
    } else {
      context.push('/categories/new');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) async {
    final cs = context.colorScheme;
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
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
