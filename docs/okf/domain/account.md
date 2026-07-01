---
type: Domain Model
title: Account (Conta)
description: Conta financeira do usuário; saldo calculado a partir dos lançamentos (Entries).
tags: [domínio, conta, account, saldo]
timestamp: 2026-06-29T00:00:00Z
---

## Definição

`Account` representa uma conta financeira do usuário (corrente, poupança, carteira de dinheiro, etc.). O saldo não é armazenado diretamente — é derivado dos [lançamentos (Entry)](entry.md) associados.

## Tipos de Conta

Definidos em `lib/core/constants/account_types.dart`:

| Tipo | Descrição |
|---|---|
| `checking` | Conta corrente bancária |
| `savings` | Conta poupança |
| `wallet` | Carteira de dinheiro físico |
| `investment` | Conta de investimento |
| `credit` | Cartão de crédito (passivo) |
| `loan` | Empréstimo/financiamento (passivo) |

## Campos

| Campo | Tipo | Descrição |
|---|---|---|
| `uuid` | String | Identificador único |
| `name` | String | Nome da conta |
| `type` | AccountType | Tipo da conta |
| `icon` | String | Nome do ícone Material |
| `color` | int | Cor em ARGB |
| `initialBalanceInCents` | int | Saldo inicial ao criar a conta |
| `isArchived` | bool | Conta arquivada (não aparece na UI principal) |

## Cálculo de Saldo

Saldo atual = `initialBalance + SUM(entries WHERE type=debit) - SUM(entries WHERE type=credit)`.

Use case de referência: `lib/features/accounts/domain/usecases/get_account_balance.dart`.

## Arquivos

- `lib/features/accounts/domain/models/account.dart`
- `lib/core/database/tables/accounts.dart`
- `lib/core/database/daos/accounts_dao.dart`
- `lib/features/accounts/data/repositories/account_repository.dart`
- `lib/features/accounts/presentation/providers/accounts_provider.dart`

## Relações

- Uma conta recebe/emite [Entries](entry.md) de [Transações](transaction.md).
- Pode ter [Cartão de Crédito](../features/credit-cards.md) vinculado.
- É referenciada por [Recorrências](../features/recurring.md) e [Metas](../features/goals.md).
