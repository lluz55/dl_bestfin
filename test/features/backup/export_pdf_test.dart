import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/backup/domain/usecases/export_pdf.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late ExportPdfUseCase exportPdf;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    exportPdf = ExportPdfUseCase(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> seedAccount() async {
    final accountId = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        id: accountId,
        name: 'Conta Corrente',
        type: 'checking',
      ),
    );
    return accountId;
  }

  Future<void> seedTransaction(
    String accountId, {
    required DateTime date,
    required String type,
    required int amount,
    String description = 'Movimento',
  }) async {
    await db.transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: date,
        description: description,
        type: type,
      ),
      accountId: accountId,
      amount: amount,
    );
  }

  test(
    'generates a valid PDF for a multi-month period (monthly evolution)',
    () async {
      final accountId = await seedAccount();

      // Três meses de movimentação para acionar a seção "Evolução Mensal"
      await seedTransaction(
        accountId,
        date: DateTime(2026, 5, 10),
        type: 'income',
        amount: 500000,
      );
      await seedTransaction(
        accountId,
        date: DateTime(2026, 5, 15),
        type: 'expense',
        amount: 120000,
      );
      await seedTransaction(
        accountId,
        date: DateTime(2026, 6, 5),
        type: 'expense',
        amount: 80000,
      );
      await seedTransaction(
        accountId,
        date: DateTime(2026, 7, 1),
        type: 'income',
        amount: 500000,
      );

      final bytes = await exportPdf.execute(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 7, 31, 23, 59, 59),
      );

      // PDF magic header "%PDF"
      expect(bytes.length, greaterThan(4));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    },
  );

  test(
    'generates a valid PDF for a single-month period and for empty data',
    () async {
      final accountId = await seedAccount();
      await seedTransaction(
        accountId,
        date: DateTime(2026, 7, 5),
        type: 'expense',
        amount: 4200,
      );

      // Mês-calendário exato (relatório mensal)
      final monthly = await exportPdf.execute(
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 7, 31, 23, 59, 59),
      );
      expect(String.fromCharCodes(monthly.take(4)), '%PDF');

      // Período sem transações não deve lançar erro
      final empty = await exportPdf.execute(
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2020, 12, 31),
      );
      expect(String.fromCharCodes(empty.take(4)), '%PDF');
    },
  );
}
