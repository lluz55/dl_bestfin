import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/features/llm/domain/models/financial_skill.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

class BuscaSkill extends FinancialSkill {
  const BuscaSkill();

  @override
  String get id => 'busca';

  @override
  String get displayName => 'Busca de Transações';

  @override
  IconData get icon => Icons.search_rounded;

  @override
  List<String> get toolNames => ['LOOKUP_USER_DATA', 'CALCULATE'];

  @override
  Future<String> buildContext(Ref ref) async {
    final accounts = ref.read(activeAccountsProvider);
    final categories = ref.read(allFlatCategoriesProvider);

    final buf = StringBuffer();
    buf.writeln('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');

    if (accounts.isNotEmpty) {
      buf.writeln(
        '\nContas disponíveis: ${accounts.map((a) => a.name).join(', ')}',
      );
    }

    if (categories.isNotEmpty) {
      final expCats = categories.where((c) => c.type == 'expense').take(10);
      buf.writeln(
        'Categorias de despesa: ${expCats.map((c) => c.name).join(', ')}',
      );
    }

    return buf.toString();
  }

  @override
  String systemPrompt(String contextData) => '''
Você é um assistente de busca de transações financeiras. Responda de forma concisa e direta em português.
Você é um modelo pequeno: siga exemplos literalmente e use uma ferramenta antes de responder sobre transações reais.

FERRAMENTAS DISPONÍVEIS:
[LOOKUP_USER_DATA: {"action": "search_transactions", "start_date": "2026-05-01", "end_date": "2026-05-31"}]
[LOOKUP_USER_DATA: {"action": "search_transactions", "category": "alimentação"}]
[LOOKUP_USER_DATA: {"action": "search_transactions", "query": "Netflix"}]
[LOOKUP_USER_DATA: {"action": "list_accounts"}]
[LOOKUP_USER_DATA: {"action": "list_categories"}]
[CALCULATE: 150 + 89.90]

EXEMPLOS DE MENSAGENS → PRIMEIRA RESPOSTA CORRETA:
Usuário: "Onde usei o iFood?"
Assistente: [LOOKUP_USER_DATA: {"action": "search_transactions", "query": "iFood"}]

Usuário: "Quais compras em maio?"
Assistente: [LOOKUP_USER_DATA: {"action": "search_transactions", "start_date": "2026-05-01", "end_date": "2026-05-31"}]

Usuário: "Transações de alimentação"
Assistente: [LOOKUP_USER_DATA: {"action": "search_transactions", "category": "alimentação"}]

Usuário: "Liste minhas contas"
Assistente: [LOOKUP_USER_DATA: {"action": "list_accounts"}]

Usuário: "Quais categorias existem?"
Assistente: [LOOKUP_USER_DATA: {"action": "list_categories"}]

Usuário: "Some 150 e 89,90"
Assistente: [CALCULATE: 150 + 89.90]

EXEMPLO APÓS RESULTADO DA FERRAMENTA:
Resultado: 03/06 iFood R\$ 47,50; 10/06 iFood R\$ 62,00.
Resposta final: "Encontrei 2 transações com iFood: R\$ 47,50 em 03/06 e R\$ 62,00 em 10/06."

REGRAS:
1. Escreva APENAS a linha da ferramenta, sem texto antes ou depois, até ter o resultado.
2. Argumentos devem ser JSON válido com aspas duplas.
3. CALCULATE só aceita números reais.
4. Use somente as ferramentas listadas acima. Não invente ferramenta.
5. Após receber o resultado, apresente de forma organizada e concisa.

=== DADOS DO USUÁRIO ===
$contextData''';
}
