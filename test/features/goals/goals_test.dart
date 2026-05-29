import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/features/goals/domain/usecases/calculate_monthly_target.dart';

void main() {
  group('CalculateMonthlyTarget', () {
    final calculate = CalculateMonthlyTarget();

    test('should calculate correct scenarios for positive inputs', () {
      final result = calculate(remainingInCents: 100000, months: 10);

      expect(result.idealInCents, 10000); // 100000 / 10
      expect(result.pessimisticInCents, 12000); // 10000 * 1.2
      expect(result.optimisticInCents, 8000); // 10000 * 0.8
      expect(result.months, 10);
    });

    test('should return zeroes when months is zero or negative', () {
      final resultZero = calculate(remainingInCents: 100000, months: 0);
      expect(resultZero.idealInCents, 0);
      expect(resultZero.pessimisticInCents, 0);
      expect(resultZero.optimisticInCents, 0);

      final resultNegative = calculate(remainingInCents: 100000, months: -5);
      expect(resultNegative.idealInCents, 0);
      expect(resultNegative.pessimisticInCents, 0);
      expect(resultNegative.optimisticInCents, 0);
    });

    test('should return zeroes when remainingInCents is zero or negative', () {
      final resultZero = calculate(remainingInCents: 0, months: 10);
      expect(resultZero.idealInCents, 0);
      expect(resultZero.pessimisticInCents, 0);
      expect(resultZero.optimisticInCents, 0);

      final resultNegative = calculate(remainingInCents: -500, months: 10);
      expect(resultNegative.idealInCents, 0);
      expect(resultNegative.pessimisticInCents, 0);
      expect(resultNegative.optimisticInCents, 0);
    });

    test('should handle fractional rounding correctly with ceil', () {
      // 100001 / 10 = 10000.1 -> ceil = 10001
      final result = calculate(remainingInCents: 100001, months: 10);

      expect(result.idealInCents, 10001);
      expect(
        result.pessimisticInCents,
        12002,
      ); // 10001 * 1.2 = 12001.2 -> ceil = 12002
      expect(
        result.optimisticInCents,
        8001,
      ); // 10001 * 0.8 = 8000.8 -> ceil = 8001
    });
  });
}
