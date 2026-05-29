import 'package:bestfin/features/categories/data/repositories/category_repository.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';

enum DeleteCategoryResult { deleted, archived, systemProtected }

class DeleteCategory {
  const DeleteCategory(this._repository);
  final CategoryRepository _repository;

  Future<DeleteCategoryResult> call(CategoryModel category) async {
    if (category.isSystem) return DeleteCategoryResult.systemProtected;

    final used = await _repository.hasTransactions(category.id);
    if (used) {
      await _repository.archiveCategory(category.id);
      return DeleteCategoryResult.archived;
    }

    // Also check children — archive parent if any child has transactions
    for (final child in category.children) {
      final childUsed = await _repository.hasTransactions(child.id);
      if (childUsed) {
        await _repository.archiveCategory(category.id);
        return DeleteCategoryResult.archived;
      }
    }

    // Safe to hard-delete (cascades to children via FK setNull)
    for (final child in category.children) {
      await _repository.deleteCategory(child.id);
    }
    await _repository.deleteCategory(category.id);
    return DeleteCategoryResult.deleted;
  }
}
