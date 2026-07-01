---
type: Feature
title: Investimentos
description: Portfólio de investimentos com acompanhamento de rentabilidade e alocação.
tags: [investimentos, portfólio, rentabilidade, ativos]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite registrar e acompanhar investimentos (renda fixa, variável, fundos, criptomoedas) com visualização de alocação e rentabilidade.

## Modelo

`Investment` — `lib/features/investments/domain/models/investment.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/portfolio_screen.dart` | Visão geral do portfólio com alocação |
| `screens/investment_form_screen.dart` | Criação/edição de investimento |
| `screens/investment_detail_screen.dart` | Detalhe com histórico de preços |

## Dependências

- [Relatórios](reports.md) — incluídos no patrimônio líquido
- [Contas](accounts.md) — conta do tipo `investment` vinculada
