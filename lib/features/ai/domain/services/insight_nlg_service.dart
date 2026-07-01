import 'package:bestfin/core/utils/currency_formatter.dart';

/// NLG baseada em templates: gera os mesmos 3 insights do período que o LLM
/// produziria (fluxo de caixa, maior gasto e sugestão acionável), porém de
/// forma determinística e sem nenhum modelo carregado.
///
/// Recebe apenas primitivos já computados pelos providers algorítmicos
/// (`ai_provider.dart`) para manter a camada de domínio desacoplada da de
/// apresentação, seguindo o mesmo padrão de [NaiveBayesClassifier].
class InsightNlgService {
  /// Monta até 3 frases de insight. Cada slot só é preenchido quando há dado
  /// suficiente, então a lista pode ter menos de 3 itens (degradação graciosa).
  ///
  /// Os valores monetários passam por [CurrencyFormatter.formatCents], que já
  /// respeita o modo privacidade (mascara com `•••••` quando ativo).
  static List<String> periodInsights({
    required int balanceCents,
    required double savingsRate,
    String? cashFlowAlert,
    required String topCategoryName,
    required int topCategoryCents,
    required double topCategoryPctChange,
    required String primaryRecommendation,
  }) {
    final insights = <String>[];

    // 1. Fluxo de caixa / saldo — alerta de projeção tem prioridade.
    if (cashFlowAlert != null && cashFlowAlert.isNotEmpty) {
      insights.add('⚠️ $cashFlowAlert');
    } else {
      final pct = (savingsRate * 100).toStringAsFixed(0);
      final saldo = CurrencyFormatter.formatCents(balanceCents);
      if (savingsRate >= 0.20) {
        insights.add(
          '💰 Ótimo controle: você poupou $pct% da renda nos últimos 90 dias. Saldo atual de $saldo.',
        );
      } else if (savingsRate >= 0.10) {
        insights.add(
          '📊 Saldo atual de $saldo. Taxa de poupança de $pct% — bom ritmo, tente chegar a 20%.',
        );
      } else if (savingsRate >= 0) {
        insights.add(
          '📊 Saldo atual de $saldo. Poupança de apenas $pct% no período — há espaço para economizar mais.',
        );
      } else {
        insights.add(
          '🔴 Atenção: suas despesas superaram a renda (poupança de $pct%) nos últimos 90 dias.',
        );
      }
    }

    // 2. Maior gasto do mês com a variação em relação ao mês anterior.
    if (topCategoryName.isNotEmpty && topCategoryCents > 0) {
      final valor = CurrencyFormatter.formatCents(topCategoryCents);
      if (topCategoryPctChange.abs() < 10) {
        insights.add(
          '📌 Seu maior gasto do mês foi $topCategoryName: $valor, estável em relação ao mês anterior.',
        );
      } else if (topCategoryPctChange > 0) {
        final p = topCategoryPctChange.toStringAsFixed(0);
        insights.add(
          '📈 Seu maior gasto do mês foi $topCategoryName: $valor, $p% acima do mês anterior.',
        );
      } else {
        final p = topCategoryPctChange.abs().toStringAsFixed(0);
        insights.add(
          '📉 Seu maior gasto do mês foi $topCategoryName: $valor, $p% abaixo do mês anterior. Bom trabalho!',
        );
      }
    }

    // 3. Sugestão acionável — reaproveita a recomendação do score de saúde.
    if (primaryRecommendation.isNotEmpty) {
      insights.add('💡 $primaryRecommendation');
    }

    return insights;
  }
}
