---
type: Feature
title: Segurança
description: Autenticação biométrica, PIN local e lock overlay para proteger dados financeiros.
tags: [segurança, biometria, pin, lock, autenticação]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Protege o app com autenticação biométrica (impressão digital, face ID) e PIN local de 4 dígitos. Ativa automaticamente após 60s de background.

## Comportamento

- **Primeira abertura**: usuário configura PIN e biometria no onboarding.
- **Background > 60s**: ao retornar ao app, `LockOverlay` é exibido. O timer é verificado em `didChangeAppLifecycleState` em `main.dart`.
- **Lock overlay**: cobre toda a árvore de widgets — implementado como wrapper global.

## Providers

| Provider | Arquivo |
|---|---|
| `isLockedProvider` | `presentation/providers/security_provider.dart` |
| `biometricsEnabledProvider` | idem |

## Telas e Widgets

| Arquivo | Propósito |
|---|---|
| `screens/app_lock_screen.dart` | Tela de desbloqueio |
| `screens/pin_setup_screen.dart` | Configuração do PIN |
| `widgets/lock_overlay.dart` | Overlay global — wraps a árvore inteira |
| `widgets/pin_input_widget.dart` | Input do PIN com feedback visual |

## Armazenamento Seguro

PIN e credenciais de biometria → `flutter_secure_storage`. **Nunca** em `SharedPreferences` ou SQLite.

## Integração

`LockOverlay` é inserido em `main.dart` como wrapper do `MaterialApp.router`. `BadgeUnlockOverlay` está fora do `LockOverlay` para garantir que a animação de badge não apareça durante o lock.

## Dependências

- [Sincronização](sync.md) — credenciais do backend também em `flutter_secure_storage`
