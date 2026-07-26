---
type: Feature
title: Relatórios
description: Hub de relatórios com Sankey, waterfall, heatmap, fluxo de caixa e patrimônio líquido.
tags: [relatórios, gráficos, sankey, fluxo-de-caixa, patrimônio]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Geração de relatórios financeiros avançados para análise de gastos, evolução do patrimônio e fluxo de caixa.

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/reports_hub_screen.dart` | Hub com acesso a todos os relatórios |
| `screens/monthly_report_screen.dart` | Relatório mensal com comparativos |
| `screens/category_report_screen.dart` | Gastos por categoria com drill-down |
| `screens/cash_flow_screen.dart` | Fluxo de caixa projetado |
| `screens/net_worth_screen.dart` | Evolução do patrimônio líquido |
| `screens/sankey_screen.dart` | Diagrama Sankey de fluxo de dinheiro |

## Widgets de Gráfico

| Arquivo | Propósito |
|---|---|
| `widgets/bar_chart_widget.dart` | Barras (mensal, comparativo) |
| `widgets/line_chart_widget.dart` | Linha (patrimônio, tendências) |
| `widgets/donut_chart_widget.dart` | Donut (categorias, contas) |
| `widgets/waterfall_chart_widget.dart` | Waterfall (receita − despesas = saldo) |
| `widgets/heatmap_widget.dart` | Heatmap de dias com mais gastos |
| `widgets/sankey_widget.dart` | Diagrama Sankey |
| `widgets/treemap_widget.dart` | Treemap de categorias |
| `widgets/report_filters_widget.dart` | Filtros de período e conta |

## Use Cases

- `generate_monthly_report.dart`
- `generate_category_report.dart`
- `generate_cash_flow.dart`
- `generate_net_worth.dart`
- `generate_sankey_report.dart`

## Funcionalidade Planejada

**A4 — Narrador de Relatório** (Task 25): transforma gráficos em texto narrativo via LLM. Provider: `llm_report_narrator_provider.dart` (não implementado).

## Dependências

- [Transações](transactions.md) — dados base
- [Contas](accounts.md) — patrimônio e saldos
- [Investimentos](investments.md) — incluso no patrimônio
