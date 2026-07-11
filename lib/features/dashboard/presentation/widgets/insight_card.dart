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

  Map<String, dynamic> _getCategoryInfo(InsightCategory? category) {
    switch (category) {
      case InsightCategory.debt:
        return {
          'title': 'Dívidas',
          'icon': Icons.payment,
          'color': Colors.red,
        };
      case InsightCategory.savings:
        return {
          'title': 'Economia',
          'icon': Icons.savings,
          'color': Colors.green,
        };
      case InsightCategory.budget:
        return {
          'title': 'Orçamento',
          'icon': Icons.pie_chart,
          'color': Colors.orange,
        };
      case InsightCategory.cashflow:
        return {
          'title': 'Fluxo',
          'icon': Icons.account_balance,
          'color': Colors.blue,
        };
      case InsightCategory.investment:
        return {
          'title': 'Investimentos',
          'icon': Icons.trending_up,
          'color': Colors.purple,
        };
      case InsightCategory.creditCard:
        return {
          'title': 'Cartão',
          'icon': Icons.credit_card,
          'color': Colors.indigo,
        };
      case InsightCategory.subscription:
        return {
          'title': 'Assinaturas',
          'icon': Icons.notifications,
          'color': Colors.pink,
        };
      case InsightCategory.goal:
        return {
          'title': 'Metas',
          'icon': Icons.flag,
          'color': Colors.amber,
        };
      case InsightCategory.behavior:
        return {
          'title': 'Comportamento',
          'icon': Icons.psychology,
          'color': Colors.teal,
        };
      default:
        return {
          'title': 'Dica',
          'icon': Icons.lightbulb_outline,
          'color': Colors.blue,
        };
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
    final categoryInfo = _getCategoryInfo(topInsight.category);
    final title = categoryInfo['title'] as String;
    final iconData = categoryInfo['icon'] as IconData;
    final categoryColor = categoryInfo['color'] as Color;
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