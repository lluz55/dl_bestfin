---
type: Architecture Pattern
title: Contabilidade de Partida Dobrada
description: Invariante central do domínio — toda transação tem débito igual a crédito.
tags: [double-entry, domínio, contabilidade, invariante]
timestamp: 2026-06-29T00:00:00Z
---

## Invariante

**Toda transação financeira** no BestFin é composta por pelo menos **dois lançamentos (Entry)**:
- Um ou mais lançamentos de **débito** (saída de valor de uma conta)
- Um ou mais lançamentos de **crédito** (entrada de valor em outra conta)

`SUM(débitos) == SUM(créditos)` — validado antes de persistir. Violar essa regra é um bug crítico que corrompe todos os saldos.

## Modelos Envolvidos

- [`Transaction`](../domain/transaction.md) — entidade raiz; contém metadados (data, descrição, categoria)
- [`Entry`](../domain/entry.md) — perna da transação; tem `accountId`, `amountInCents` e `type` (debit/credit)

## Exemplos de Fluxo

### Despesa simples (R$ 50 no supermercado)
```
Transaction: type=expense, description="Supermercado", category=Alimentação
  Entry 1: account=Carteira, type=credit, amount=5000   ← sai da carteira
  Entry 2: account=Despesas, type=debit,  amount=5000   ← entra na categoria de despesa
```

### Transferência entre contas (R$ 200 da corrente para poupança)
```
Transaction: type=transfer
  Entry 1: account=Corrente,  type=credit, amount=20000  ← sai da corrente
  Entry 2: account=Poupança,  type=debit,  amount=20000  ← entra na poupança
```

### Receita (salário R$ 3.200)
```
Transaction: type=income, description="Salário", category=Renda
  Entry 1: account=Receitas, type=credit, amount=320000  ← sai da fonte de receita
  Entry 2: account=Corrente, type=debit,  amount=320000  ← entra na conta corrente
```

## Onde Validar

A validação `SUM(débitos) == SUM(créditos)` **deve ocorrer em `domain/use_cases/`** antes de chamar o repository. Nunca validar apenas na UI — o banco pode ser populado por importação, sincronização ou testes.

## Arquivos Chave

- `lib/core/database/tables/entries.dart` — tabela Entry
- `lib/core/database/tables/transactions.dart` — tabela Transaction
- `lib/features/transactions/domain/usecases/create_transaction.dart` — use case com validação
- `lib/features/transactions/domain/usecases/update_transaction.dart`
- `lib/features/transactions/domain/usecases/delete_transaction.dart`
