---
type: Task
id: "38"
title: "Inserção de Lançamentos em Bulk"
status: done
timestamp: 2026-07-09T19:15:00Z
---

# Inserção de Lançamentos em Bulk ("Inserir Vários")

Permite cadastrar vários lançamentos de uma vez compartilhando cabeçalho
(tipo, pagador/recebedor, conta(s), data, status pendente/confirmada) com
descrição, valor e categoria variando por linha, exibidos em tabela.
Salvamento tudo-ou-nada em uma única transação de banco.

## Subtarefas

- [x] Criar `BulkTransactionItem` domain model
- [x] Refatorar `TransactionRepositoryImpl.createTransaction` extraindo `_insertTransactionRecords`
- [x] Adicionar `createTransactionsBulk` (tudo-ou-nada, side effects pós-commit)
- [x] Criar use case `CreateTransactionsBulk` com validações de domínio
- [x] Adicionar `createTransactionsBulkProvider`
- [x] Criar `BulkTransactionScreen` (cabeçalho compartilhado + tabela de linhas)
- [x] Aplicação em massa: categoria e valor nas linhas selecionadas/todas
- [x] Rota `/transaction/bulk-new` + opção "Inserir Vários" no GlobalFAB
- [x] Testes unitários (`test/features/transactions/bulk_create_test.dart`)
- [x] Atualizar docs OKF (`docs/okf/features/transactions.md`)

## Refinamentos pós-review

- [x] Cap de 12 dígitos no keypad de valor (evita overflow do `int.parse` → 0 silencioso)
- [x] "Aplicar valor em massa" só grava ao confirmar (sheet retorna via `Navigator.pop`); cancelar não sobrescreve as linhas
- [x] `Dismissible` remove a linha por referência do objeto, não por índice capturado
- [x] Iniciar com 2 linhas (antes 3) e botão explícito "remover linha" por linha (além do swipe)

## Extensão: agrupamento de lançamentos

- [x] Coluna `transactions.groupId` + índice `transactions_group_idx` (schema v23 + migration)
- [x] `groupId` no `TransactionModel`, `BulkTransactionItem`, repositório e payload de sync (repo + backfill + merge)
- [x] Toggle "Agrupar em um só lançamento" no cabeçalho da inserção em massa
- [x] `collapseTransactionGroups` (usecase puro) + colapso em `groupedTransactionsProvider`
- [x] `GroupedTransactionTile` (mostra só o total, selo de destaque) na lista principal
- [x] `TransactionGroupScreen` (`/transaction/group/:groupId`) — edita/exclui cada membro
- [x] Ícone de pilha no `TransactionTile` quando `isGrouped` (destaque em qualquer lista)
- [x] Ícone de relógio reservado a transações futuras (agendadas); pendências vencidas usam alerta
- [x] Testes: persistência do `groupId` + preservação no update, colapso de grupos

## Alinhamento com o padrão de criar/editar transações

- [x] Keypad de valor unificado: `AmountKeypadSheet` público em `amount_input.dart` (com cap de 12 dígitos), usado pelo `AmountInput` e pela inserção em massa; cópia local removida
- [x] Botão "Data e Hora" extraído para `widgets/date_time_button.dart` e compartilhado entre formulário e inserção em massa; bulk agora seleciona data **e hora** como o formulário
- [x] Descrição por linha usa o mesmo `DescriptionAutocomplete` do formulário (sugestões por histórico), em decoração compacta (novos params `decoration`/`style`/`textCapitalization`)
- [x] Chrome do sheet extraído para `showLimitedTransactionSheet` (em `transaction_form_modal_overlay.dart`): fundo transparente, cantos 28, altura máx. 65% da tela — usado pelo formulário, pela inserção em massa e pela edição de bloco
- [x] `showBulkTransactionModal`: inserção em massa abre no mesmo padrão modal do formulário (sheet limitado no mobile, painel adaptativo no desktop); GlobalFAB usa o modal e a rota `/transaction/bulk-new` vira fallback
- [x] `showTransactionGroupModal`: edição de bloco agrupado abre no mesmo padrão modal (tile da lista usa o modal; rota `/transaction/group/:groupId` vira fallback)
- [x] `BulkTransactionScreen`/`TransactionGroupScreen` ganham `onClose` (mesmo contrato do formulário): sem AppBar em modal, botão "Cancelar" no rodapé com confirmação de descarte
