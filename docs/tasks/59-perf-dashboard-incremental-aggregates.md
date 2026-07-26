---
type: Task
title: "Perf — agregados incrementais no dashboard"
description: "Evitar reprocessar todo o histórico de transações a cada carga do dashboard usando agregados materializados/incrementais por período."
tags: [performance, dashboard, data-layer]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/3
---

## Descrição

`lib/features/dashboard/domain/usecases/get_dashboard_data.dart:55` documenta que a agregação
reprocessa **todo** o histórico de transações em várias passadas. Já houve trabalho de perf
(tasks 45 e 50 — isolate + otimização de barras/cashflow), mas o custo full-history escala mal
conforme o volume de transações cresce.

Proposta: manter uma tabela de agregados (por mês/categoria) atualizada incrementalmente na
escrita de transações, e o dashboard lê os agregados ao invés de recomputar do zero.

## Checklist

- [ ] Medir tempo de agregação com dataset grande (baseline)
- [ ] Projetar tabela de agregados + migration Drift e estratégia de atualização incremental
- [ ] Dashboard consumindo agregados; validar paridade de resultados com testes
