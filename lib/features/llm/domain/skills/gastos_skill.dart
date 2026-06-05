import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/features/llm/domain/models/financial_skill.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';

class GastosSkill extends FinancialSkill {
  const GastosSkill();

  @override
  String get id => 'gastos';

  @override
  String get displayName => 'Análise de Gastos';

  @override
  IconData get icon => Icons.bar_chart_rounded;

  @override
  List<String> get toolNames => ['GET_SPENDING_SUMMARY', 'CALCULATE'];

  @override
  Future<String> buildContext(Ref ref) async {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    String brl(int cents) => 'R\$ ${fmt.format(cents / 100)}';

    final balance = ref.read(totalBalanceProvider);
    final trends = ref.read(spendingTrendsProvider);
    final anomalies = ref.read(anomalyDetectionProvider);

    final buf = StringBuffer();
    buf.writeln('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    buf.writeln('Saldo atual: ${brl(balance)}');

    if (trends.isNotEmpty) {
      buf.writeln('\nTendências (mês atual vs anterior):');
      for (final t in trends.take(6)) {
        final s = t.trend == 'increasing'
            ? '↑'
            : t.trend == 'decreasing'
            ? '↓'
            : '→';
        buf.writeln(
          '  $s ${t.categoryName}: ${t.percentChange.toStringAsFixed(1)}%',
        );
      }
    }

    if (anomalies.isNotEmpty) {
      buf.writeln('\nGastos anômalos detectados:');
      for (final a in anomalies.take(3)) {
        buf.writeln('  - ${a.title}: ${a.description}');
      }
    }

    return buf.toString();
  }

  @override
  String systemPrompt(String contextData) => '''
Você é um analista de gastos pessoais. Responda de forma concisa e direta em português.
Você é um modelo pequeno: siga exemplos literalmente e use uma ferramenta antes de responder sobre dados do usuário.

FERRAMENTAS DISPONÍVEIS:
[GET_SPENDING_SUMMARY: {}]
[GET_SPENDING_SUMMARY: {"start_date": "2026-06-01", "end_date": "2026-06-30"}]
[CALCULATE: 1500 + 200]

EXEMPLOS DE MENSAGENS → PRIMEIRA RESPOSTA CORRETA:
Usuário: "Quanto gastei esse mês?"
Assistente: [GET_SPENDING_SUMMARY: {}]

Usuário: "Me mostre gastos de junho"
Assistente: [GET_SPENDING_SUMMARY: {"start_date": "2026-06-01", "end_date": "2026-06-30"}]

Usuário: "Compare maio e junho"
Assistente: [GET_SPENDING_SUMMARY: {"start_date": "2026-05-01", "end_date": "2026-05-31"}]

Usuário: "Que percentual foi alimentação?"
Assistente: [GET_SPENDING_SUMMARY: {}]

Usuário: "Some 120,50 com 79,90"
Assistente: [CALCULATE: 120.50 + 79.90]

EXEMPLO APÓS RESULTADO DA FERRAMENTA:
Resultado: Alimentação R\$ 900; Transporte R\$ 300; Total R\$ 1500
Resposta final: "Você gastou R\$ 1.500 no período. Alimentação foi o maior grupo, com R\$ 900 (60% do total)."

REGRAS:
1. Escreva APENAS a linha da ferramenta, sem texto antes ou depois, até ter o resultado.
2. CALCULATE só aceita números reais (ex: [CALCULATE: 350 + 120]). Nunca use nomes, SQL ou datas.
3. Use somente as ferramentas listadas acima. Não invente ferramenta.
4. Após receber o resultado da ferramenta, responda ao usuário de forma concisa.

=== DADOS DO USUÁRIO ===
$contextData''';
}
