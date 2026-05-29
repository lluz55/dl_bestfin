import 'package:bestfin/features/categories/data/repositories/category_repository.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';

class GetCategoriesTree {
  const GetCategoriesTree(this._repository);
  final CategoryRepository _repository;

  Stream<List<CategoryModel>> call({String? type}) {
    if (type != null) return _repository.watchCategoriesTreeByType(type);
    return _repository.watchCategoriesTree();
  }
}
