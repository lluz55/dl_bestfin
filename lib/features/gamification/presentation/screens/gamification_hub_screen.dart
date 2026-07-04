import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/features/gamification/domain/models/streak.dart';
import 'package:bestfin/features/gamification/domain/models/badge.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:intl/intl.dart';

class GamificationHubScreen extends ConsumerWidget {
  const GamificationHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = context.textTheme;

    final streaksAsync = ref.watch(streaksStreamProvider);
    final badgesAsync = ref.watch(allBadgesStreamProvider);

    return Scaffold(
      appBar: const AppPageAppBar(title: 'Conquistas e Sequências'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Suas Sequências',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          streaksAsync.when(
            data: (streaks) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: streaks.map((s) => _StreakCard(streak: s)).toList(),
            ),
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (e, s) => Text('Erro ao carregar sequências: $e'),
          ),
          const SizedBox(height: 32),
          Text(
            'Medalhas',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          badgesAsync.when(
            data: (badges) => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: badges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final badge = BadgeModel.fromDb(badges[index]);
                return _BadgeTile(badge: badge);
              },
            ),
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (e, s) => Text('Erro ao carregar medalhas: $e'),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final StreakModel streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            streak.type == StreakType.recording
                ? Icons.local_fire_department
                : Icons.account_balance_wallet,
            color: streak.isActive ? Colors.orange : cs.outline,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            streak.currentCount.toString(),
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: streak.isActive ? cs.primary : cs.outline,
            ),
          ),
          Text(
            streak.type.label,
            style: tt.labelSmall,
            textAlign: TextAlign.center,
          ),
          if (streak.longestCount > streak.currentCount)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Recorde: ${streak.longestCount}',
                style: tt.bodySmall?.copyWith(fontSize: 10, color: cs.outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeModel badge;

  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: badge.isUnlocked
                  ? cs.primaryContainer
                  : cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getBadgeIcon(badge.badgeKey),
              color: badge.isUnlocked ? cs.onPrimaryContainer : cs.outline,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: badge.isUnlocked ? cs.onSurface : cs.outline,
                  ),
                ),
                Text(
                  badge.description,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                if (badge.isUnlocked && badge.unlockedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Conquistada em: ${DateFormat('dd/MM/yyyy').format(badge.unlockedAt!)}',
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (badge.isUnlocked)
            Icon(Icons.check_circle, color: cs.primary, size: 20),
        ],
      ),
    );
  }

  IconData _getBadgeIcon(String key) {
    switch (key) {
      case 'first_transaction':
        return Icons.star;
      case 'seven_days_streak':
        return Icons.trending_up;
      case 'emergency_fund':
        return Icons.emergency;
      case 'debt_free':
        return Icons.verified_user;
      case 'goal_reached':
        return Icons.emoji_events;
      case 'finance_master':
        return Icons.workspace_premium;
      case 'investor':
        return Icons.show_chart;
      case 'installment_completed':
        return Icons.task_alt;
      default:
        return Icons.help_outline;
    }
  }
}
