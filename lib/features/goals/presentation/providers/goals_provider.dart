import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/goals/domain/usecases/create_goal.dart';
import 'package:bestfin/features/goals/domain/usecases/add_contribution.dart';
import 'package:bestfin/features/goals/domain/usecases/calculate_monthly_target.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return GoalRepositoryImpl(database);
});

// ── Streams ─────────────────────────────────────────────────────────────────

final allGoalsProvider = StreamProvider<List<GoalModel>>((ref) {
  return ref.watch(goalRepositoryProvider).watchAllGoals();
});

final activeGoalsProvider = StreamProvider<List<GoalModel>>((ref) {
  return ref.watch(goalRepositoryProvider).watchActiveGoals();
});

final completedGoalsProvider = StreamProvider<List<GoalModel>>((ref) {
  return ref.watch(goalRepositoryProvider).watchCompletedGoals();
});

final goalByIdProvider = StreamProvider.family<GoalModel?, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).watchGoalById(id);
});

// ── Use Cases ───────────────────────────────────────────────────────────────

final createGoalProvider = Provider<CreateGoal>((ref) {
  return CreateGoal(ref.watch(goalRepositoryProvider));
});

final addContributionProvider = Provider<AddContribution>((ref) {
  return AddContribution(ref.watch(goalRepositoryProvider));
});

final calculateMonthlyTargetProvider = Provider<CalculateMonthlyTarget>((ref) {
  return CalculateMonthlyTarget();
});

// ── Action Providers ────────────────────────────────────────────────────────

final archiveGoalProvider = Provider<Future<void> Function(String)>((ref) {
  return (id) => ref.read(goalRepositoryProvider).archiveGoal(id);
});

final deleteGoalProvider = Provider<Future<void> Function(String)>((ref) {
  return (id) => ref.read(goalRepositoryProvider).deleteGoal(id);
});

/// Verifica e reseta goals recorrentes expirados. Chame no app startup.
final resetExpiredGoalsProvider = Provider<Future<void> Function()>((ref) {
  return () => ref.read(goalRepositoryProvider).checkAndResetExpiredGoals();
});
