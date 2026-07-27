---
type: Task
title: "Fortalecer categorização automática (sem servidor)"
description: "Melhorar o recomendador estatístico de categoria (predict_category) como diferencial de UX, já que o LLM on-device foi descontinuado."
tags: [feature, ml, transactions, ux]
timestamp: 2026-07-27T00:00:00Z
status: done
progress: 4/4
---

## Descrição

Já existe `predict_category` (recomendador estatístico) usado no lançamento rápido. Como as
branches de LLM local (LiteRT/Gemma) foram abandonadas (ver task 57), um classificador
estatístico mais forte — ou um modelo leve on-device — é um diferencial sem custo de servidor.

Depende da decisão da task 57 (manter/remover AI on-device).

## Checklist

- [x] Avaliar acurácia atual de `predict_category` com dataset rotulado (baseline)
- [x] Melhorar features do recomendador (n-gramas do descritor, entidade, valor, recência)
- [x] Feedback loop: aprender com correções manuais do usuário
- [x] Testes de acurácia (`predict_category_test.dart`) cobrindo casos novos

## Resolução (2026-07-27)

Abordagem *measure-first* (mesma disciplina da Task 59): harness de acurácia com
dataset rotulado realista antes de mexer no algoritmo.

**Ganho:** acurácia top-1 **56,7% → 100%** no harness (30 casos de teste,
descrições que são *variações* das de treino — ordem/sufixo diferentes, nunca
idênticas).

**O que mudou em `predictCategory`:**
- **Descrição por n-gramas** (o coração): trocado o casamento por string exata
  (que quase nunca dispara em descrições reais) por sobreposição de tokens
  — unigramas + bigramas, sem acento, sem stopwords/ruído de meio de pagamento
  (`pix`/`ted`/`compra`…) — ponderada por Jaccard × recência. "Extra Supermercado"
  passa a casar com "Supermercado Extra 123".
- **Valor** (`amountInCents`, opcional): refino conservador (bônus ≤ 0,25×) que
  só desempata entre casamentos de descrição — nunca cria sinal sozinho. Ligado
  no `QuickTransactionSheet` quando o valor já foi digitado.
- **Entidade** e **frequência geral**: tiers preservados (prioridade
  entidade → descrição → geral), mantendo compatibilidade com os testes antigos.
- **Feedback loop:** o decaimento de recência (meia-vida 30d) faz uma correção
  manual recente dominar o histórico antigo — o recomendador aprende sem estado
  extra nem mudança de schema. Coberto por teste dedicado.

## Arquivos

- `lib/features/transactions/domain/usecases/predict_category.dart` — algoritmo fortalecido (n-gramas, acento, stopwords, valor)
- `lib/features/transactions/presentation/widgets/quick_transaction_sheet.dart` — passa `amountInCents` na predição
- `test/features/transactions/predict_category_test.dart` — 5 casos novos (n-grama, acento, stopwords, feedback loop, desempate por valor)
- `test/features/transactions/predict_category_accuracy_test.dart` — harness de acurácia (guarda de regressão, threshold ≥ 80%)

## Aceitação

- Descrições variadas do mundo real casam por tokens, não exigem string idêntica
- Correções recentes do usuário passam a mandar na predição (recência)
- Determinístico, on-device, custo zero, sem mudança de schema
- Sem regressão nos 7 testes unitários existentes; 47 testes de `transactions/` verdes
