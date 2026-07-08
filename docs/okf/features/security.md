---
type: Feature
title: Segurança
description: Autenticação biométrica, PIN local e lock overlay para proteger dados financeiros.
tags: [segurança, biometria, pin, lock, autenticação]
timestamp: 2026-07-06T00:00:00Z
---

## Responsabilidade

Protege o app com autenticação biométrica (impressão digital, face ID) e PIN local de 4 dígitos. Ativa automaticamente após 60s de background.

## Comportamento

- **Primeira abertura**: usuário configura PIN e biometria no onboarding.
- **Background > 60s**: ao retornar ao app, `LockOverlay` é exibido. O timer é verificado em `didChangeAppLifecycleState` em `main.dart`.
- **Lock overlay**: cobre toda a árvore de widgets — implementado como wrapper global.

## Armadilha de agente

O `LockOverlay` deve **sobrepor** a tela de bloqueio ao conteúdo (Stack), nunca **substituir** a subárvore do app. Substituí-la desmonta todos os Navigators (raiz + branches do shell); se houver navegação em andamento no mesmo frame, o `NavigatorState.dispose` dispara o assert `!_debugLocked`, além de perder toda a pilha de rotas ao desbloquear. Enquanto bloqueado, o conteúdo fica atrás da tela opaca com toques, foco e semântica bloqueados (`IgnorePointer`/`ExcludeFocus`/`ExcludeSemantics`). Teste de regressão: `test/features/security/lock_overlay_test.dart`.

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

**Armadilha do `PinInputWidget`:** após `onComplete` o buffer interno continua
com 4 dígitos e o teclado deixa de aceitar entrada. Ao reutilizar o widget para
uma nova digitação (etapa de confirmação, fim de lockout), chame
`PinInputWidgetState.clear()` via GlobalKey — `shake()` também limpa, mas com
animação de erro. O widget aceita teclado físico (dígitos + backspace) via
`Focus` com autofocus, essencial no Linux desktop.

## Armazenamento Seguro

PIN e credenciais de biometria → `flutter_secure_storage`. **Nunca** em `SharedPreferences` ou SQLite.

## Integração

`LockOverlay` é inserido em `main.dart` como wrapper do `MaterialApp.router`. `BadgeUnlockOverlay` está fora do `LockOverlay` para garantir que a animação de badge não apareça durante o lock.

## Dependências

- [Sincronização](sync.md) — masterKey da identidade Nostr também cifrada em `flutter_secure_storage`
