---
type: Task
id: "33"
title: Onboarding & Tutorial Inicial
status: completed
timestamp: 2026-07-01T00:00:00Z
---

# Tarefa 33 — Onboarding & Tutorial Inicial

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** 08-navigation-and-onboarding

Descrição: Corrigir bugs do fluxo de onboarding existente e adicionar um tutorial de coach marks pós-onboarding para descoberta das principais features.

## Subtarefas

### Parte 1 — Correção de Bugs

- [x] **NotificationPermissionStep** → converter para `ConsumerStatefulWidget`, chamar `androidNotificationServiceProvider.requestPermission()` no botão "Habilitar"; mostrar info banner no Linux
- [x] **SelectCategoriesStep** → substituir `error: (_, __) => const SizedBox()` por widget de erro com retry
- [x] **CreateAccountStep** → adicionar `_colorCustomized` bool; só resetar cor ao trocar tipo quando usuário não personalizou
- [x] **SecurityStep** → atualizar label para "Ativar Biometria e PIN" e subtítulo com menção ao PIN de fallback

### Parte 2 — Tutorial Coach Marks

- [x] Criar `lib/features/onboarding/presentation/providers/tutorial_provider.dart` — `TutorialKeys`, `tutorialSeenProvider`, `TutorialActions.markSeen/readSeen`
- [x] Criar `lib/features/onboarding/presentation/widgets/tutorial_runner.dart` — `TutorialRunner` (`ConsumerStatefulWidget`) com 3 coach marks: FAB → Customize → Mais tab
- [x] Adicionar `tutorial_coach_mark: ^1.3.3` ao `pubspec.yaml`
- [x] `main.dart` → ler `initialTutorialSeen` antes de `runApp`
- [x] `responsive_navigation.dart` → adicionar `lastDestinationKey` e thread para `_AnimatedBottomBar`
- [x] `app_shell.dart` → ler `tutorialKeysProvider`, passar `fabKey` e `maisTabKey`
- [x] `dashboard_screen.dart` → adicionar `_customizeKey`, `super.key` em `_TonalIconButton`, integrar `TutorialRunner`

### Parte 3 — OKF

- [x] Criar `docs/tasks/33-onboarding-tutorial.md`
- [x] Criar `docs/okf/features/onboarding.md`
- [x] Atualizar `docs/okf/index.md`

## Aceitação

- Onboarding completo de 6 steps funcional sem bugs
- Android: botão "Habilitar Notificações" solicita permissão real do SO
- Linux: passo de notificações exibe info banner (sem botão de habilitar)
- Ao trocar tipo de conta, cor customizada pelo usuário é preservada
- Botão de biometria exibe "Ativar Biometria e PIN"
- Após completar onboarding, 3 coach marks aparecem no dashboard: FAB → customize → aba Mais
- Após pular ou completar o tutorial, ele não reexibe
- `tutorial_seen` persistido em SharedPreferences

## Arquivos

- `pubspec.yaml`
- `lib/main.dart`
- `lib/core/shell/app_shell.dart`
- `lib/core/shell/responsive_navigation.dart`
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/features/onboarding/presentation/providers/tutorial_provider.dart` (novo)
- `lib/features/onboarding/presentation/widgets/tutorial_runner.dart` (novo)
- `lib/features/onboarding/presentation/widgets/notification_permission_step.dart`
- `lib/features/onboarding/presentation/widgets/select_categories_step.dart`
- `lib/features/onboarding/presentation/widgets/create_account_step.dart`
- `lib/features/onboarding/presentation/widgets/security_step.dart`
