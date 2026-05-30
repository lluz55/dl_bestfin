import 'package:bestfin/features/categories/data/repositories/category_repository.dart';

class UpdateCategory {
  const UpdateCategory(this._repository);
  final CategoryRepository _repository;

  Future<void> call({
    required String id,
    required String name,
    required String icon,
    required String color,
    required String type,
    String? description,
  }) => _repository.updateCategory(
    id: id,
    name: name,
    icon: icon,
    color: color,
    type: type,
    description: description,
  );
}
