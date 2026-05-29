import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
}
