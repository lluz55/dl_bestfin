---
type: Concept
title: "Onboarding & Tutorial"
description: "Fluxo inicial de 6 steps para configuração do app + sistema de coach marks pós-onboarding para descoberta de features."
tags: [onboarding, tutorial, ux, setup]
related: [security, dashboard, notifications]
timestamp: 2026-07-01T00:00:00Z
---

## O Que É

Dois sistemas distintos de orientação ao usuário:

1. **Onboarding** (`/onboarding`): wizard de 6 passos executado uma única vez antes do usuário entrar no app. Configura conta, categorias, notificações, IA e segurança.

2. **Tutorial de Coach Marks**: overlay de spotlight que aparece uma vez após o onboarding, no primeiro carregamento do Dashboard. Destaca as 3 principais descobertas: FAB, personalização e aba Mais.

## Fontes de código

```
lib/features/onboarding/presentation/
  screens/
    onboarding_screen.dart          # PageView com 6 steps
  widgets/
    welcome_step.dart               # Step 0 — boas-vindas (animações flutter_animate)
    create_account_step.dart        # Step 1 — criação da primeira conta
    select_categories_step.dart     # Step 2 — confirmação de categorias padrão
    notification_permission_step.dart  # Step 3 — permissão de notificações (real no Android)
    ai_step.dart                    # Step 4 — download do modelo LLM
    security_step.dart              # Step 5 — biometria + PIN
    tutorial_runner.dart            # Coach marks pós-onboarding
  providers/
    onboarding_provider.dart        # onboardingCompletedProvider + biometricsEnabledProvider
    tutorial_provider.dart          # tutorialSeenProvider + TutorialKeys + TutorialActions
```

## Ordem dos 6 Steps

| Index | Widget | Dados coletados | Skip? |
|---|---|---|---|
| 0 | `WelcomeStep` | nenhum | não |
| 1 | `CreateAccountStep` | nome, tipo, cor, ícone, saldo inicial | não |
| 2 | `SelectCategoriesStep` | nenhum (informativo) | sim |
| 3 | `NotificationPermissionStep` | permissão SO (Android only) | sim |
| 4 | `AiStep` | modelo selecionado + download opcional | sim |
| 5 | `SecurityStep` | biometria_enabled (bool) | sim |

**"Pular" do step 2 em diante chama `OnboardingActions.complete(ref)` imediatamente** — router guard redireciona para `/home`.

## Persistência

Dual-write: `SharedPreferences` + tabela `AppSettings` no Drift (chave/valor).

Chaves:
- `onboarding_completed` → `onboardingCompletedProvider`
- `biometrics_enabled` → `biometricsEnabledProvider`
- `tutorial_seen` → `tutorialSeenProvider`
- `onboarding_step` → `initialOnboardingStep` (só SharedPreferences)
- `onboarding_account_draft` → `onboardingAccountDraftProvider` (JSON com o formulário do step 1; espelhado em memória para restauração síncrona ao navegar entre steps)

Todos lidos antes de `runApp()` em `main.dart` para bootstrap síncrono.

**Retomada de progresso:** o step atual do wizard é persistido em
`onboarding_step` a cada `onPageChanged` e removido em
`OnboardingActions.complete()`. Se o SO matar o processo no meio do setup, o
`PageController` retoma do step salvo — sem isso o usuário refaria tudo
(inclusive a conta do step 1, que já foi criada no banco).

## Tutorial Coach Marks

Pacote: `tutorial_coach_mark ^1.3.3`

**Arquitetura de GlobalKeys:**

```dart
// tutorial_provider.dart
class TutorialKeys {
  final fabKey = GlobalKey();         // GlobalFAB widget
  final maisTabKey = GlobalKey();     // 4ª aba do bottom nav (Expanded)
}
final tutorialKeysProvider = Provider<TutorialKeys>((_) => TutorialKeys());
```

- `AppShell` lê `tutorialKeysProvider` → passa `fabKey` para `GlobalFAB(key:...)` e `maisTabKey` para `ResponsiveNavigation(lastDestinationKey:...)`
- `DashboardScreen` cria `_customizeKey` local → passa tudo para `TutorialRunner`

**3 Coach Marks:**

| # | Target | Mensagem |
|---|---|---|
| 1 | FAB | "Registre movimentações — gastos, receitas ou transferências em segundos." |
| 2 | Ícone ⚙️ (personalizar) | "Personalize seu início — reorganize ou oculte os cards do dashboard." |
| 3 | Aba "Mais" | "Explore tudo — orçamentos, metas, investimentos, IA e muito mais." |

Targets com `GlobalKey.currentContext == null` são filtrados antes de exibir.

## Erros comuns de agente

- **Não inicializar `initialTutorialSeen` antes de `runApp()`** → provider seed errado, tutorial não dispara.
- **Usar `tutorialKeysProvider` em dois lugares diferentes esperando GlobalKeys distintas** → Provider é um singleton em Riverpod; sempre retorna a mesma instância.
- **Não filtrar targets inválidos** → `tutorial_coach_mark` pode crashar se `keyTarget.currentContext` for null.
- **Pular step em `OnboardingScreen`**: "Pular" chama `_finish()` (completa onboarding), não `_nextPage()`. Comportamento intencional.
- **Resetar o wizard sem limpar `onboarding_step`** → o usuário volta no meio de um onboarding "novo". Ao zerar o onboarding (ex.: limpar todos os dados), zere também a chave, `initialOnboardingStep` e `initialOnboardingAccountDraft` (+ invalidar `onboardingAccountDraftProvider`).
- **Push de rota durante o onboarding** → o guard do router rebate para `/onboarding` qualquer rota fora da allowlist (`/security/pin-setup`, `/categories/new`, rotas `/sync/*` de auth). Se um step precisar abrir outra tela por push, adicione a rota à allowlist `isOnboardingSubflow` em `app_router.dart`, senão o usuário é jogado de volta ao wizard.
- **A conta do step 1 NÃO é criada no step** — o formulário só grava o rascunho (`onboardingAccountDraftProvider`); a criação acontece uma única vez em `OnboardingScreen._finish()` (inclusive quando o usuário "Pula"). Se o onboarding for abandonado, nada é gravado no banco. `DuplicateAccountNameException` no finish é engolida de propósito (conta homônima pode ter vindo do sync).
- **Permissões de notificação no Android são DUAS**: `requestAndroidNotificationPermission()` (POST_NOTIFICATIONS — exibir lembretes, diálogo do sistema) e `AndroidNotificationService.requestPermission()` (listener de captura — abre as configurações do SO). O `NotificationPermissionStep` pede as duas, nessa ordem.
