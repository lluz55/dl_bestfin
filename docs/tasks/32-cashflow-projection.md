---
type: Task
id: "32"
title: "Projeção de Fluxo de Caixa (30/60/90 dias)"
status: done
timestamp: 2026-07-26T13:00:00Z
---

# Projeção de Fluxo de Caixa

Forward-looking cash flow — projeta saldo futuro baseado em regras recorrentes,
parcelas de financiamentos e planos de parcelamento existentes.

Nenhuma mudança de schema necessária — usa dados já existentes.

## Subtarefas

- [x] Criar CashflowPoint + CashflowEvent domain models
- [x] Criar ProjectCashflowUseCase (algoritmo de projeção diária)
- [x] Criar CashflowProvider (FutureProvider.family com horizonDays)
- [x] Criar CashflowScreen com seletor 30/60/90 dias
- [x] Criar CashflowChart (fl_chart LineChart área)
- [x] Criar CashflowProjectionCard (dashboard widget compacto)
- [x] Adicionar HomeWidgetId.cashFlowProjection
- [x] Adicionar rota /cashflow
