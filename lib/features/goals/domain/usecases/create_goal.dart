import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';

class CreateGoal {
  final GoalRepository repository;
  CreateGoal(this.repository);

  Future<String> call({
    required String name,
    String? description,
    required int targetAmountInCents,
    DateTime? targetDate,
    String? accountId,
    String? color,
    String? icon,
    GoalType type = GoalType.saving,
  }) {
    return repository.createGoal(
      name: name,
      description: description,
      targetAmountInCents: targetAmountInCents,
      targetDate: targetDate,
      accountId: accountId,
      color: color,
      icon: icon,
      type: type,
    );
  }
}
