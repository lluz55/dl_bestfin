import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/features/ai/domain/services/insight_nlg_service.dart';

void main() {
  setUp(() => CurrencyFormatter.valuesHidden = false);

  group('InsightNlgService.periodInsights', () {
    test('gera 3 insights quando há dados completos', () {
      final insights = InsightNlgService.periodInsights(
        balanceCents: 250000,
        savingsRate: 0.25,
        cashFlowAlert: null,
        topCategoryName: 'Alimentação',
        topCategoryCents: 80000,
        topCategoryPctChange: 15,
        primaryRecommendation: 'Mantenha o ritmo de poupança.',
      );

      expect(insights, hasLength(3));
      expect(insights[0], contains('💰'));
      expect(insights[0], contains('25%'));
      expect(insights[1], contains('📈'));
      expect(insights[1], contains('Alimentação'));
      expect(insights[1], contains('15%'));
      expect(insights[2], startsWith('💡'));
    });

    test('alerta de fluxo de caixa tem prioridade sobre o saldo', () {
      final insights = InsightNlgService.periodInsights(
        balanceCents: 100000,
        savingsRate: 0.30,
        cashFlowAlert: 'Saldo ficará negativo em 12 dias.',
        topCategoryName: '',
        topCategoryCents: 0,
        topCategoryPctChange: 0,
        primaryRecommendation: '',
      );

      expect(insights, hasLength(1));
      expect(insights.first, contains('⚠️'));
      expect(insights.first, contains('negativo em 12 dias'));
    });

    test('saldo negativo de poupança usa o template de alerta vermelho', () {
      final insights = InsightNlgService.periodInsights(
        balanceCents: -5000,
        savingsRate: -0.10,
        cashFlowAlert: null,
        topCategoryName: '',
        topCategoryCents: 0,
        topCategoryPctChange: 0,
        primaryRecommendation: '',
      );

      expect(insights, hasLength(1));
      expect(insights.first, contains('🔴'));
    });

    test('omite o insight de maior gasto quando não há categoria', () {
      final insights = InsightNlgService.periodInsights(
        balanceCents: 100000,
        savingsRate: 0.05,
        cashFlowAlert: null,
        topCategoryName: '',
        topCategoryCents: 0,
        topCategoryPctChange: 0,
        primaryRecommendation: 'Tente poupar mais.',
      );

      expect(insights, hasLength(2));
      expect(insights.any((i) => i.contains('maior gasto')), isFalse);
    });

    test('gasto em queda usa o template positivo', () {
      final insights = InsightNlgService.periodInsights(
        balanceCents: 100000,
        savingsRate: 0.15,
        cashFlowAlert: null,
        topCategoryName: 'Lazer',
        topCategoryCents: 30000,
        topCategoryPctChange: -22,
        primaryRecommendation: '',
      );

      final spending = insights.firstWhere((i) => i.contains('Lazer'));
      expect(spending, contains('📉'));
      expect(spending, contains('22%'));
      expect(spending, contains('Bom trabalho'));
    });

    test('respeita o modo privacidade mascarando valores', () {
      CurrencyFormatter.valuesHidden = true;
      final insights = InsightNlgService.periodInsights(
        balanceCents: 250000,
        savingsRate: 0.25,
        cashFlowAlert: null,
        topCategoryName: 'Alimentação',
        topCategoryCents: 80000,
        topCategoryPctChange: 15,
        primaryRecommendation: '',
      );

      expect(insights[0], contains('•••••'));
      expect(insights[0], isNot(contains('2.500,00')));
    });
  });
}
