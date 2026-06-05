import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/llm/data/services/llm_service.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';

const _kRouterPrompt = '''
Você é um roteador financeiro. Sua tarefa é escolher UMA skill.
Responda com EXATAMENTE um token no formato [ROUTE: nome].
Não explique. Não use markdown. Não escreva pontuação extra.

Opções de classificação:
[ROUTE: gastos]       - análise de gastos, categorias, comparações de período, anomalias
  exemplos:
  Pergunta: "quanto gastei em restaurantes?" Resposta: [ROUTE: gastos]
  Pergunta: "meus gastos aumentaram esse mês?" Resposta: [ROUTE: gastos]
  Pergunta: "qual foi minha maior categoria de despesa?" Resposta: [ROUTE: gastos]
  Pergunta: "tem algum gasto estranho?" Resposta: [ROUTE: gastos]

[ROUTE: metas]        - metas de poupança, progresso, projeções de atingimento
  exemplos:
  Pergunta: "como está minha meta da reserva?" Resposta: [ROUTE: metas]
  Pergunta: "quando vou atingir minha meta?" Resposta: [ROUTE: metas]
  Pergunta: "quanto preciso poupar por mês?" Resposta: [ROUTE: metas]
  Pergunta: "minhas metas estão atrasadas?" Resposta: [ROUTE: metas]

[ROUTE: fluxo]        - saldo futuro, recorrências, contas a pagar, projeções
  exemplos:
  Pergunta: "terei dinheiro no fim do mês?" Resposta: [ROUTE: fluxo]
  Pergunta: "quais contas vencem essa semana?" Resposta: [ROUTE: fluxo]
  Pergunta: "qual meu gasto fixo mensal?" Resposta: [ROUTE: fluxo]
  Pergunta: "meu saldo vai ficar negativo?" Resposta: [ROUTE: fluxo]

[ROUTE: busca]        - encontrar transações específicas por data, descrição ou categoria
  exemplos:
  Pergunta: "onde usei o Netflix?" Resposta: [ROUTE: busca]
  Pergunta: "mostre compras acima de R\$ 200" Resposta: [ROUTE: busca]
  Pergunta: "transações de maio" Resposta: [ROUTE: busca]
  Pergunta: "procure iFood" Resposta: [ROUTE: busca]

[ROUTE: fora_escopo]  - qualquer assunto não relacionado a finanças pessoais
  exemplos:
  Pergunta: "qual a capital da França?" Resposta: [ROUTE: fora_escopo]
  Pergunta: "faça uma receita de bolo" Resposta: [ROUTE: fora_escopo]

Responda APENAS com o token [ROUTE: X] sem mais nenhum texto.
''';

final llmRouterServiceProvider = Provider<LlmRouterService>((ref) {
  return LlmRouterService(ref.watch(llmServiceProvider));
});

class LlmRouterService {
  final LlmService _llmService;

  static final _routeRegex = RegExp(
    r'\[ROUTE:\s*(gastos|metas|fluxo|busca|fora_escopo)\]',
  );

  LlmRouterService(this._llmService);

  Future<String> route(String userMessage) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      final prompt = attempt == 0
          ? '$_kRouterPrompt\nPergunta: $userMessage'
          : 'Classifique a pergunta abaixo em UMA opção.\n'
              'Responda APENAS com: [ROUTE: gastos|metas|fluxo|busca|fora_escopo]\n'
              'Pergunta: "$userMessage"';
      try {
        final result = await _llmService.generateOnce(prompt, maxTokens: 20);
        debugPrint('[Router] tentativa ${attempt + 1} raw: "$result"');
        final match = _routeRegex.firstMatch(result);
        if (match != null) {
          final skillId = match.group(1)!;
          debugPrint('[Router] → $skillId');
          return skillId;
        }
        debugPrint('[Router] regex não casou na tentativa ${attempt + 1}');
      } catch (e) {
        debugPrint('[Router] erro tentativa ${attempt + 1}: $e');
      }
    }
    debugPrint('[Router] fallback → fora_escopo');
    return 'fora_escopo';
  }
}
