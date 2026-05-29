import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';

class InsightCard extends ConsumerWidget {
  const InsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    // Watch providers
    final forecast = ref.watch(cashFlowForecastingProvider);
    final anomalies = ref.watch(anomalyDetectionProvider);
    final sentiments = ref.watch(sentimentCorrelationProvider);
    final gamificationInsightsAsync = ref.watch(insightsFutureProvider);

    // Resolve which insight to display
    String title = 'Central de IA';
    String message =
        'Monitore suas tendências de gastos futuros, sentimentos e anomalias de fluxo de caixa.';
    IconData icon = Icons.psychology_outlined;
    String iconEmoji = '';
    Color iconColor = cs.primary;
    Color bgIconColor = cs.primaryContainer;
    String badgeText = 'IA Ativa';

    if (forecast.alertMessage != null && forecast.daysUntilNegative != null) {
      title = 'Alerta de Fluxo de Caixa';
      message = forecast.alertMessage!;
      icon = Icons.warning_amber_rounded;
      iconColor = cs.error;
      bgIconColor = cs.errorContainer.withValues(alpha: 0.3);
      badgeText = 'Crítico';
    } else if (anomalies.isNotEmpty) {
      final topAnomaly = anomalies.first;
      title = topAnomaly.title;
      message = topAnomaly.description;
      icon = Icons.trending_up_rounded;
      iconColor = cs.error;
      bgIconColor = cs.errorContainer.withValues(alpha: 0.3);
      badgeText = 'Atenção';
    } else if (sentiments.psychologicalInsights.isNotEmpty) {
      title = 'Insight de Sentimento';
      message = sentiments.psychologicalInsights.first;
      icon = Icons.lightbulb_outline_rounded;
      iconColor = Colors.amber;
      bgIconColor = Colors.amber.withValues(alpha: 0.15);
      badgeText = 'Psicológico';
    } else {
      // Try gamification insights
      final gInsights = gamificationInsightsAsync.value ?? [];
      if (gInsights.isNotEmpty) {
        final topG = gInsights.first;
        title = 'Dica Financeira';
        message = topG.text;
        iconEmoji = topG.icon;
        icon = Icons.tips_and_updates_outlined;
        iconColor = Colors.blue;
        bgIconColor = Colors.blue.withValues(alpha: 0.1);
        badgeText = 'Dica';
      }
    }

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      onTap: () => context.push('/ai'),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: cs.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'INSIGHT DA IA',
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bgIconColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: tt.labelSmall?.copyWith(
                        color: iconColor == cs.error
                            ? cs.onErrorContainer
                            : cs.onSurface,
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
                        : Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
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
