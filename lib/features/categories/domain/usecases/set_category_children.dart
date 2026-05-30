import 'package:bestfin/features/categories/data/repositories/category_repository.dart';

class SetCategoryChildren {
  const SetCategoryChildren(this._repository);
  final CategoryRepository _repository;

  Future<void> call(String parentId, List<String> childIds) =>
      _repository.setCategoryChildren(parentId, childIds);
}
