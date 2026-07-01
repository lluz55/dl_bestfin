---
type: Task
id: "29"
title: "Orçamento Envelope (YNAB-style)"
status: in_progress
timestamp: 2026-07-01T00:00:00Z
---

# Orçamento Envelope

Feature de orçamento mensal por categoria com rollover automático do saldo não gasto.

## Subtarefas

- [x] Criar tabela Drift `budgets` com uniqueKey (categoryId, year, month)
- [x] Migração v18: createTable(budgets)
- [x] Criar BudgetsDao com watchBudgetsWithSpending, CRUD
- [x] Criar BudgetRepository + BudgetModel
- [x] Criar RolloverBudgetUseCase
- [x] Criar BudgetsProvider (Riverpod)
- [x] Criar BudgetsListScreen
- [x] Criar BudgetFormSheet (modal)
- [x] Criar BudgetCard widget
- [x] Criar BudgetsOverviewCard (dashboard)
- [x] Adicionar HomeWidgetId.budgetsOverview
- [x] Adicionar rota /budgets
- [x] Adicionar item no MoreScreen (seção Objetivos)
