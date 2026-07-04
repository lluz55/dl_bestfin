import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';

class InsightCard extends ConsumerWidget {
  const InsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final gamificationInsightsAsync = ref.watch(insightsFutureProvider);
    final gInsights = gamificationInsightsAsync.value ?? [];

    if (gInsights.isEmpty) {
      return const SizedBox.shrink();
    }

    final topInsight = gInsights.first;
    final title = 'Dica Financeira';
    final message = topInsight.text;
    final iconEmoji = topInsight.icon;
    const icon = Icons.tips_and_updates_outlined;
    const iconColor = Colors.blue;
    final bgIconColor = Colors.blue.withValues(alpha: 0.1);
    const badgeText = 'Dica';

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      onTap: () => context.push('/gamification'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: cs.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'INSIGHT',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bgIconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: bgIconColor,
                child: iconEmoji.isNotEmpty
                    ? Text(iconEmoji, style: const TextStyle(fontSize: 20))
                    : const Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.sanitizeText(title),
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.sanitizeText(message),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
