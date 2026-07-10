---
type: Concept
title: "Onboarding & Tutorial"
description: "Fluxo inicial de 6 steps para configuração do app + sistema de coach marks pós-onboarding para descoberta de features."
tags: [onboarding, tutorial, ux, setup]
related: [security, dashboard, notifications]
timestamp: 2026-07-09T00:00:00Z
---

## O Que É

Dois sistemas distintos de orientação ao usuário:

1. **Onboarding** (`/onboarding`): wizard de 6 passos executado uma única vez antes do usuário entrar no app. Configura conta, categorias, notificações, IA e segurança.

2. **Tutorial de Coach Marks**: overlay de spotlight que aparece após o onboarding, no primeiro carregamento do Dashboard, e pode ser reexibido a qualquer momento em Configurações → Ajuda → "Rever tutorial". Percorre as funcionalidades mais relevantes: FAB, personalização do início, aba Transações, aba Relatórios e aba Mais.

## Fontes de código

```
lib/features/onboarding/presentation/
  screens/
    onboarding_screen.dart          # PageView com 6 steps
  widgets/
    welcome_step.dart               # Step 0 — boas-vindas (animações flutter_animate)
    profile_step.dart               # Step 1 — nome e foto do usuário (opcional)
    create_account_step.dart        # Step 2 — criação da primeira conta
    select_categories_step.dart     # Step 3 — confirmação de categorias padrão
    notification_permission_step.dart  # Step 4 — permissão de notificações (real no Android)
    security_step.dart              # Step 5 — biometria + PIN
    tutorial_runner.dart            # Coach marks pós-onboarding
  providers/
    onboarding_provider.dart        # onboardingCompletedProvider + biometricsEnabledProvider
    tutorial_provider.dart          # tutorialSeenProvider + TutorialKeys + TutorialActions (markSeen/readSeen/reset)
```

O tile "Rever tutorial" fica em `settings_screen.dart` (seção "Ajuda"): chama
`TutorialActions.reset(ref)` e `context.go('/home')`.

## Ordem dos 6 Steps

| Index | Widget | Dados coletados | Skip? |
|---|---|---|---|
| 0 | `WelcomeStep` | nenhum (atalhos: sync com outro dispositivo, restaurar backup) | não |
| 1 | `ProfileStep` | nome + foto (opcionais; gravam direto no `userProfileProvider`) | não* |
| 2 | `CreateAccountStep` | nome, tipo, cor, ícone, saldo inicial | não |
| 3 | `SelectCategoriesStep` | nenhum (informativo) | sim |
| 4 | `NotificationPermissionStep` | permissão SO (Android only) | sim |
| 5 | `SecurityStep` | biometria_enabled (bool) | sim |

\* O `ProfileStep` não tem o "Pular" do header (que encerraria o onboarding
inteiro) — os campos são opcionais e "Continuar" segue sempre adiante.

**"Pular" do step 3 em diante chama `OnboardingActions.complete(ref)` imediatamente** — router guard redireciona para `/home`.

**Restaurar backup no welcome:** `OnboardingScreen._restoreFromBackup()` aceita `.sqlite` (via `BackupDatabaseUseCase.restoreBackup`) ou `.json` (via `ImportDataUseCase.restoreJson`), invalida o `databaseProvider` e chama `OnboardingActions.complete(ref)` **direto** — não passa por `_finish()`, pois o backup já traz contas e a conta do rascunho do step 2 não deve ser criada.

## Persistência

Dual-write: `SharedPreferences` + tabela `AppSettings` no Drift (chave/valor).

Chaves:
- `onboarding_completed` → `onboardingCompletedProvider`
- `biometrics_enabled` → `biometricsEnabledProvider`
- `tutorial_seen` → `tutorialSeenProvider`
- `onboarding_step` → `initialOnboardingStep` (só SharedPreferences)
- `onboarding_account_draft` → `onboardingAccountDraftProvider` (JSON com o formulário do step de conta; espelhado em memória para restauração síncrona ao navegar entre steps)
- `user_name` / `user_photo_path` → `userProfileProvider` (`lib/core/providers/user_profile_provider.dart`; só SharedPreferences — a foto é copiada para o diretório de documentos do app)

Todos lidos antes de `runApp()` em `main.dart` para bootstrap síncrono.

**Retomada de progresso:** o step atual do wizard é persistido em
`onboarding_step` a cada `onPageChanged` e removido em
`OnboardingActions.complete()`. Se o SO matar o processo no meio do setup, o
`PageController` retoma do step salvo — sem isso o usuário refaria tudo
(inclusive a conta do step 2, cujo rascunho já foi preenchido).

## Tutorial Coach Marks

Pacote: `tutorial_coach_mark ^1.3.3`

**Arquitetura de GlobalKeys:**

```dart
// tutorial_provider.dart
class TutorialKeys {
  final fabKey = GlobalKey();               // GlobalFAB widget
  final transactionsTabKey = GlobalKey();   // 2ª aba do bottom nav
  final reportsTabKey = GlobalKey();        // 3ª aba do bottom nav
  final maisTabKey = GlobalKey();           // 4ª aba do bottom nav
}
final tutorialKeysProvider = Provider<TutorialKeys>((_) => TutorialKeys());
```

- `AppShell` lê `tutorialKeysProvider` → passa `fabKey` para `GlobalFAB(key:...)` e uma lista `destinationKeys: [null, transactionsTabKey, reportsTabKey, maisTabKey]` para `ResponsiveNavigation`. As chaves só são ligadas ao `_AnimatedBottomBar` (layout **compacto**); em tablet/desktop os alvos das abas ficam sem `currentContext` e são filtrados.
- `DashboardScreen` cria `_customizeKey` local → passa tudo para `TutorialRunner`

**5 Coach Marks (avanço passo a passo por botões):**

| # | Target | Mensagem | Ação |
|---|---|---|---|
| 1 | FAB | "Adicione uma transação — que tal criar a sua primeira agora?" | **hands-on**: "Criar transação" abre o `QuickTransactionSheet` real; "Depois" pula o passo |
| 2 | Ícone ⚙️ (personalizar) | "Personalize seu início — reorganize ou oculte os cards." | Próximo |
| 3 | Aba "Transações" | "Suas transações — histórico, filtros e edição." | Próximo |
| 4 | Aba "Relatórios" | "Análises e relatórios — categorias, fluxo de caixa, patrimônio." | Próximo |
| 5 | Aba "Mais" | "Explore tudo — orçamentos, metas, investimentos, cartões." | Concluir |

**Modelo de interação:** cada card tem contador "Passo X de N", botão **Próximo/Concluir**
e **Pular** (encerra o tutorial). O avanço é só pelos botões — `enableTargetTab: false`
e `enableOverlayTab: false` impedem que um toque acidental pule etapas; a skip nativa
fica escondida (`hideSkip: true`). Os passos são numerados **após** filtrar targets com
`currentContext == null` (as abas só têm chave no layout compacto), então o contador
reflete só os passos realmente exibidos.

**Demo prática (passo 1):** `TutorialRunner` recebe `onCreateTransaction` do
`DashboardScreen` (`_runTransactionDemo` → `showAdaptiveModal(QuickTransactionSheet)`).
O modal abre acima do overlay do coach mark (mesma `Overlay` do Navigator); ao fechar,
`_runDemo` chama `_coach.next()` para seguir. Guardas de `mounted` cobrem o `await`.

**Reexibição:** `TutorialRunner.build` faz `ref.listen(tutorialSeenProvider)`; quando a flag vai de `true → false` (via "Rever tutorial" ou "Limpar todos os dados"), relança os coach marks com a guarda `_showing` para não abrir duas vezes.

## Erros comuns de agente

- **Não inicializar `initialTutorialSeen` antes de `runApp()`** → provider seed errado, tutorial não dispara.
- **Usar `tutorialKeysProvider` em dois lugares diferentes esperando GlobalKeys distintas** → Provider é um singleton em Riverpod; sempre retorna a mesma instância.
- **Não filtrar targets inválidos** → `tutorial_coach_mark` pode crashar se `keyTarget.currentContext` for null.
- **Pular step em `OnboardingScreen`**: "Pular" chama `_finish()` (completa onboarding), não `_nextPage()`. Comportamento intencional.
- **Resetar o wizard sem limpar `onboarding_step`** → o usuário volta no meio de um onboarding "novo". Ao zerar o onboarding (ex.: limpar todos os dados), zere também a chave, `initialOnboardingStep` e `initialOnboardingAccountDraft` (+ invalidar `onboardingAccountDraftProvider`).
- **Push de rota durante o onboarding** → o guard do router rebate para `/onboarding` qualquer rota fora da allowlist (`/security/pin-setup`, `/categories/new`, rotas `/sync/*` de auth). Se um step precisar abrir outra tela por push, adicione a rota à allowlist `isOnboardingSubflow` em `app_router.dart`, senão o usuário é jogado de volta ao wizard.
- **A conta do step 2 NÃO é criada no step** — o formulário só grava o rascunho (`onboardingAccountDraftProvider`); a criação acontece uma única vez em `OnboardingScreen._finish()` (inclusive quando o usuário "Pula"). Se o onboarding for abandonado, nada é gravado no banco. `DuplicateAccountNameException` no finish é engolida de propósito (conta homônima pode ter vindo do sync).
- **Permissões de notificação no Android são DUAS**: `requestAndroidNotificationPermission()` (POST_NOTIFICATIONS — exibir lembretes, diálogo do sistema) e `AndroidNotificationService.requestPermission()` (listener de captura — abre as configurações do SO). O `NotificationPermissionStep` pede as duas, nessa ordem.
