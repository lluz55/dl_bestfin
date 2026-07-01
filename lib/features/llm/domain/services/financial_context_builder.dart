import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

class FinancialContextBuilder {
  static String? _cachedContext;
  static DateTime? _cacheTimestamp;
  static const _cacheTtl = Duration(minutes: 5);

  static String build(Ref ref) {
    if (_cachedContext != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTtl) {
      return _cachedContext!;
    }

    final balance = ref.read(totalBalanceProvider);
    final health = ref.read(financialHealthScoreProvider);
    final forecast = ref.read(cashFlowForecastingProvider);
    final anomalies = ref.read(anomalyDetectionProvider);
    final trends = ref.read(spendingTrendsProvider);
    final goals = ref.read(goalAchievabilityProvider);
    final txsAsync = ref.read(filteredTransactionsProvider);

    final fmt = NumberFormat('#,##0.00', 'pt_BR');
    String brl(int cents) => 'R\$ ${fmt.format(cents / 100)}';

    final buf = StringBuffer();

    // 1. Static Tool Instructions (written first so they are at the top, enabling 100% KV cache hit rate)
    buf.writeln('=== FERRAMENTAS DISPONÍVEIS ===');
    buf.writeln(
      'Você é o assistente financeiro BestFin. Você tem duas ferramentas. Quando precisar de cálculo ou dados, escreva APENAS a linha da ferramenta e pare imediatamente — nada antes, nada depois.',
    );
    buf.writeln('');
    buf.writeln('=== DIRETRIZES DE RESPOSTA ===');
    buf.writeln(
      '- Responda de forma extremamente concisa, direta, curta e objetiva.',
    );
    buf.writeln(
      '- Responda SEMPRE no mesmo idioma/linguagem que o usuário utilizou na pergunta (se ele perguntar em inglês, responda em inglês; se em português, responda em português, etc.).',
    );
    buf.writeln(
      '- Você deve se manter estritamente dentro do escopo do aplicativo BestFin (finanças pessoais, controle de gastos, planejamento, economia e orçamento).',
    );
    buf.writeln(
      '- Se o usuário perguntar sobre assuntos não relacionados ao tema (como receitas culinárias, programação de software, piadas, curiosidades históricas, esportes, etc.), recuse-se de forma educada, direta e concisa a responder, orientando-o a perguntar sobre suas finanças pessoais ou economia doméstica.',
    );
    buf.writeln('');
    buf.writeln('FORMATO OBRIGATÓRIO (use : dois-pontos, nunca parênteses):');
    buf.writeln('');
    buf.writeln('[CALCULATE: 1500 * 0.15]');
    buf.writeln('[CALCULATE: 3400 + 1200 - 450]');
    buf.writeln('[LOOKUP_USER_DATA: {"action": "list_accounts"}]');
    buf.writeln('[LOOKUP_USER_DATA: {"action": "list_categories"}]');
    buf.writeln(
      '[LOOKUP_USER_DATA: {"action": "search_transactions", "start_date": "2025-05-01", "end_date": "2025-05-31"}]',
    );
    buf.writeln(
      '[LOOKUP_USER_DATA: {"action": "search_transactions", "category": "alimentação"}]',
    );
    buf.writeln('[GET_GOALS: {}]');
    buf.writeln('[GET_RECURRING: {}]');
    buf.writeln(
      '[GET_SPENDING_SUMMARY: {"start_date": "2026-05-01", "end_date": "2026-05-31"}]',
    );
    buf.writeln('[GET_SPENDING_SUMMARY: {}]');
    buf.writeln('');
    buf.writeln('REGRAS CRÍTICAS E OBRIGATÓRIAS DE USO DE FERRAMENTAS:');
    buf.writeln(
      '1. O CALCULATE serve APENAS para matemática básica (+, -, *, /) com números reais.',
    );
    buf.writeln(
      '   - Ele NÃO tem acesso ao banco de dados e NÃO sabe o que o usuário gastou.',
    );
    buf.writeln(
      '   - Ele NÃO aceita textos, SQL, datas, filtros ou nomes de tabelas (ex: "SUM(Traques...)" é PROIBIDO no CALCULATE).',
    );
    buf.writeln('   - Exemplo correto: [CALCULATE: 150.50 + 200]');
    buf.writeln(
      '2. O LOOKUP_USER_DATA acessa contas, categorias e transações individuais.',
    );
    buf.writeln(
      '   - Se o usuário perguntar algo como "Quanto gastei este mês?", use GET_SPENDING_SUMMARY para um resumo por categoria.',
    );
    buf.writeln(
      '   - Use LOOKUP_USER_DATA + search_transactions apenas se precisar de transações individuais específicas.',
    );
    buf.writeln(
      '   - Exemplo: [LOOKUP_USER_DATA: {"action": "search_transactions", "start_date": "2026-05-01", "end_date": "2026-05-31"}]',
    );
    buf.writeln(
      '3. O GET_SPENDING_SUMMARY retorna o total gasto por categoria num período (mais eficiente para visões gerais).',
    );
    buf.writeln(
      '   - Omitir datas = mês atual. Exemplo: [GET_SPENDING_SUMMARY: {}]',
    );
    buf.writeln(
      '4. O GET_GOALS lista todas as metas financeiras ativas com progresso e prazo.',
    );
    buf.writeln(
      '   - Use quando o usuário perguntar sobre metas, objetivos ou economias. Exemplo: [GET_GOALS: {}]',
    );
    buf.writeln(
      '5. O GET_RECURRING lista todas as transações recorrentes ativas (assinaturas, salário, aluguel, etc.).',
    );
    buf.writeln(
      '   - Use quando o usuário perguntar sobre gastos fixos, assinaturas ou receitas regulares. Exemplo: [GET_RECURRING: {}]',
    );
    buf.writeln('6. FLUXO DE TRABALHO:');
    buf.writeln(
      '   - Primeiro, use a ferramenta adequada para trazer os dados reais.',
    );
    buf.writeln(
      '   - Depois, se precisar calcular porcentagens ou somas sobre valores retornados, use CALCULATE.',
    );
    buf.writeln(
      '7. Escreva SOMENTE a linha da ferramenta (ex: [GET_GOALS: {}]). Nada mais antes ou depois.',
    );
    buf.writeln(
      '8. Só responda em texto final para o usuário quando você já tiver o resultado real da ferramenta.',
    );
    buf.writeln('');

    // 2. Dynamic Financial Context (written at the bottom since it changes frequently)
    buf.writeln('=== CONTEXTO FINANCEIRO DO USUÁRIO ===');
    buf.writeln('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}');
    buf.writeln('');

    // Balance
    buf.writeln('Saldo atual: ${brl(balance)}');
    buf.writeln('Projeção 30 dias: ${brl(forecast.projectedBalance30Days)}');
    buf.writeln('Projeção 90 dias: ${brl(forecast.projectedBalance90Days)}');
    if (forecast.alertMessage != null) {
      buf.writeln('⚠️ Alerta: ${forecast.alertMessage}');
    }
    buf.writeln('');

    // Health score
    buf.writeln('Saúde financeira: ${health.score}/100 (nota ${health.grade})');
    buf.writeln(
      'Taxa de poupança (90 dias): ${(health.savingsRate * 100).toStringAsFixed(1)}%',
    );
    buf.writeln('');

    // Anomalies
    if (anomalies.isNotEmpty) {
      buf.writeln('Anomalias detectadas (${anomalies.length}):');
      for (final a in anomalies.take(3)) {
        buf.writeln('  - ${a.title}: ${a.description}');
      }
      buf.writeln('');
    }

    // Spending trends
    if (trends.isNotEmpty) {
      buf.writeln('Tendências de gasto (mês atual vs anterior):');
      for (final t in trends.take(5)) {
        final symbol = t.trend == 'increasing'
            ? '↑'
            : t.trend == 'decreasing'
            ? '↓'
            : '→';
        buf.writeln(
          '  $symbol ${t.categoryName}: ${t.percentChange.toStringAsFixed(1)}%',
        );
      }
      buf.writeln('');
    }

    // Goals
    if (goals.isNotEmpty) {
      buf.writeln('Metas financeiras:');
      for (final g in goals.take(3)) {
        final pct = (g.progressFraction * 100).toStringAsFixed(0);
        final track = g.isOnTrack ? '✅ no prazo' : '⚠️ atrasada';
        buf.writeln('  - ${g.goalName}: $pct% ($track) — ${g.statusMessage}');
      }
      buf.writeln('');
    }

    // Recent transactions
    final txs = txsAsync.value;
    if (txs != null && txs.isNotEmpty) {
      final recent = txs.where((t) => t.isCompleted).take(20).toList();
      if (recent.isNotEmpty) {
        final accounts = ref.read(activeAccountsProvider);
        final accountMap = {for (final a in accounts) a.id: a.name};

        buf.writeln('Últimas ${recent.length} transações confirmadas:');
        for (final tx in recent) {
          final sign = tx.type == TransactionType.income ? '+' : '-';

          final String typeLabel;
          final String payer;
          final String payee;

          if (tx.type == TransactionType.income) {
            typeLabel = 'Receita (Entrada)';
            payer = tx.entity?.name ?? 'Não especificado (Outros)';
            final destAccountId = tx.accountId;
            payee =
                (destAccountId != null ? accountMap[destAccountId] : null) ??
                'Usuário (Minha Conta)';
          } else if (tx.type == TransactionType.expense) {
            typeLabel = 'Despesa (Saída)';
            final sourceAccountId = tx.accountId;
            payer =
                (sourceAccountId != null
                    ? accountMap[sourceAccountId]
                    : null) ??
                'Usuário (Minha Conta)';
            payee = tx.entity?.name ?? 'Não especificado';
          } else {
            typeLabel = 'Transferência (Movimentação Interna)';
            final fromAcc = tx.fromAccountId;
            final toAcc = tx.toAccountId;
            payer =
                (fromAcc != null ? accountMap[fromAcc] : null) ??
                'Conta Origem';
            payee =
                (toAcc != null ? accountMap[toAcc] : null) ?? 'Conta Destino';
          }

          final cat = tx.category?.name ?? 'Sem categoria';
          buf.writeln(
            '  - ${DateFormat('dd/MM/yyyy').format(tx.date)}: $sign${brl(tx.amount)} - "${tx.description}" [$cat]\n'
            '    Tipo: $typeLabel | Pagador: $payer | Recebedor: $payee',
          );
        }
      }
    }

    _cachedContext = buf.toString();
    _cacheTimestamp = DateTime.now();
    return _cachedContext!;
  }

  static void invalidate() {
    _cachedContext = null;
    _cacheTimestamp = null;
  }
}
