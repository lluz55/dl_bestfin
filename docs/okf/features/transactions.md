---
type: Feature
title: Transações
description: CRUD completo de transações financeiras com double-entry, filtros e busca.
tags: [transações, double-entry, crud, filtros]
timestamp: 2026-07-08T00:00:00Z
---

## Responsabilidade

Permite ao usuário registrar, editar, excluir e visualizar transações financeiras (despesas, receitas e transferências) com suporte a partida dobrada.

## Telas

| Arquivo | Propósito |
|---|---|
| `presentation/screens/transactions_list_screen.dart` | Lista paginada com filtros |
| `presentation/screens/transaction_form_screen.dart` | Formulário multi-passo (wizard) |
| `presentation/screens/bulk_transaction_screen.dart` | Inserção em massa **e edição de bloco**: cabeçalho compartilhado + tabela de linhas, salvamento tudo-ou-nada, opção de agrupar. Param `initialGroup` abre em modo de edição. Reusa os mesmos widgets do formulário individual (autocomplete de descrição, `AmountKeypadSheet`, `DateTimeButton`). Abre via `showBulkTransactionModal` no mesmo padrão modal do formulário (sheet limitado a 65% no mobile / painel no desktop); rota `/transaction/bulk-new` é fallback full-screen |
| `presentation/screens/transaction_group_screen.dart` | Loader do bloco agrupado: carrega os membros e abre a `BulkTransactionScreen` em modo de edição |

## Widgets Notáveis

| Arquivo | Propósito |
|---|---|
| `presentation/widgets/amount_input.dart` | Campo de valor monetário + `AmountKeypadSheet` (keypad modal compartilhado, cap de 12 dígitos) |
| `presentation/widgets/date_time_button.dart` | Botão "Data e Hora" em formato de card, compartilhado entre formulário e inserção em massa |
| `presentation/widgets/transaction_tile.dart` | Item da lista com swipe actions **e** menu ⋮ (marcar como pago quando pendente / duplicar / excluir) como alternativa ao gesto. Ícone de status só para não confirmadas (alerta = pendente vencida, relógio = agendada); confirmada é o estado neutro, sem ícone — inclusive sem check fixo na linha |
| `presentation/widgets/transaction_filters.dart` | Filtros por período, tipo, categoria |
| `presentation/widgets/delete_transaction_sheet.dart` | Sheet de exclusão com opções (só esta / todas recorrentes) |
| `presentation/widgets/description_autocomplete.dart` | Autocomplete de descrição por histórico |
| `presentation/widgets/grouped_transaction_tile.dart` | Tile de bloco agrupado: mostra só o total, com selo de destaque |

## Providers

| Provider | Arquivo |
|---|---|
| `transactionsProvider` | `presentation/providers/transactions_provider.dart` |
| `createTransactionProvider` | idem |
| `createTransactionsBulkProvider` | idem |
| `updateGroupedTransactionsProvider` | idem — edição de bloco (substitui os membros) |
| `updateTransactionProvider` | idem |
| `deleteTransactionProvider` | idem |
| `deleteTransactionsProvider` | idem — exclusão em massa (seleção múltipla) |

## Use Cases

- `create_transaction.dart` — valida double-entry e persiste `Transaction` + `Entry`s
- `create_transactions_bulk.dart` — valida o lote e insere N transações em uma única transação de banco (tudo-ou-nada)
- `update_grouped_transactions.dart` — edição de bloco: valida e substitui todos os membros do `groupId` (delete + reinsert atômico), recalculando saldos/metas
- `update_transaction.dart` — atualiza transaction e recria entries
- `delete_transaction.dart` — remove com opções para recorrentes (só esta / futuras / todas)
- `delete_transactions.dart` — exclui várias de uma vez (seleção em massa na lista)
- `get_transactions.dart` — busca com filtros de período, tipo, categoria, conta

## Dependências

- [Contas](accounts.md) — para selecionar conta de origem/destino
- [Categorias](categories.md) — para classificar a transação
- [LLM](llm.md) — auto-categorização via `llmCategorizeProvider`
- [Recorrências](recurring.md) — transações geradas automaticamente
- [Cartões](credit-cards.md) — lança na fatura do cartão quando conta é do tipo crédito
- [Gamificação](gamification.md) — atualiza streak ao criar transação

## Agrupamento de lançamentos (bulk agrupado)

Na inserção em massa, o toggle "Agrupar em um só lançamento" vem **ativado por
padrão** (`_groupTogether = true` em `bulk_transaction_screen.dart`); o usuário pode
desativá-lo. Todas as
linhas do lote recebem um `groupId` compartilhado (coluna `transactions.groupId`,
schema v23). O agrupamento é **apenas de exibição** — cada membro continua sendo uma
transação real com suas próprias entries (a partida dobrada e os saldos não mudam).

- **Colapso na lista:** `collapseTransactionGroups` (usecase puro) agrupa membros com o
  mesmo `groupId` em um `TransactionGroup`, exibido por `GroupedTransactionTile` mostrando
  só o **total**. Chamado dentro de `groupedTransactionsProvider`, por dia.
- **Detalhe/edição:** tocar no bloco chama `showTransactionGroupModal` — mesmo padrão
  de apresentação do formulário (bottom sheet limitado a 65% no mobile via
  `showLimitedTransactionSheet`, painel adaptativo no desktop). O `TransactionGroupScreen`
  carrega os membros (via `transactionGroupMembersProvider`) e abre a
  `BulkTransactionScreen` em modo de edição. A rota `/transaction/group/:groupId`
  permanece como fallback full-screen (deep link).
- **Destaque em qualquer lugar:** o `TransactionTile` compartilhado exibe um ícone de
  pilha quando `transaction.isGrouped`, então membros também aparecem destacados fora da
  lista principal (ex: recentes do dashboard).
- `groupId` é preservado no `updateTransaction` (o companion não o toca) e propagado no
  sync (payload `group_id` no repo e no backfill; merge desserializa `group_id`).

## Exclusão em massa (seleção múltipla)

A lista (`transactions_list_screen.dart`) suporta seleção múltipla para excluir
vários lançamentos de uma vez:

- **Entrar no modo:** long-press em qualquer tile (`TransactionTile` ou
  `GroupedTransactionTile`). Ambos ganharam `selectionMode`/`selected`/`onLongPress`.
- **Selecionar:** no modo de seleção, o toque alterna a seleção em vez de abrir; o
  swipe é desabilitado. Selecionar um bloco agrupado marca **todos os membros**.
- **Barra contextual:** a AppBar troca para contador + "selecionar tudo" + excluir.
  Um `PopScope` faz o botão voltar sair da seleção em vez da tela.
- **Confirmação e recálculo:** o botão excluir abre um `AlertDialog` de confirmação;
  ao confirmar, `deleteTransactionsProvider` → `repository.deleteTransactions(ids)`
  apaga tudo em **uma única transação de banco** (tudo-ou-nada), reutilizando
  `_deleteSingleTx` (desfaz impacto em metas, remove entries, enfileira sync). Os
  saldos das contas — derivados das entries via stream — e os totais do período
  recalculam sozinhos assim que o stream re-emite. Não há recálculo manual.

## Integração LLM

O formulário oferece auto-categorização: após preencher descrição, o `llmCategorizeProvider` sugere categoria. Implementado em `presentation/providers/llm_categorize_provider.dart`.

# Citations

[1] [Contabilidade de Partida Dobrada](../architecture/double-entry.md)
[2] [Domain Model: Transação](../domain/transaction.md)
