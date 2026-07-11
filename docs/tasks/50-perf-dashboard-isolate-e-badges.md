---
type: Task
id: "50"
title: "Perf — Agregação do Dashboard em isolate e badges sem full-scan"
status: completed
priority: high
tags: [performance, dashboard, gamification, isolate]
timestamp: 2026-07-11T00:00:00Z
---

# Tarefa 50 — Performance: isolate no Dashboard e badges sem full-scan

**Fase:** 3 — Refinamentos
**Prioridade:** 🔴 Alta (crítico) + 🟡 Média
**Estimativa:** Pequena
**Última atualização:** 2026-07-11

## Descrição

Continuação da auditoria de performance da Task 45, que deixou registrado como
"médio prazo" o full-scan do Dashboard. Duas correções localizadas, sem mudança
de schema:

1. **(Crítico) Agregação do Dashboard em isolate de fundo.**
   `GetDashboardData.aggregate` reprocessa TODO o histórico de transações
   (várias passadas O(n) + ordenações: histórico mensal, fluxo de caixa,
   patrimônio, ranking de categorias) a cada gravação. Rodava na thread da UI,
   causando jank em bases grandes. Agora roda via `compute()` num isolate de
   fundo. A lógica é **idêntica** — `aggregate` e seus helpers foram tornados
   `static` (nenhum usava estado de instância) para serem chamados por uma
   função de nível de topo `_aggregateDashboardData`.

2. **(Médio) Badges deixam de carregar o histórico inteiro.**
   `badge_checker` fazia `watchAllTransactions().first` + `isNotEmpty` só para
   saber se existe alguma transação — carregava e mapeava todo o histórico (com
   joins de categoria/entidade/entries). Passa a usar o método leve já existente
   `hasAnyTransactions()` (`SELECT id ... LIMIT 1`).

## Fora de escopo (registrado, não implementado)

- **Janelar a query do Dashboard no SQL** (carregar só o período em vez do
  histórico inteiro): o valor da transação vive nas `entries` (com casos de
  split, `rawAmount` de cartão e semântica "primeira entry"), então calcular o
  baseline acumulado do fluxo de caixa em SQL puro seria frágil. O isolate
  remove o jank sem esse risco de correção; a janela em SQL fica como refator
  de médio prazo.
- **Lista de Transações carrega tudo por padrão** — decisão de produto (picker
  de calendário permite qualquer período); não é puramente performance.
- **Múltiplos streams full-history concorrentes** — parcialmente mitigado pela
  Task 45; deduplicar em uma fonte única é refator arquitetural maior.

## Subtarefas

### 1. Isolate no Dashboard (`get_dashboard_data.dart`) ✅

- [x] Import de `compute` (`package:flutter/foundation.dart`).
- [x] `flush()` async chamando `compute(_aggregateDashboardData, args)`.
- [x] `aggregate` + helpers (`_calculateMonthlyHistory`,
      `_calculateCashFlowHistory`, `_calculateNetWorthHistory`,
      `_calculateCategoryRanking`) tornados `static`.
- [x] Classe `_DashboardAggregateArgs` (serializável) + função de topo
      `_aggregateDashboardData`.

### 2. Badges sem full-scan (`badge_checker.dart`) ✅

- [x] `_checkFirstTransaction` usa `hasAnyTransactions()`.
- [x] `_checkDebtFree` usa `hasAnyTransactions()`.

### 3. Testes e Validação ✅

- [x] `flutter analyze` nos arquivos alterados sem novos issues.
- [x] `flutter test test/features/dashboard/` verde (15 testes) — comportamento
      idêntico ao cálculo síncrono.
</content>
</invoke>
