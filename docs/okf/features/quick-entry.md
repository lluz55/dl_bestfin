---
type: Feature
title: Lançamento Rápido
description: Bottom sheet de criação rápida de qualquer transação com sugestões por recomendador estatístico on-device.
tags: [transações, ux, ml, recomendador, double-entry]
related: [transactions, accounts, categories]
timestamp: 2026-06-30T00:00:00Z
---

## Responsabilidade

Oferecer um caminho de 1–2 toques para registrar **qualquer** transação (despesa, receita,
transferência), sem o wizard completo. Acionado pelo `GlobalFAB`, abre um bottom sheet único
com abas de tipo, chips de sugestão (autopreenchem conta/categoria/valor) e botão Salvar. Para
edição detalhada, "Mais opções" abre o formulário completo (`transactionFormModalProvider`).

## Recomendador (ML estatístico on-device)

Não usa LLM. `rankQuickSuggestions` é uma função pura e determinística que:

1. Filtra transações concluídas e confirmadas (`isCompleted && isConfirmed && amount > 0`),
   ordena por data desc e pega as últimas ~180.
2. Agrupa por assinatura:
   - despesa/receita → `tipo + descrição(normalizada) + categoryId + entityId`
   - transferência → `tipo + contaOrigem + contaDestino`
3. Pontua cada grupo por **frequência × recência**: `score = Σ 0.5^(idadeDias / 30)` (meia-vida 30d).
4. Escolhe o **valor típico** (moda; desempate pela ocorrência mais recente) e a **conta típica** do grupo.
5. Ordena por `score` desc e devolve o top 6 do tipo selecionado.

A criação real **sempre** passa por `CreateTransaction` (valida débito = crédito). O motor só sugere.

## Predição de categoria (`predictCategory`)

Enquanto o usuário digita a descrição, `predictCategory` sugere um _smart default_ de
categoria a partir do mesmo histórico (~180 dias). Função pura e determinística, combina
quatro sinais em ordem de prioridade — **entidade → descrição → valor → frequência geral**:

- **Descrição por n-gramas:** tokeniza a descrição (minúsculas, sem acento, sem
  stopwords/ruído de pagamento como `pix`/`compra`), gera unigramas + bigramas, e pontua
  cada categoria por **Jaccard × recência**. Casa descrições *parecidas*, não idênticas
  (ex.: "Extra Supermercado" ↔ "Supermercado Extra 123") — não use casamento por string exata.
- **Entidade:** pagador/recebedor já visto é o sinal mais forte (vence a descrição).
- **Valor** (`amountInCents`, opcional): bônus conservador (≤ 0,25×) que só desempata entre
  casamentos de descrição — nunca cria sinal sozinho.
- **Feedback loop:** a meia-vida de recência (30d) faz correções manuais recentes dominarem
  o histórico antigo. Aprende sem estado extra nem mudança de schema.

## Arquivos

| Arquivo | Propósito |
|---|---|
| `lib/features/transactions/domain/models/quick_suggestion.dart` | Modelo `QuickSuggestion` |
| `lib/features/transactions/domain/usecases/get_quick_suggestions.dart` | `rankQuickSuggestions` (puro) |
| `lib/features/transactions/domain/usecases/predict_category.dart` | `predictCategory` — smart default de categoria (n-gramas + entidade + valor + recência) |
| `lib/features/transactions/presentation/providers/quick_suggestions_provider.dart` | `quickSuggestionsProvider` (StreamProvider.family por tipo) |
| `lib/features/transactions/presentation/widgets/quick_transaction_sheet.dart` | `QuickTransactionSheet` |
| `lib/core/shell/app_shell.dart` | FAB abre o sheet (`showModalBottomSheet`) |
| `test/features/transactions/get_quick_suggestions_test.dart` | Testes do ranqueamento |
| `test/features/transactions/predict_category_test.dart` | Testes de `predictCategory` (n-grama, acento, feedback loop, valor) |
| `test/features/transactions/predict_category_accuracy_test.dart` | Harness de acurácia (guarda de regressão) |

## Reuso

- `AmountInput`, `TransactionTypeTabs`, `DescriptionAutocomplete` — widgets de transação
- `createTransactionProvider` / `CreateTransaction` — criação com double-entry
- `activeAccountsProvider`, `allFlatCategoriesProvider` — fontes de seleção
- `gamificationServiceProvider.onTransactionCreated()` — streak ao criar

## Erros comuns de agente

- **Não** definir provider dentro de provider: `quickSuggestionsProvider` é um `StreamProvider.family`
  que mapeia o stream de `getTransactions` — não aninhe um `StreamProvider` dentro de um `Provider`.
- **Não** criar entries manualmente no sheet: delegue a `CreateTransaction`/repository.
- Em transferência, `toAccountId` deve ser preenchido e diferente da origem; categoria/entidade são nulas.

# Citations

[1] [Contabilidade de Partida Dobrada](../architecture/double-entry.md)
[2] [Transações](transactions.md)
