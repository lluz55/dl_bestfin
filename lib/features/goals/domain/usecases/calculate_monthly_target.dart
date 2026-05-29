import 'package:bestfin/features/goals/domain/models/goal.dart';

class CalculateMonthlyTarget {
  /// Calcula a simulação mensal para atingir [remainingInCents] em [months] meses.
  /// Retorna 3 cenários: pessimista (+20%), ideal, otimista (-20%).
  MonthlySimulation call({required int remainingInCents, required int months}) {
    if (months <= 0 || remainingInCents <= 0) {
      return const MonthlySimulation(
        optimisticInCents: 0,
        idealInCents: 0,
        pessimisticInCents: 0,
        months: 0,
      );
    }

    final ideal = (remainingInCents / months).ceil();
    final pessimistic = (ideal * 1.2).ceil();
    final optimistic = (ideal * 0.8).ceil();

    return MonthlySimulation(
      optimisticInCents: optimistic,
      idealInCents: ideal,
      pessimisticInCents: pessimistic,
      months: months,
    );
  }
}
