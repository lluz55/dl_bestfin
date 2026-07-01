---
type: Feature
title: Transações
description: CRUD completo de transações financeiras com double-entry, filtros e busca.
tags: [transações, double-entry, crud, filtros]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite ao usuário registrar, editar, excluir e visualizar transações financeiras (despesas, receitas e transferências) com suporte a partida dobrada.

## Telas

| Arquivo | Propósito |
|---|---|
| `presentation/screens/transactions_list_screen.dart` | Lista paginada com filtros |
| `presentation/screens/transaction_form_screen.dart` | Formulário multi-passo (wizard) |

## Widgets Notáveis

| Arquivo | Propósito |
|---|---|
| `presentation/widgets/amount_input.dart` | Teclado numérico de valor monetário |
| `presentation/widgets/transaction_tile.dart` | Item da lista com swipe actions |
| `presentation/widgets/transaction_filters.dart` | Filtros por período, tipo, categoria |
| `presentation/widgets/delete_transaction_sheet.dart` | Sheet de exclusão com opções (só esta / todas recorrentes) |
| `presentation/widgets/description_autocomplete.dart` | Autocomplete de descrição por histórico |

## Providers

| Provider | Arquivo |
|---|---|
| `transactionsProvider` | `presentation/providers/transactions_provider.dart` |
| `createTransactionProvider` | idem |
| `updateTransactionProvider` | idem |
| `deleteTransactionProvider` | idem |

## Use Cases

- `create_transaction.dart` — valida double-entry e persiste `Transaction` + `Entry`s
- `update_transaction.dart` — atualiza transaction e recria entries
- `delete_transaction.dart` — remove com opções para recorrentes (só esta / futuras / todas)
- `get_transactions.dart` — busca com filtros de período, tipo, categoria, conta

## Dependências

- [Contas](accounts.md) — para selecionar conta de origem/destino
- [Categorias](categories.md) — para classificar a transação
- [LLM](llm.md) — auto-categorização via `llmCategorizeProvider`
- [Recorrências](recurring.md) — transações geradas automaticamente
- [Cartões](credit-cards.md) — lança na fatura do cartão quando conta é do tipo crédito
- [Gamificação](gamification.md) — atualiza streak ao criar transação

## Integração LLM

O formulário oferece auto-categorização: após preencher descrição, o `llmCategorizeProvider` sugere categoria. Implementado em `presentation/providers/llm_categorize_provider.dart`.

# Citations

[1] [Contabilidade de Partida Dobrada](../architecture/double-entry.md)
[2] [Domain Model: Transação](../domain/transaction.md)
