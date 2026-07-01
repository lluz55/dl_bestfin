---
type: Feature
title: Metas Financeiras
description: Metas com progresso, simulador mensal e celebração ao atingir o objetivo.
tags: [metas, objetivos, poupança, progresso]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite criar metas financeiras (ex: "Viagem — R$ 5.000 até dezembro") e acompanhar o progresso com contribuições manuais ou automáticas.

## Modelo

`Goal` — `lib/features/goals/domain/models/goal.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/goals_list_screen.dart` | Lista de metas com progresso |
| `screens/goal_form_screen.dart` | Criação/edição |
| `screens/goal_detail_screen.dart` | Detalhe com histórico de contribuições |

## Widgets

| Arquivo | Propósito |
|---|---|
| `widgets/progress_ring_widget.dart` | Anel de progresso animado |
| `widgets/monthly_simulator_widget.dart` | Simulador: quanto poupar por mês para atingir |
| `widgets/goal_celebration_widget.dart` | Animação de celebração ao completar |
| `widgets/goal_category_selector.dart` | Vincula categorias à meta |

## Use Cases

- `create_goal.dart`
- `add_contribution.dart`
- `calculate_monthly_target.dart` — simula valor mensal necessário

## Dependências

- [Dashboard](dashboard.md) — widget de progresso de metas
- [Transações](transactions.md) — contribuições são transações direcionadas à meta
