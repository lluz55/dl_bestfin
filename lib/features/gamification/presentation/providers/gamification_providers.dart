import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/repositories/streak_repository_impl.dart';
import '../../domain/repositories/streak_repository.dart';
import '../../domain/services/badge_checker.dart';
import '../../domain/services/gamification_service.dart';
import '../../domain/services/insights_service.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../investments/presentation/providers/investments_provider.dart';
import '../../../financing/presentation/providers/financing_provider.dart';

final streaksDaoProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return db.streaksDao;
});

final badgesDaoProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return db.badgesDao;
});

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  return StreakRepositoryImpl(ref.watch(streaksDaoProvider));
});

final streaksStreamProvider = StreamProvider((ref) {
  return ref.watch(streakRepositoryProvider).watchAllStreaks();
});

final badgeCheckerProvider = Provider<BadgeChecker>((ref) {
  return BadgeChecker(
    badgesDao: ref.watch(badgesDaoProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    goalRepository: ref.watch(goalRepositoryProvider),
    investmentRepository: ref.watch(investmentRepositoryProvider),
    financingRepository: ref.watch(financingRepositoryProvider),
    streakRepository: ref.watch(streakRepositoryProvider),
  );
});

final gamificationServiceProvider = Provider<GamificationService>((ref) {
  return GamificationService(
    streakRepository: ref.watch(streakRepositoryProvider),
    badgeChecker: ref.watch(badgeCheckerProvider),
  );
});

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService(ref.watch(transactionRepositoryProvider));
});

final insightsFutureProvider = FutureProvider<List<InsightModel>>((ref) {
  return ref.watch(insightsServiceProvider).generateInsights();
});

final allBadgesStreamProvider = StreamProvider((ref) {
  return ref.watch(badgesDaoProvider).watchAllBadges();
});
