import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/categories/data/repositories/category_repository.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/categories/domain/usecases/create_category.dart';
import 'package:bestfin/features/categories/domain/usecases/delete_category.dart';
import 'package:bestfin/features/categories/domain/usecases/reorder_categories.dart';
import 'package:bestfin/features/categories/domain/usecases/set_category_children.dart';
import 'package:bestfin/features/categories/domain/usecases/update_category.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CategoryRepositoryImpl(database);
});

final categoriesTreeProvider = StreamProvider<List<CategoryModel>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategoriesTree();
});

final categoriesByTypeProvider =
    StreamProvider.family<List<CategoryModel>, String>((ref, type) {
      return ref
          .watch(categoryRepositoryProvider)
          .watchCategoriesTreeByType(type);
    });

final allFlatCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final tree = ref.watch(categoriesTreeProvider).value ?? [];
  // Deduplicate by ID — a subcategory can appear under multiple parents
  final Map<String, CategoryModel> byId = {};
  for (final root in tree) {
    byId[root.id] = root;
    for (final child in root.children) {
      byId[child.id] = child;
    }
  }
  return byId.values.toList();
});

final createCategoryProvider = Provider<CreateCategory>((ref) {
  return CreateCategory(ref.watch(categoryRepositoryProvider));
});

final updateCategoryProvider = Provider<UpdateCategory>((ref) {
  return UpdateCategory(ref.watch(categoryRepositoryProvider));
});

final setCategoryChildrenProvider = Provider<SetCategoryChildren>((ref) {
  return SetCategoryChildren(ref.watch(categoryRepositoryProvider));
});

final deleteCategoryProvider = Provider<DeleteCategory>((ref) {
  return DeleteCategory(ref.watch(categoryRepositoryProvider));
});

final reorderCategoriesProvider = Provider<ReorderCategories>((ref) {
  return ReorderCategories(ref.watch(categoryRepositoryProvider));
});
