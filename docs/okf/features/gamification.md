---
type: Feature
title: Gamificação
description: Sistema de streaks de lançamentos diários e badges de conquistas para engajamento.
tags: [gamificação, streak, badges, conquistas, engajamento]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Mantém o usuário engajado com streaks (sequências de dias com lançamentos) e badges (conquistas desbloqueadas por comportamentos financeiros positivos).

## Modelos

- `Streak` — `domain/models/streak.dart`
- `Badge` — `domain/models/badge.dart`

## Serviços

| Arquivo | Propósito |
|---|---|
| `domain/services/gamification_service.dart` | Orquestra streak e badges |
| `domain/services/badge_checker.dart` | Verifica condições de desbloqueio de badges |
| `domain/services/insights_service.dart` | Gera insights baseados em comportamento |

## Inicialização

`GamificationService.onAppStarted()` é chamado em `main.dart` (`initState`) para atualizar o streak e verificar novos badges.

## Widgets

| Arquivo | Propósito |
|---|---|
| `widgets/badge_unlock_overlay.dart` | Overlay global de animação de desbloqueio |
| `widgets/streaks_dashboard_widget.dart` | Widget do dashboard com streak atual |

## Tela

`screens/gamification_hub_screen.dart` — exibe streak atual, badges conquistados e bloqueados.

## Integração

O `BadgeUnlockOverlay` envolve toda a árvore de widgets (em `main.dart`) para poder mostrar a animação de desbloqueio em qualquer tela.

## Dependências

- [Transações](transactions.md) — criar transação atualiza streak
- [Dashboard](dashboard.md) — widget de streak
