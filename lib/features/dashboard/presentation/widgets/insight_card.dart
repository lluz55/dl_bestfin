import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/gamification/domain/models/financial_insight.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';

class InsightCard extends ConsumerWidget {
  const InsightCard({super.key});

  Color _categoryColor(InsightCategory? category, ColorScheme cs) {
    switch (category) {
      case InsightCategory.debt:
        return cs.error;
      case InsightCategory.savings:
        return cs.primary;
      case InsightCategory.budget:
        return cs.tertiary;
      case InsightCategory.cashflow:
        return cs.secondary;
      case InsightCategory.investment:
        return cs.primary;
      case InsightCategory.creditCard:
        return cs.tertiary;
      case InsightCategory.subscription:
        return cs.secondary;
      case InsightCategory.goal:
        return cs.primary;
      case InsightCategory.behavior:
        return cs.secondary;
      default:
        return cs.primary;
    }
  }

  String _categoryTitle(InsightCategory? category) {
    switch (category) {
      case InsightCategory.debt:
        return 'Dívidas';
      case InsightCategory.savings:
        return 'Economia';
      case InsightCategory.budget:
        return 'Orçamento';
      case InsightCategory.cashflow:
        return 'Fluxo';
      case InsightCategory.investment:
        return 'Investimentos';
      case InsightCategory.creditCard:
        return 'Cartão';
      case InsightCategory.subscription:
        return 'Assinaturas';
      case InsightCategory.goal:
        return 'Metas';
      case InsightCategory.behavior:
        return 'Comportamento';
      default:
        return 'Dica';
    }
  }

  IconData _categoryIcon(InsightCategory? category) {
    switch (category) {
      case InsightCategory.debt:
        return Icons.payment;
      case InsightCategory.savings:
        return Icons.savings;
      case InsightCategory.budget:
        return Icons.pie_chart;
      case InsightCategory.cashflow:
        return Icons.account_balance;
      case InsightCategory.investment:
        return Icons.trending_up;
      case InsightCategory.creditCard:
        return Icons.credit_card;
      case InsightCategory.subscription:
        return Icons.notifications;
      case InsightCategory.goal:
        return Icons.flag;
      case InsightCategory.behavior:
        return Icons.psychology;
      default:
        return Icons.lightbulb_outline;
    }
  }

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
    final title = _categoryTitle(topInsight.category);
    final iconData = _categoryIcon(topInsight.category);
    final categoryColor = _categoryColor(topInsight.category, cs);
    final message = topInsight.text;
    final iconEmoji = topInsight.icon;
    final bgIconColor = categoryColor.withValues(alpha: 0.1);

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
                    iconData,
                    color: categoryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title.toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      color: categoryColor,
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
                  'Dica',
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
                    : Icon(iconData, color: categoryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.sanitizeText(message),
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
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