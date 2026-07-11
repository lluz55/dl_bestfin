---
type: Task
id: "47"
title: Exibir Categoria Pai/Filho em Todos os Componentes do App
status: completed
timestamp: 2026-07-11T00:00:00Z
---

# Tarefa 47 — Categoria Pai/Filho em Todo o App

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** [05-categories](./05-categories.md), [06-transactions](./06-transactions.md)

---

## Descrição

Continuação do commit `75e3570` (v1.0.8), que passou a exibir
`CategoryModel.displayName` ("Pai/Filho") apenas nos gráficos do dashboard e
relatórios. O usuário pediu para **revisar todo o app** e garantir que, onde uma
subcategoria aparece como rótulo isolado, ela apareça como "Pai/Filho" para
desambiguar (ex.: `Alimentação/Restaurante`).

Regra aplicada:

- **Rótulo isolado de categoria** (filtros, chips, cards de envelope,
  recorrência, itens de fatura, seletor de envelope, chip do formulário) →
  usa `displayName`.
- **Árvore de gerenciamento de categorias** (`categories_screen`,
  `category_tile`) e cabeçalhos de agrupamento por pai → mantêm só `name`,
  pois a hierarquia já é visual pela indentação/seção.
- **Serialização/export** (`category_repository` map) → mantém `name`.

---

## Subtarefas

 - [x] `TransactionFilters`: lista de seleção e chip de categoria usam
   `displayName` (provider já enriquecido via `allFlatCategoriesProvider`)
 - [x] `ReportFiltersWidget`: lista de seleção e chip de categoria usam
   `displayName`
 - [x] `InvoiceDetailScreen`: item de transação da fatura usa
   `tx.category?.displayName`
 - [x] `BulkTransactionScreen`: ao carregar transação existente, `categoryName`
   da linha recebe `tx.category!.displayName`
 - [x] `TransactionFormScreen`: fallbacks de `_categoryName` (edição e rascunho)
   usam `displayName`
 - [x] `BudgetFormSheet`: rótulo do seletor de categoria usa `displayName`
 - [x] `BudgetRepository._enrich`: `categoryName` armazenado passa a ser
   "Pai/Filho" (relações carregadas uma vez por emissão via
   `getAllRelationships`); corrige budget_card, budget_form e delete-confirm
 - [x] `RecurringRepository._enrichRules`: `categoryName` passa a ser "Pai/Filho"
   (carrega relações + categorias-pai no mesmo lote, sem N+1); corrige
   `recurring_card`
 - [x] Componentes que já usavam `displayName` verificados (donut/ranking do
   dashboard, `SpendingDonut`, `category_picker`, `category_multi_select_button`,
   `quick_transaction_sheet`, `split_editor_sheet`, `goal_category_selector`)
 - [x] `dart analyze` sem novos erros/warnings/infos nos arquivos tocados
