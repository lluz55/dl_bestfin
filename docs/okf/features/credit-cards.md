---
type: Feature
title: Cartões de Crédito
description: Gestão de cartões com faturas, limite, timeline e visualização de cartão virtual.
tags: [cartão-de-crédito, fatura, limite, invoice]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Gerencia cartões de crédito e suas faturas mensais. Transações lançadas na conta do tipo `credit` são automaticamente associadas à fatura aberta.

## Modelos

- `CreditCard` — `lib/features/credit_cards/domain/models/credit_card.dart`
- `Invoice` — `lib/features/credit_cards/domain/models/invoice.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/credit_cards_list_screen.dart` | Lista de cartões |
| `screens/credit_card_form_screen.dart` | Criação/edição |
| `screens/credit_card_detail_screen.dart` | Detalhe com faturas e limite |
| `screens/invoice_detail_screen.dart` | Transações da fatura |

## Widgets

| Arquivo | Propósito |
|---|---|
| `widgets/credit_card_visual_widget.dart` | Cartão virtual animado |
| `widgets/invoice_timeline_widget.dart` | Timeline de faturas anteriores |
| `widgets/limit_bar_widget.dart` | Barra de uso do limite |

## Fechamento de Fatura

Faturas são criadas automaticamente. O dia de fechamento e vencimento são configurados no cartão. A fatura aberta agrega todas as transações do período.

## Dependências

- [Contas](accounts.md) — conta do tipo `credit` representa o cartão
- [Transações](transactions.md) — transações da fatura
- [Parcelamentos](installments.md) — compras parceladas no cartão
