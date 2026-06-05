import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/features/llm/domain/models/financial_skill.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';

class FluxoSkill extends FinancialSkill {
  const FluxoSkill();

  @override
  String get id => 'fluxo';

  @override
  String get displayName => 'Fluxo de Caixa';

  @override
  IconData get icon => Icons.show_chart_rounded;

  @override
  List<String> get toolNames => ['GET_RECURRING', 'CALCULATE'];

  @override
  Future<String> buildContext(Ref ref) async {
    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    String brl(int cents) => 'R\$ ${fmt.format(cents / 100)}';

    final balance = ref.read(totalBalanceProvider);
    final forecast = ref.read(cashFlowForecastingProvider);

    final buf = StringBuffer();
    buf.writeln('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    buf.writeln('Saldo atual: ${brl(balance)}');
    buf.writeln('Projeção 30 dias: ${brl(forecast.projectedBalance30Days)}');
    buf.writeln('Projeção 90 dias: ${brl(forecast.projectedBalance90Days)}');
    if (forecast.alertMessage != null) {
      buf.writeln('⚠️ Alerta: ${forecast.alertMessage}');
    }

    return buf.toString();
  }

  @override
  String systemPrompt(String contextData) => '''
Você é um analista de fluxo de caixa pessoal. Responda de forma concisa e direta em português.
Você é um modelo pequeno: siga exemplos literalmente e use uma ferramenta antes de responder sobre recorrências.

FERRAMENTAS DISPONÍVEIS:
[GET_RECURRING: {}]
[CALCULATE: 3400 - 1200 - 450]

EXEMPLOS DE MENSAGENS → PRIMEIRA RESPOSTA CORRETA:
Usuário: "Quais contas vencem essa semana?"
Assistente: [GET_RECURRING: {}]

Usuário: "Qual meu gasto fixo mensal?"
Assistente: [GET_RECURRING: {}]

Usuário: "Terei dinheiro no fim do mês?"
Assistente: [GET_RECURRING: {}]

Usuário: "Meu saldo menos aluguel de 1200 e internet de 100 dá quanto?"
Assistente: [CALCULATE: 3400 - 1200 - 100]

Usuário: "Quanto sobra depois de contas fixas de 1800?"
Assistente: [CALCULATE: 3400 - 1800]

EXEMPLO APÓS RESULTADO DA FERRAMENTA:
Resultado: Netflix R\$ 39,90 dia 05; Aluguel R\$ 1200 dia 10; Salário R\$ 4200 dia 30.
Resposta final: "Você tem R\$ 1.239,90 em despesas recorrentes mapeadas. O maior compromisso é o aluguel no dia 10."

REGRAS:
1. Escreva APENAS a linha da ferramenta, sem texto antes ou depois, até ter o resultado.
2. CALCULATE só aceita números reais. Nunca use nomes, SQL ou variáveis.
3. Use somente as ferramentas listadas acima. Não invente ferramenta.
4. Após receber o resultado da ferramenta, responda ao usuário de forma concisa.

=== DADOS DO USUÁRIO ===
$contextData''';
}
