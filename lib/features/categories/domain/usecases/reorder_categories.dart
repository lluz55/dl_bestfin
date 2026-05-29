import 'package:bestfin/features/categories/data/repositories/category_repository.dart';

class ReorderCategories {
  const ReorderCategories(this._repository);
  final CategoryRepository _repository;

  Future<void> call(List<String> orderedRootIds) =>
      _repository.saveRootOrder(orderedRootIds);
}
