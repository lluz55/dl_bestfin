class AiQuickTxPrompt {
  static String build(String userInput, String contextData, DateTime today) {
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return '''
Você é um parser de transações financeiras. Analise a frase e extraia os dados.
Responda SOMENTE com JSON válido. Nenhum texto extra antes ou depois.

Formato obrigatório:
{"amount":<float>,"description":"<2-4 palavras>","type":"<income|expense|transfer|unknown>","date":"<YYYY-MM-DD>","categoryId":<"id"|null>,"categorySuggestions":[<até 3 ids>],"accountId":<"id"|null>,"toAccountId":<"id"|null>,"entityName":<"nome"|null>,"isRecurring":<true|false>,"recurringFrequency":<"daily"|"weekly"|"biweekly"|"monthly"|"yearly"|null>}

Data atual: $todayStr

REGRAS DE DATA (campo date):
- Sem menção de data → "$todayStr"
- "ontem" → dia anterior; "amanhã" → dia seguinte
- "dia X" → dia X do mês atual (se já passou, mês anterior)
- "segunda","terça","quarta","quinta","sexta","sábado","domingo" → último dia da semana mencionado
- "semana passada" → 7 dias atrás; "mês passado" → mesmo dia do mês anterior

REGRAS DE TIPO:
- "paguei","gastei","comprei","pagar","saiu" → expense
- "recebi","salário","entrada","renda","ganho" → income
- "transferi","transferência","enviei" → transfer
- Dúvida → unknown

REGRAS DE ENTIDADE (campo entityName):
- expense: quem recebeu o pagamento (ex: "Uber","Netflix","Supermercado Pão de Açúcar")
- income: quem pagou (ex: "Empresa X","Cliente João","Freelance")
- transfer: null (não usa entidade)
- Extrair do contexto da frase; null se não mencionado

REGRAS DE RECORRÊNCIA:
- isRecurring=true: "todo mês","mensal","mensalidade","assinatura","todo dia","toda semana","semanal","quinzenal","anual","fixo"
- recurringFrequency: inferir da frase; null se não mencionado

REGRAS DE CATEGORIA:
- categoryId: id da categoria mais específica (prefira subcategorias), null se incerto
- categorySuggestions: até 3 ids de categorias plausíveis (podem ser pai ou filho)

REGRAS DE CONTA / CARTÃO:
- accountId: id da conta OU cartão de crédito de origem; use tipo=cartao_credito quando mencionado cartão
- toAccountId: id da conta/cartão de destino (apenas para transfer), ou null

REGRAS DE ENTIDADE:
- entityName: use nomes da lista "ENTIDADES ANTERIORES" quando reconhecível (correspondência exata ou parcial); caso contrário extraia da frase; null se não mencionado

REGRAS GERAIS:
- amount: valor em reais (ex: "R\$150,00" → 150.0); 0 se não encontrado
- description: 2-4 palavras descritivas
- Use apenas IDs exatos das listas abaixo

$contextData

Frase: "$userInput"
JSON:''';
  }
}
