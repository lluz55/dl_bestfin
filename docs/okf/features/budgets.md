---
type: Feature
title: Orçamento Mensal
description: Orçamento mensal com múltiplas categorias, rollover automático e acompanhamento de gastos.
tags: [orçamento, categorias, rollover, controle financeiro]
timestamp: 2026-07-11T12:00:00Z
---

## Responsabilidade

Permite criar orçamentos mensais vinculados a múltiplas categorias de despesa, acompanhar gastos confirmados e previstos, e aplicar rollover do saldo não gasto para o próximo mês.

## Modelo

- `Budget` — `lib/core/database/tables/budgets.dart` — tabela principal com nome, ano, mês, valor planejado e rollover
- `BudgetCategory` — `lib/core/database/tables/budget_categories.dart` — tabela pivô (budgetId, categoryId)
- `BudgetModel` — `lib/features/budgets/domain/models/budget_model.dart` — modelo de domínio com lista de `CategoryInfo`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/budgets_list_screen.dart` | Lista de orçamentos com navegação mensal e barra de resumo |
| `widgets/budget_form_sheet.dart` | Bottom sheet de criação/edição com nome + multi-select de categorias |
| `widgets/budget_card.dart` | Card individual com chips de categorias e barras de progresso |
| `widgets/budgets_overview_card.dart` | Widget de overview no dashboard |

## DAO

| Método | Propósito |
|---|---|
| `getBudgetsWithSpending` | Retorna orçamentos do período com gasto calculado via JOIN com transactions/entries |
| `getCategoryIdsForBudget` | Retorna IDs das categorias vinculadas a um orçamento |
| `insertBudget` | Insere orçamento + categorias na tabela pivô |
| `updateBudget` | Atualiza orçamento e substitui categorias |
| `applyRollover` | Transfere saldo disponível para o mês seguinte |

## Dependências

- [Categorias](categories.md) — categorias vinculadas via tabela pivô
- [Transações](transactions.md) — gasto calculado a partir de transações confirmadas/pendentes
- [Dashboard](dashboard.md) — widget de overview de orçamentos
