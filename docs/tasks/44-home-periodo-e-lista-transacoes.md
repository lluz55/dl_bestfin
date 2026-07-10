# Tarefa 44 — Período global na Home e lista de transações consistente ✅

> **Fase:** 3 — Refinamentos
> **Prioridade:** 🟡 Alta
> **Estimativa:** Pequena
> **Última atualização:** 2026-07-10

## Descrição

Dois ajustes de consistência na tela inicial (Dashboard):

1. **Lista "Últimas transações" igual à de Transações:** substituir o
   `StaggeredTransactionList` (modelo simplificado `TransactionItem`) pelo mesmo
   `TransactionTile` usado na tela de Transações, ganhando ícone de categoria
   com pai, entidade, badges de pendente/agendada/atrasada e as ações de
   duplicar/excluir/marcar como pago (swipe + menu). Sem modo de seleção em
   massa.
2. **Filtro de período aplicado a todos os componentes:** o chip de período
   (`Este mês / Semana / 3 meses / Ano`) passa a janelar **todos** os dados
   derivados de transações — incluindo os três gráficos de histórico
   (Histórico mensal, Evolução patrimonial, Fluxo de caixa) e a própria lista
   de últimas transações, que antes ignoravam o período (mostravam 6 meses
   fixos / últimas 10 globais).

## Subtarefas

### 1. Camada de domínio (`get_dashboard_data.dart`) ✅

- [x] `recentTransactions` filtrado por `!tx.date.isBefore(start)` antes do `take(10)`.
- [x] Helper `_monthsInWindow(start, now)` (>= 1) para dimensionar os gráficos mensais.
- [x] `_calculateMonthlyHistory` e `_calculateNetWorthHistory` usam a janela do período em vez de 6 meses fixos.
- [x] `_calculateCashFlowHistory` janela por `windowStart` (period start) no lugar de `sixMonthsAgo` (baseline, filtro confirmado e camada de previsto).

### 2. Camada de apresentação (`dashboard_screen.dart`) ✅

- [x] Novo widget `_RecentTransactionsList` (ConsumerWidget) reaproveitando `TransactionTile` com onTap/onClone/onDelete/onMarkAsPaid.
- [x] Remoção de `_buildTransactionItems` e imports não usados (`staggered_transaction_list`, `accounts_provider`).

### 3. Testes e Validação ✅

- [x] Ajuste do teste de agregação: `recentTransactions` agora respeita o período (exclui lançamentos de meses anteriores).
- [x] `flutter analyze` sem novos issues; `flutter test test/features/dashboard/` verde.

## Notas de design

- Os gráficos são inerentemente mensais (modelos `MonthlyBar`/`NetWorthPoint`
  e widgets compartilhados com Relatórios). Períodos curtos (Semana/Este mês)
  resultam em poucos buckets mensais; o **Fluxo de caixa** já é diário e mostra
  a janela real (ex.: só esta semana). Manter granularidade mensal evita mexer
  nos widgets compartilhados de Relatórios.
- Componentes de ponto-no-tempo (Saldo, Livre para gastar) e projeções
  próprias (Orçamentos, Projeção de fluxo, Próximas contas) não dependem do
  período por natureza e permanecem inalterados.
