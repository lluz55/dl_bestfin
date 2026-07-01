---
type: Feature
title: Notificações & Captura Automática
description: Leitura de notificações de apps bancários para sugerir transações automaticamente.
tags: [notificações, captura-automática, sugestões, android]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

No Android, lê notificações de apps bancários (Nubank, BB, Itaú…) via `NotificationListenerService` e extrai automaticamente dados de transações para apresentar como sugestões na fila de revisão.

## Como Funciona

1. App registra `NotiListenerService` (permissão especial do Android).
2. Notificação chega → `AndroidNotificationService` a intercepta.
3. `notification_parser.dart` tenta extrair valor, descrição e tipo com regex.
4. Padrões configuráveis em `NotificationPattern` (banco → regex → mapeamentos).
5. Sugestão criada como `TransactionSuggestion` e salva no banco.
6. Usuário revisa em `ReviewQueueScreen` e confirma ou descarta.

## Modelos

- `NotificationPattern` — `domain/models/notification_pattern.dart`
- `TransactionSuggestion` — `domain/models/transaction_suggestion.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/review_queue_screen.dart` | Fila de sugestões pendentes |
| `screens/notification_settings_screen.dart` | Configuração de padrões por banco |

## Widgets

| Arquivo | Propósito |
|---|---|
| `widgets/suggestion_card.dart` | Card de sugestão com ações aceitar/recusar |
| `widgets/pattern_editor.dart` | Editor de padrão regex por banco |

## Plataformas

| Plataforma | Suporte |
|---|---|
| Android | Completo (NotificationListenerService) |
| Linux | `linux_notification_service.dart` (D-Bus) |

## Dependências

- [Transações](transactions.md) — sugestão confirmada → cria transação
- [Categorias](categories.md) — mapeamento no padrão de notificação
- [Contas](accounts.md) — conta associada ao padrão do banco
