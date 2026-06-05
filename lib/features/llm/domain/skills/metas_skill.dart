import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/llm/domain/models/financial_skill.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';

class MetasSkill extends FinancialSkill {
  const MetasSkill();

  @override
  String get id => 'metas';

  @override
  String get displayName => 'Metas e Poupança';

  @override
  IconData get icon => Icons.flag_rounded;

  @override
  List<String> get toolNames => ['GET_GOALS', 'CALCULATE'];

  @override
  Future<String> buildContext(Ref ref) async {
    final health = ref.read(financialHealthScoreProvider);
    final goals = ref.read(goalAchievabilityProvider);

    final buf = StringBuffer();
    final now = DateTime.now();
    buf.writeln(
      'Data: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
    );
    buf.writeln(
      'Taxa de poupança (90 dias): ${(health.savingsRate * 100).toStringAsFixed(1)}%',
    );
    buf.writeln('Saúde financeira: ${health.score}/100 (${health.grade})');

    if (goals.isNotEmpty) {
      buf.writeln('\nResumo das metas:');
      for (final g in goals.take(5)) {
        final pct = (g.progressFraction * 100).toStringAsFixed(0);
        final track = g.isOnTrack ? '✅ no prazo' : '⚠️ atrasada';
        buf.writeln('  - "${g.goalName}": $pct% — $track — ${g.statusMessage}');
      }
    }

    return buf.toString();
  }

  @override
  String systemPrompt(String contextData) => '''
Você é um consultor de metas financeiras pessoais. Responda de forma concisa e direta em português.
Você é um modelo pequeno: siga exemplos literalmente e use uma ferramenta antes de responder sobre metas reais.

FERRAMENTAS DISPONÍVEIS:
[GET_GOALS: {}]
[CALCULATE: 5000 / 12]

EXEMPLOS DE MENSAGENS → PRIMEIRA RESPOSTA CORRETA:
Usuário: "Como estão minhas metas?"
Assistente: [GET_GOALS: {}]

Usuário: "Minha reserva está atrasada?"
Assistente: [GET_GOALS: {}]

Usuário: "Quando vou atingir a meta viagem?"
Assistente: [GET_GOALS: {}]

Usuário: "Quanto preciso guardar para juntar R\$ 10.000 em 8 meses?"
Assistente: [CALCULATE: 10000 / 8]

Usuário: "Se eu poupar 700 por mês por 12 meses, quanto dá?"
Assistente: [CALCULATE: 700 * 12]

EXEMPLO APÓS RESULTADO DA FERRAMENTA:
Resultado: Reserva 42%, atrasada, precisa R\$ 850/mês.
Resposta final: "Sua meta Reserva está em 42% e está atrasada. Para voltar ao prazo, mire cerca de R\$ 850 por mês."

REGRAS:
1. Escreva APENAS a linha da ferramenta, sem texto antes ou depois, até ter o resultado.
2. CALCULATE só aceita números reais. Nunca use nomes, SQL ou variáveis.
3. Use somente as ferramentas listadas acima. Não invente ferramenta.
4. Após receber o resultado da ferramenta, responda ao usuário de forma concisa.

=== DADOS DO USUÁRIO ===
$contextData''';
}
