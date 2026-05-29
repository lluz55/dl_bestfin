import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/features/credit_cards/data/repositories/invoice_repository.dart';

void main() {
  group('Intelligent Closing Date Lógica', () {
    final holidays = [
      DateTime(2026, 1, 1), // Confraternização Universal
      DateTime(2026, 5, 1), // Dia do Trabalhador
      DateTime(2026, 9, 7), // Independência
      DateTime(2026, 12, 25), // Natal
    ];

    test('Standard closing on weekday returns the exact closing day', () {
      // 5 de Maio de 2026 é uma Terça-feira (Dia útil normal, sem feriados)
      final result = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: 2026,
        month: 5,
        closingDay: 5,
        holidays: holidays,
      );

      expect(result, DateTime(2026, 5, 5));
    });

    test('Closing on Saturday anticipates to Friday', () {
      // 9 de Maio de 2026 é um Sábado. Deve antecipar para Sexta (8 de Maio)
      final result = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: 2026,
        month: 5,
        closingDay: 9,
        holidays: holidays,
      );

      expect(result, DateTime(2026, 5, 8));
    });

    test('Closing on Sunday anticipates to Friday', () {
      // 10 de Maio de 2026 é um Domingo. Deve antecipar para Sexta (8 de Maio)
      final result = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: 2026,
        month: 5,
        closingDay: 10,
        holidays: holidays,
      );

      expect(result, DateTime(2026, 5, 8));
    });

    test('Closing on Holiday anticipates to previous day', () {
      // 1 de Maio de 2026 é uma Sexta-feira (Dia do Trabalhador - Feriado).
      // Deve antecipar para Quinta-feira (30 de Abril)
      final result = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: 2026,
        month: 5,
        closingDay: 1,
        holidays: holidays,
      );

      expect(result, DateTime(2026, 4, 30));
    });

    test('Closing on Holiday falling on Monday anticipates to previous Friday', () {
      // 7 de Setembro de 2026 é uma Segunda-feira (Dia da Independência - Feriado).
      // Deve antecipar para o dia útil anterior.
      // Domingo (6) e Sábado (5) são fins de semana, então deve antecipar até Sexta-feira (4 de Setembro)
      final result = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: 2026,
        month: 9,
        closingDay: 7,
        holidays: holidays,
      );

      expect(result, DateTime(2026, 9, 4));
    });

    test('Dynamic offset 7 days before due date 15th returns 8th of same month', () {
      // dueDay = 15, closingDay = -7. Base date is 15 - 7 = 8 (May 8, 2026, which is Friday, no adjustments)
      final result = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: 2026,
        month: 5,
        closingDay: -7,
        dueDay: 15,
        holidays: holidays,
      );

      expect(result, DateTime(2026, 5, 8));
    });

    test('Dynamic offset 10 days before due date 5th wraps to previous month and anticipates weekend', () {
      // dueDay = 5, closingDay = -10. Base date is May 5 minus 10 days = April 25 (Saturday).
      // Saturday anticipates to Friday (April 24).
      final result = InvoiceRepositoryImpl.calculateClosingDateStatic(
        year: 2026,
        month: 5,
        closingDay: -10,
        dueDay: 5,
        holidays: holidays,
      );

      expect(result, DateTime(2026, 4, 24));
    });
  });
}
