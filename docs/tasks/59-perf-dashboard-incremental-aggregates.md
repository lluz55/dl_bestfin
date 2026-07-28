---
type: Task
title: "Perf — agregados incrementais no dashboard"
description: "Evitar reprocessar todo o histórico de transações a cada carga do dashboard usando agregados materializados/incrementais por período."
tags: [performance, dashboard, data-layer]
timestamp: 2026-07-26T00:00:00Z
status: wont_do
progress: 1/3
---

## Resolução (2026-07-26) — não será implementada

Medido o baseline (item 1). Os dados **não justificam** o custo/risco da tabela de
agregados materializados (itens 2 e 3), que foram descartados. A investigação em si é a
entrega da task.

**Baseline — custo de `GetDashboardData.aggregate()` por volume** (função pura, que já
roda **fora da thread de UI** em isolate via `compute`; benchmark em
`test/features/dashboard/get_dashboard_data_benchmark_test.dart`):

| Transações | Tempo/agregação |
|---|---|
| 100 | 1,3 ms |
| 1.000 | 1,1 ms |
| 5.000 | 3,3 ms |
| 10.000 | 5,2 ms |
| 25.000 | 31,9 ms |
| 50.000 | 66,2 ms |

Até ~10k transações a agregação inteira leva ~5 ms — bem abaixo do orçamento de frame de
16,7 ms — e nunca bloqueia a UI (isolate). O custo só cresce a partir de 25k–50k
transações, volume irreal para finanças pessoais.

**Por que não fazer:** uma tabela de agregados materializada teria que ser mantida em
sincronia com **todos** os write paths (insert/update/delete, splits, geração de
recorrências, reconciliação) **e** o merge de sync Nostr, com corrupção silenciosa do
dashboard como modo de falha — para resolver um gargalo que não existe na escala real.
Tasks 45 e 50 já cobriram as otimizações que valiam a pena (isolate + partição-antes-de-ordenar).

O benchmark fica versionado como guarda de regressão: se o baseline degradar em escala
realista no futuro, reabrir esta análise.

## Descrição

`lib/features/dashboard/domain/usecases/get_dashboard_data.dart:55` documenta que a agregação
reprocessa **todo** o histórico de transações em várias passadas. Já houve trabalho de perf
(tasks 45 e 50 — isolate + otimização de barras/cashflow), mas o custo full-history escala mal
conforme o volume de transações cresce.

Proposta: manter uma tabela de agregados (por mês/categoria) atualizada incrementalmente na
escrita de transações, e o dashboard lê os agregados ao invés de recomputar do zero.

## Checklist

- [x] Medir tempo de agregação com dataset grande (baseline) — ver Resolução acima
- [ ] ~~Projetar tabela de agregados + migration Drift e estratégia de atualização incremental~~ (descartado — não justificado)
- [ ] ~~Dashboard consumindo agregados; validar paridade de resultados com testes~~ (descartado — não justificado)
