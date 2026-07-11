---
type: Task
id: "29"
title: "Orçamento (multi-categorias)"
status: completed
timestamp: 2026-07-11T00:00:00Z
---

# Orçamento

Feature de orçamento mensal com múltiplas categorias por orçamento e rollover automático.

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
- [x] Renomear "Envelope" → "Orçamento" em toda a UI
- [x] Criar tabela pivô `budget_categories` (budgetId, categoryId)
- [x] Migration v24: adicionar coluna `name`, criar budget_categories, migrar dados
- [x] Atualizar DAO para multi-categorias (getCategoryIdsForBudget, insertBudget com categoryIds)
- [x] Atualizar Repository com _enrichCategories
- [x] Atualizar BudgetModel (name, List<CategoryInfo>)
- [x] Atualizar Providers (createBudgetProvider, updateBudgetProvider)
- [x] Atualizar BudgetFormSheet com campo nome + CategoryMultiSelectButton
- [x] Atualizar BudgetCard com chips de categorias
- [x] Atualizar BudgetsOverviewCard com nome do orçamento
- [x] Atualizar sync_service para formato legado e novo
- [x] Atualizar insights_service para multi-categorias
- [x] Atualizar testes (budgets_dao_test, insights_service_test)
