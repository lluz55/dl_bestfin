---
type: Feature
title: Financiamentos
description: Controle de financiamentos (Price/SAC) com tabela de parcelas e amortização.
tags: [financiamento, parcelas, price, sac, amortização]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Gerencia financiamentos de longo prazo (imóvel, veículo) com geração automática da tabela de parcelas usando os sistemas Price ou SAC.

## Modelos

- `Financing` — `domain/models/financing.dart`
- `FinancingInstallment` — `domain/models/financing_installment.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/financing_list_screen.dart` | Lista de financiamentos |
| `screens/financing_form_screen.dart` | Criação com simulação de parcelas |
| `screens/financing_detail_screen.dart` | Tabela de amortização completa |

## Dependências

- [Transações](transactions.md) — parcelas pagas geram transações
- [Contas](accounts.md) — conta debitada no pagamento
