import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/router/app_router.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/gamification/domain/models/badge.dart';

// A better way is to have a provider for the unlock events
final badgeUnlockEventProvider = StreamProvider<String>((ref) {
  return ref.watch(gamificationServiceProvider).onBadgeUnlocked;
});

class BadgeUnlockOverlay extends ConsumerWidget {
  final Widget child;

  const BadgeUnlockOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<String>>(badgeUnlockEventProvider, (previous, next) {
      next.whenData((badgeKey) {
        unawaited(_showUnlockDialog(ref, badgeKey));
      });
    });

    return child;
  }

  Future<void> _showUnlockDialog(WidgetRef ref, String badgeKey) async {
    final badges = await ref.read(badgesDaoProvider).getAllBadges();
    final badgeDb = badges.firstWhere((b) => b.badgeKey == badgeKey);
    final badge = BadgeModel.fromDb(badgeDb);

    final navContext = ref.read(navigatorKeyProvider).currentContext;
    if (navContext == null || !navContext.mounted) return;

    unawaited(
      showDialog(
        context: navContext,
        barrierDismissible: true,
        builder: (context) => _UnlockDialog(badge: badge),
      ),
    );
  }
}

class _UnlockDialog extends StatelessWidget {
  final BadgeModel badge;

  const _UnlockDialog({required this.badge});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉 Nova Conquista!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getBadgeIcon(badge.badgeKey),
                color: cs.onPrimaryContainer,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Incrível!'),
            ),
          ],
        ),
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
