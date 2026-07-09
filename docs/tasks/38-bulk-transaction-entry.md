---
type: Task
id: "38"
title: "Inserção de Lançamentos em Bulk"
status: done
timestamp: 2026-07-09T00:00:00Z
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
