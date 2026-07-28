---
type: Task
id: "30"
title: "Reconciliação de Contas"
status: done
timestamp: 2026-07-26T13:00:00Z
---

# Reconciliação de Contas

Fluxo para confirmar que o saldo no app bate com o extrato bancário real.

## Subtarefas

- [x] Adicionar coluna `reconciled_at` em `entries`
- [x] Criar tabela `reconciliation_checkpoints`
- [x] Migração v18
- [x] Criar ReconciliationDao (watchByAccount, insertCheckpoint, deleteCheckpoint)
- [x] Criar ReconciliationEntryTile widget
- [x] Criar ReconciliationScreen
- [x] Adicionar botão "Reconciliar" no AccountDetailScreen
- [x] Adicionar rota /accounts/:id/reconcile
