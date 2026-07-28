---
type: Feature
title: Dashboard
description: Tela principal com widgets configuráveis, atalhos, filtros de período e insights LLM.
tags: [dashboard, home, widgets, insights, gráficos]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Tela inicial do app. Exibe resumo financeiro do período selecionado com widgets configuráveis pelo usuário, atalhos personalizáveis e insights gerados pelo LLM.

## Tela Principal

`lib/features/dashboard/dashboard_screen.dart`

## Perfil do Usuário no Header

O header saúda o usuário pelo primeiro nome ("Bom dia, Lucas") e mostra sua
foto no lugar do ícone do app quando o perfil está preenchido — dados do
`userProfileProvider` (`lib/core/providers/user_profile_provider.dart`),
editáveis no onboarding e em Configurações → Perfil. Avatar renderizado por
`ProfileAvatar` (`lib/core/widgets/profile_avatar.dart`).

## Widgets Configuráveis

O usuário pode reordenar/ocultar widgets via `HomeWidgetsEditSheet`. Gerenciados por `homeWidgetsProvider`.

| Widget | Arquivo | Propósito |
|---|---|---|
| `BalanceCard` | `widgets/balance_card.dart` | Saldo total consolidado |
| `FreeToSpendCard` | `widgets/free_to_spend_card.dart` | Quanto sobra para gastar |
| `SpendingDonut` | `widgets/spending_donut.dart` | Donut de gastos por categoria |
| `IncomeExpenseBar` | `widgets/income_expense_bar.dart` | Barras receita vs despesa |
| `UpcomingBills` | `widgets/upcoming_bills.dart` | Próximas contas recorrentes |
| `GoalsProgress` | `widgets/goals_progress.dart` | Progresso das metas |
| `InsightCard` | `widgets/insight_card.dart` | Insight gerado pelo LLM |
| `StreamsDashboardWidget` | `gamification/../streaks_dashboard_widget.dart` | Streak atual |
| `ChartWidgetsWrapper` | `widgets/chart_widgets_wrapper.dart` | Container de gráficos |

## Providers

| Provider | Arquivo |
|---|---|
| `dashboardProvider` | `presentation/providers/dashboard_provider.dart` |
| `homeWidgetsProvider` | `presentation/providers/home_widgets_provider.dart` |
| `shortcutsProvider` | `presentation/providers/shortcuts_provider.dart` |

## Filtros de Período

`['Este mês', 'Semana', '3 meses', 'Ano']` — chips animados no topo (`dashboardPeriodProvider`). O índice é passado ao `dashboardProvider` → `GetDashboardData(periodIndex:)`.

O período janela **todos** os dados derivados de transações no `aggregate`: totais de receita/despesa, donut e ranking de categorias, a lista de **Últimas transações** (`recentTransactions`, filtrada por `!date.isBefore(start)` antes do `take(10)`) e os três gráficos de histórico (Histórico mensal, Evolução patrimonial, Fluxo de caixa), dimensionados por `_monthsInWindow(start, now)` em vez dos 6 meses fixos antigos. O Fluxo de caixa é diário e reflete a janela exata. Componentes de ponto-no-tempo (Saldo, Livre para gastar) e projeções próprias (Orçamentos, Projeção, Próximas contas) não dependem do período.

## Últimas Transações

Reutiliza o `TransactionTile` da tela de Transações (`transactions/presentation/widgets/transaction_tile.dart`) via `_RecentTransactionsList`, para listagem visualmente idêntica (ícone de categoria, entidade, badges, ações de duplicar/excluir/marcar como pago) — sem modo de seleção em massa.

## Pull-to-Refresh

`RefreshIndicator` invalida `dashboardProvider` e aguarda o novo carregamento.

## Modo Privacidade

`valuesHiddenProvider` — quando ativo, todos os valores monetários são substituídos por `•••`. Aplicado globalmente via `AmountDisplay`.

## Dependências

- [Transações](transactions.md) — dados base para saldos e totais
- [Metas](goals.md) — widget de progresso
- [Recorrências](recurring.md) — widget de próximas contas
- [Gamificação](gamification.md) — widget de streak
