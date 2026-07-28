---
type: Task
title: "Métricas de cobertura e gates no CI"
description: "Rodar flutter test --coverage no CI e tornar visível a lacuna de cobertura (especialmente UI)."
tags: [ci, quality, coverage, tests]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/3
---

## Descrição

Não há relatório de cobertura no CI, o que torna invisível a lacuna de testes de UI (ver task 63).
Adicionar `flutter test --coverage` e publicar/checar o report dá visibilidade e evita regressão.

Complementa o gate `--fatal-infos` da task 55.

## Checklist

- [ ] Adicionar `flutter test --coverage` ao workflow de CI
- [ ] Publicar artefato de cobertura (lcov) ou resumo no job
- [ ] (Opcional) Definir limiar mínimo de cobertura como gate
