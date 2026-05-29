import 'package:bestfin/features/categories/data/repositories/category_repository.dart';

class CreateCategory {
  const CreateCategory(this._repository);
  final CategoryRepository _repository;

  Future<String> call({
    required String name,
    required String icon,
    required String color,
    required String type,
    String? parentId,
  }) => _repository.createCategory(
    name: name,
    icon: icon,
    color: color,
    type: type,
    parentId: parentId,
  );
}
