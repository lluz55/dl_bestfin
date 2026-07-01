---
type: Feature
title: Parcelamentos
description: Planos de parcelamento de compras com wizard de criação e timeline de compromissos futuros.
tags: [parcelamento, parcelas, compra, wizard, compromissos]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite registrar compras parceladas (ex: TV em 12x) gerando automaticamente as transações futuras de cada parcela.

## Modelo

`InstallmentPlan` — `domain/models/installment_plan.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/installments_list_screen.dart` | Lista de parcelamentos ativos |
| `screens/installment_wizard_screen.dart` | Wizard de criação (valor, parcelas, data) |

## Widgets

| Arquivo | Propósito |
|---|---|
| `widgets/installment_progress_widget.dart` | Progresso de parcelas pagas/restantes |
| `widgets/future_commitments_timeline.dart` | Timeline de compromissos futuros |

## Dependências

- [Transações](transactions.md) — cada parcela é uma transação
- [Cartões de Crédito](credit-cards.md) — parcelamento no cartão
- [Contas](accounts.md) — conta de débito
