---
type: Task
id: "31"
title: "Split de Transações"
status: in_progress
timestamp: 2026-07-01T00:00:00Z
---

# Split de Transações

Permite dividir uma única transação entre múltiplas categorias.

## Subtarefas

- [x] Adicionar coluna `is_split` em `transactions`
- [x] Criar tabela `transaction_splits`
- [x] Migração v18
- [x] Criar SplitEntry domain model
- [x] Atualizar TransactionModel (isSplit, splits fields)
- [x] Atualizar TransactionRepository (createTransaction + splits)
- [x] Criar SplitEditorSheet (modal bottom sheet)
- [x] Atualizar TransactionFormScreen (botão + estado de splits na página 1)
- [ ] Indicador de split no StaggeredTransactionList (opcional — backlog)
