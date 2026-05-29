import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';

class AddContribution {
  final GoalRepository repository;
  AddContribution(this.repository);

  /// Registra uma contribuição para o objetivo.
  /// [fromAccountId]: conta de origem da transferência (obrigatória).
  /// Gera transação real de transferência + atualiza currentAmount.
  Future<void> call({
    required String goalId,
    required int amountInCents,
    required String fromAccountId,
    String? notes,
  }) {
    return repository.addContribution(
      goalId: goalId,
      amountInCents: amountInCents,
      fromAccountId: fromAccountId,
      notes: notes,
    );
  }
}
