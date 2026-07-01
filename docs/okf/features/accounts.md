---
type: Feature
title: Contas
description: Gestão de contas financeiras do usuário com cálculo de saldo derivado dos lançamentos.
tags: [contas, saldo, conta-corrente, poupança]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite criar, editar, arquivar e excluir contas financeiras. O saldo é calculado dinamicamente a partir dos lançamentos (Entries), não armazenado diretamente.

## Telas

| Arquivo | Propósito |
|---|---|
| `presentation/screens/accounts_list_screen.dart` | Lista de contas com saldos |
| `presentation/screens/account_form_screen.dart` | Criação/edição de conta |
| `presentation/screens/account_detail_screen.dart` | Detalhe com histórico de transações |

## Use Cases

- `create_account.dart`
- `update_account.dart`
- `delete_account.dart`
- `get_account_balance.dart` — soma entries para calcular saldo atual

## Conta Padrão

O usuário pode definir uma conta padrão que é pré-selecionada no formulário de transação. Gerenciada por `defaultAccountProvider` em `lib/core/providers/default_account_provider.dart`.

## Dependências

- [Domain Model: Conta](../domain/account.md)
- [Transações](transactions.md) — entries que afetam o saldo
- [Cartões de Crédito](credit-cards.md) — tipo de conta `credit`
