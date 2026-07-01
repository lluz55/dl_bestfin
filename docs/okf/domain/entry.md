---
type: Domain Model
title: Entry (Lançamento)
description: Perna individual de uma transação de partida dobrada; carrega o valor monetário real.
tags: [domínio, entry, double-entry, lançamento]
timestamp: 2026-06-29T00:00:00Z
---

## Definição

`Entry` é uma perna de uma [Transação](transaction.md). É onde o valor monetário efetivamente está. Toda transação produz pelo menos dois `Entry`: um débito e um crédito.

## Campos

| Campo | Tipo | Descrição |
|---|---|---|
| `transactionId` | String | FK para Transaction |
| `accountId` | String | FK para [Conta](account.md) afetada |
| `amountInCents` | int | Valor em centavos (sempre positivo) |
| `type` | EntryType | `debit` \| `credit` |

## Invariante

```
SUM(entries WHERE type=debit AND transactionId=X) ==
SUM(entries WHERE type=credit AND transactionId=X)
```

Esta igualdade deve ser validada **antes** de persistir qualquer transação.

## Arquivos

- `lib/features/transactions/domain/models/entry.dart` — modelo de domínio
- `lib/core/database/tables/entries.dart` — tabela Drift
- `lib/core/database/daos/transactions_dao.dart` — inclui queries sobre entries

# Citations

[1] [Contabilidade de Partida Dobrada](../architecture/double-entry.md)
[2] [Transação](transaction.md)
