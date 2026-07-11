import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/gamification/data/repositories/streak_repository_impl.dart';
import 'package:bestfin/features/gamification/domain/repositories/streak_repository.dart';
import 'package:bestfin/features/gamification/domain/services/badge_checker.dart';
import 'package:bestfin/features/gamification/domain/services/gamification_service.dart';
import 'package:bestfin/features/gamification/domain/services/insights_service.dart';
import 'package:bestfin/features/gamification/domain/models/financial_insight.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/investments/presentation/providers/investments_provider.dart';
import 'package:bestfin/features/financing/presentation/providers/financing_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';

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
    accountRepository: ref.watch(accountRepositoryProvider),
    categoryRepository: ref.watch(categoryRepositoryProvider),
    creditCardRepository: ref.watch(creditCardRepositoryProvider),
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
  return InsightsService(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    db: ref.watch(databaseProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    goalRepository: ref.watch(goalRepositoryProvider),
    investmentRepository: ref.watch(investmentRepositoryProvider),
  );
});

final insightsFutureProvider = FutureProvider<List<InsightModel>>((ref) {
  return ref.watch(insightsServiceProvider).generateInsights();
});

final allBadgesStreamProvider = StreamProvider((ref) {
  return ref.watch(badgesDaoProvider).watchAllBadges();
});