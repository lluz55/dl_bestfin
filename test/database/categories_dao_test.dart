import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/categories/data/repositories/category_repository.dart';
import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoryRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('categories can be queried by type', () async {
    final dao = db.categoriesDao;

    await dao.insertCategory(
      CategoriesCompanion.insert(
        id: const Uuid().v4(),
        name: 'Salary',
        icon: 'money',
        color: 'green',
        type: 'income',
      ),
    );

    await dao.insertCategory(
      CategoriesCompanion.insert(
        id: const Uuid().v4(),
        name: 'Food',
        icon: 'restaurant',
        color: 'orange',
        type: 'expense',
      ),
    );

    final incomes = await dao.watchCategoriesByType('income').first;
    expect(incomes.any((c) => c.name == 'Salary'), isTrue);
  });

  test(
    'CategoryRepository watchCategoriesTreeByType returns subcategories of the filtered type',
    () async {
      final parentId = await repo.createCategory(
        name: 'Housing',
        icon: 'home',
        color: 'red',
        type: 'expense',
      );

      final childId = await repo.createCategory(
        name: 'Rent',
        icon: 'house',
        color: 'red',
        type: 'expense',
      );

      await repo.setCategoryChildren(parentId, [childId]);

      final expenseTree = await repo.watchCategoriesTreeByType('expense').first;
      final housing = expenseTree.where((c) => c.name == 'Housing').firstOrNull;
      expect(housing, isNotNull);
      expect(housing!.children.length, equals(1));
      expect(housing.children.first.name, equals('Rent'));
    },
  );
}
