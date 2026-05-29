import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/core/widgets/category_icon.dart';

class AiDashboardScreen extends ConsumerStatefulWidget {
  const AiDashboardScreen({super.key});

  @override
  ConsumerState<AiDashboardScreen> createState() => _AiDashboardScreenState();
}

class _AiDashboardScreenState extends ConsumerState<AiDashboardScreen> {
  int _forecastDays = 30; // 30, 60, or 90 days

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    final forecast = ref.watch(cashFlowForecastingProvider);
    final anomalies = ref.watch(anomalyDetectionProvider);
    final sentiments = ref.watch(sentimentCorrelationProvider);
    final healthScore = ref.watch(financialHealthScoreProvider);
    final trends = ref.watch(spendingTrendsProvider);
    final goalForecasts = ref.watch(goalAchievabilityProvider);
    final budgetRecs = ref.watch(budgetRecommendationsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Painel de IA',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOcrBanner(context),
              const SizedBox(height: 20),

              _buildHealthScoreCard(context, healthScore),
              const SizedBox(height: 20),

              _buildForecastCard(context, forecast),
              const SizedBox(height: 20),

              _buildSpendingTrendsCard(context, trends),
              const SizedBox(height: 20),

              if (goalForecasts.isNotEmpty) ...[
                _buildGoalForecastCard(context, goalForecasts),
                const SizedBox(height: 20),
              ],

              if (budgetRecs.isNotEmpty) ...[
                _buildBudgetRecommendationsCard(context, budgetRecs),
                const SizedBox(height: 20),
              ],

              _buildAnomaliesCard(context, anomalies),
              const SizedBox(height: 20),

              _buildSentimentCard(context, sentiments),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOcrBanner(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.primary.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/ai/scan'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NOVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Escanear Comprovante com IA',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Extraia valores, data e sugira categorias de recibos automaticamente em segundos.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.document_scanner,
                    color: cs.primary,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForecastCard(BuildContext context, AiForecastReport report) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    // Filter points based on selected days
    final filteredPoints = report.points.take(_forecastDays + 1).toList();

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREVISÃO DE FLUXO DE CAIXA',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Projeção Inteligente',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: _forecastDays,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _forecastDays = val;
                      });
                    }
                  },
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 Dias')),
                    DropdownMenuItem(value: 60, child: Text('60 Dias')),
                    DropdownMenuItem(value: 90, child: Text('90 Dias')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cashflow Line Chart Widget
            _buildLineChart(context, filteredPoints),
            const SizedBox(height: 16),

            // Projected balances summary
            Row(
              children: [
                Expanded(
                  child: _buildBalanceProjectionCol(
                    context,
                    'Projeção 30 Dias',
                    report.projectedBalance30Days,
                  ),
                ),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                Expanded(
                  child: _buildBalanceProjectionCol(
                    context,
                    'Projeção 90 Dias',
                    report.projectedBalance90Days,
                  ),
                ),
              ],
            ),

            if (report.alertMessage != null &&
                report.daysUntilNegative != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.error.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: cs.error,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        report.alertMessage!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceProjectionCol(
    BuildContext context,
    String label,
    int amountInCents,
  ) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final isNegative = amountInCents < 0;

    return Column(
      children: [
        Text(
          label,
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'R\$ ${(amountInCents / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isNegative ? cs.error : cs.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, List<ForecastPoint> points) {
    final cs = context.colorScheme;

    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Sem pontos suficientes')),
      );
    }

    final double minVal = points
        .map((p) => p.balance.toDouble())
        .reduce((a, b) => a < b ? a : b);
    final double maxVal = points
        .map((p) => p.balance.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final double padding = ((maxVal - minVal) * 0.15).abs().clamp(
      2000.0,
      double.infinity,
    );

    final spots = List.generate(points.length, (i) {
      return FlSpot(i.toDouble(), points[i].balance.toDouble());
    });

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minVal - padding,
          maxY: maxVal + padding,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final idx = s.x.toInt();
                if (idx >= points.length) return null;
                final p = points[idx];
                final dateFormatted =
                    '${p.date.day.toString().padLeft(2, '0')}/${p.date.month.toString().padLeft(2, '0')}';
                return LineTooltipItem(
                  '$dateFormatted\nR\$ ${(p.balance / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
                  TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) return const SizedBox();
                  // Show monthly transition days or start/mid/end days to keep it clean
                  final p = points[idx];
                  if (idx == 0 ||
                      idx == (points.length ~/ 2) ||
                      idx == points.length - 1) {
                    final dateFormatted =
                        '${p.date.day.toString().padLeft(2, '0')}/${p.date.month.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dateFormatted,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 22,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: cs.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withValues(alpha: 0.25),
                    cs.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesCard(BuildContext context, List<AiAnomaly> anomalies) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DETECÇÃO DE ANOMALIAS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gastos Fora do Padrão',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (anomalies.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green.withValues(alpha: 0.7),
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhum gasto anômalo detectado recentemente.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: anomalies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final item = anomalies[idx];
                  final tx = item.transaction;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.error.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.trending_up,
                            color: cs.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: cs.error,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.error,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item.severity.toStringAsFixed(1)}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    tx.description,
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•',
                                    style: TextStyle(color: cs.outlineVariant),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentCard(
    BuildContext context,
    AiSentimentCorrelation report,
  ) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CORRELAÇÃO EMOCIONAL',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sentimentos e Gastos',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Sentiment Distribution Donut
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: PieChart(
                      PieChartData(
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: 28,
                        sections: [
                          PieChartSectionData(
                            color: Colors.green,
                            value: report.positivePercentage,
                            title:
                                '${(report.positivePercentage * 100).toStringAsFixed(0)}%',
                            radius: 20,
                            titleStyle: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.amber,
                            value: report.neutralPercentage,
                            title:
                                '${(report.neutralPercentage * 100).toStringAsFixed(0)}%',
                            radius: 20,
                            titleStyle: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: cs.error,
                            value: report.negativePercentage,
                            title:
                                '${(report.negativePercentage * 100).toStringAsFixed(0)}%',
                            radius: 20,
                            titleStyle: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSentimentLegendRow(
                        context,
                        'Bem-estar',
                        Colors.green,
                        report.positivePercentage,
                      ),
                      const SizedBox(height: 8),
                      _buildSentimentLegendRow(
                        context,
                        'Neutro',
                        Colors.amber,
                        report.neutralPercentage,
                      ),
                      const SizedBox(height: 8),
                      _buildSentimentLegendRow(
                        context,
                        'Impulsivo/Arrependido',
                        cs.error,
                        report.negativePercentage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Insights Title
            Text(
              'Insights e Recomendações',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (report.psychologicalInsights.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Continue cadastrando transações e classificando seus sentimentos para liberar insights comportamentais avançados.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: report.psychologicalInsights.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final insight = report.psychologicalInsights[idx];

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            insight,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentLegendRow(
    BuildContext context,
    String label,
    Color color,
    double ratio,
  ) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${(ratio * 100).toStringAsFixed(0)}%',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _gradeColor(ColorScheme cs, String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return const Color(0xFF66BB6A);
      case 'C':
        return Colors.amber;
      case 'D':
        return Colors.orange;
      default:
        return cs.error;
    }
  }

  Widget _buildHealthScoreCard(BuildContext context, AiHealthScore health) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final gradeColor = _gradeColor(cs, health.grade);

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SAÚDE FINANCEIRA',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Score Inteligente',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: gradeColor.withValues(alpha: 0.1),
                    border: Border.all(color: gradeColor, width: 3),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          health.score.toString(),
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: gradeColor,
                          ),
                        ),
                        Text(
                          health.grade,
                          style: tt.labelMedium?.copyWith(
                            color: gradeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxa de Poupança',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${(health.savingsRate * 100).toStringAsFixed(1)}%',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: health.savingsRate >= 0 ? cs.primary : cs.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: health.savingsRate.clamp(0.0, 1.0),
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            health.savingsRate >= 0.20
                                ? Colors.green
                                : health.savingsRate >= 0.10
                                    ? Colors.amber
                                    : cs.error,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: gradeColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: gradeColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      health.primaryRecommendation,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (health.tips.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...health.tips.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingTrendsCard(
    BuildContext context,
    List<AiSpendingTrend> trends,
  ) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TENDÊNCIAS DE GASTOS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mês a Mês por Categoria',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (trends.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.trending_flat_rounded,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dados de 2 meses necessários para detectar tendências.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trends.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final trend = trends[idx];
                  final isIncreasing = trend.trend == 'increasing';
                  final isDecreasing = trend.trend == 'decreasing';
                  final trendColor = isIncreasing
                      ? cs.error
                      : isDecreasing
                          ? Colors.green
                          : cs.onSurfaceVariant;
                  final trendIcon = isIncreasing
                      ? Icons.trending_up_rounded
                      : isDecreasing
                          ? Icons.trending_down_rounded
                          : Icons.trending_flat_rounded;

                  return Row(
                    children: [
                      CategoryIcon(
                        icon: trend.categoryIcon,
                        color: trend.categoryColor,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trend.categoryName,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'R\$ ${(trend.currentMonthTotal / 100).toStringAsFixed(0)} este mês  •  R\$ ${(trend.previousMonthTotal / 100).toStringAsFixed(0)} mês passado',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(trendIcon, color: trendColor, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${trend.percentChange.abs().toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalForecastCard(
    BuildContext context,
    List<AiGoalForecast> forecasts,
  ) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PREVISÃO DE METAS',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Atingibilidade dos Objetivos',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: forecasts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, idx) {
                final f = forecasts[idx];
                final progressColor =
                    f.isOnTrack ? Colors.green : cs.primary;
                final goalColor = f.goalColor != null
                    ? CategoryIcon.hexToColor(f.goalColor!)
                    : cs.primary;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: goalColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f.goalName,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          f.isOnTrack
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          color: f.isOnTrack ? Colors.green : Colors.orange,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: f.progressFraction.clamp(0.0, 1.0),
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(f.progressFraction * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%',
                          style: tt.labelSmall?.copyWith(
                            color: progressColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            f.statusMessage,
                            style: tt.labelSmall?.copyWith(
                              color: f.isOnTrack ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetRecommendationsCard(
    BuildContext context,
    List<AiBudgetRecommendation> recs,
  ) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ORÇAMENTO SUGERIDO',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Limites Inteligentes por IA',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, idx) {
                final rec = recs[idx];
                final barRatio = (rec.suggestedBudget / rec.avgMonthlySpend)
                    .clamp(0.0, 1.0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CategoryIcon(
                          icon: rec.categoryIcon,
                          color: rec.categoryColor,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.categoryName,
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'R\$ ${(rec.avgMonthlySpend / 100).toStringAsFixed(0)}',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    ' → ',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'R\$ ${(rec.suggestedBudget / 100).toStringAsFixed(0)}',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 6,
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: cs.error.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Container(
                              height: 6,
                              width: constraints.maxWidth * barRatio,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rec.reasoning,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
