---
type: Task
title: "Fortalecer categorização automática (sem servidor)"
description: "Melhorar o recomendador estatístico de categoria (predict_category) como diferencial de UX, já que o LLM on-device foi descontinuado."
tags: [feature, ml, transactions, ux]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/4
---

## Descrição

Já existe `predict_category` (recomendador estatístico) usado no lançamento rápido. Como as
branches de LLM local (LiteRT/Gemma) foram abandonadas (ver task 57), um classificador
estatístico mais forte — ou um modelo leve on-device — é um diferencial sem custo de servidor.

Depende da decisão da task 57 (manter/remover AI on-device).

## Checklist

- [ ] Avaliar acurácia atual de `predict_category` com dataset real do usuário
- [ ] Melhorar features do recomendador (n-gramas do descritor, entidade, valor, recência)
- [ ] Feedback loop: aprender com correções manuais do usuário
- [ ] Testes de acurácia (`predict_category_test.dart`) cobrindo casos novos
