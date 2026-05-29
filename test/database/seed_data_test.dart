import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/constants/default_categories.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('seed data is inserted on database creation', () async {
    // To trigger onCreate, we just need to do any query
    final categories = await db.categoriesDao.watchAllCategories().first;

    // Check if the seeded categories match the number of constants
    expect(categories.length, SeedDataConstants.defaultCategories.length);
  });
}
