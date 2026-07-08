---
type: Task
id: "36"
title: Onboarding — PIN acessível, persistência total e categorias
status: completed
timestamp: 2026-07-07T00:00:00Z
---

# Tarefa 36 — Melhorias no Onboarding

**Fase:** 3 — UX Polish
**Prioridade:** 🔴 Crítica (PIN inacessível bloqueava o step de segurança)
**Pré-requisitos:** [35-ux-fixes-batch-julho](./35-ux-fixes-batch-julho.md), [08-navigation-and-onboarding](./08-navigation-and-onboarding.md)

---

## Descrição

Três correções/melhorias no wizard de onboarding:

1. **Biometria/PIN configurável**: o guard do router rebatia qualquer rota
   para `/onboarding` enquanto o setup não estivesse completo — o push de
   `/security/pin-setup` feito pelo `SecurityStep` era redirecionado e o
   usuário voltava ao início do wizard. O guard agora tem uma allowlist de
   sub-fluxos do onboarding (`/security/pin-setup`, `/categories/new`).

2. **Persistência ao voltar step / sair do app**: além do índice do step
   (Tarefa 35), o formulário do step de conta vive em
   `onboardingAccountDraftProvider` (em memória, restauração síncrona ao
   navegar entre steps) espelhado em `onboarding_account_draft` nas prefs
   (sobrevive à morte do processo). Seed lido antes de `runApp()`.

3. **Novas categorias no onboarding**: botão "Nova categoria" no
   `SelectCategoriesStep` abre o `CategoryFormScreen` existente por push;
   a lista recarrega ao retornar.

4. **Conta criada só na finalização** (revisão pós-feedback): o step 1 não
   grava nada no banco — `OnboardingScreen._finish()` cria a conta a partir
   do rascunho (também no "Pular" e no fluxo de sync), com guard de dupla
   execução e `DuplicateAccountNameException` tolerada (conta pode ter vindo
   do sync). Abandonar o onboarding não deixa lixo no banco.

5. **Notificações no Android**: o step de notificações pedia apenas o acesso
   de leitura (captura); agora pede também `POST_NOTIFICATIONS` (exibir
   notificações, Android 13+) via `requestAndroidNotificationPermission()`.

---

## Subtarefas

 - [x] Allowlist `isOnboardingSubflow` no redirect do `app_router.dart`
 - [x] `createWithInitialBalance` retorna o id da conta (repo + usecase)
 - [x] `OnboardingAccountDraft` + `onboardingAccountDraftProvider` (seed
   síncrono via `initialOnboardingAccountDraft` antes de `runApp()`)
 - [x] `CreateAccountStep` sem escrita no banco: restaura rascunho no
   `initState` (síncrono), `_saveDraft()` em todos os campos
 - [x] Criação da conta em `OnboardingScreen._finish()` com guard
   `_finishing` e tolerância a `DuplicateAccountNameException`
 - [x] Limpeza do rascunho em `complete()` e no "Limpar todos os dados"
 - [x] `NotificationPermissionStep` pede POST_NOTIFICATIONS + listener
 - [x] Botão "Nova categoria" no `SelectCategoriesStep` com invalidação de
   `categoriesTreeProvider`
 - [x] Drift: fechar a conexão antiga antes de `invalidate(databaseProvider)`
   no clear-all e no restore JSON (aviso de múltiplas instâncias + corrida)
 - [x] "Limpar todos os dados" de fato apaga: `signOut()` do sync ANTES do
   wipe (senão o onboarding re-sincroniza tudo dos relays e "nada é apagado")
   + tabelas que faltavam na deleção (budgets, transactionSplits,
   scheduledReminders, goalCategories, reconciliationCheckpoints,
   categoryParents, chatMessages, syncQueue, nostrEventLog) + aviso de
   desconexão do sync no diálogo de confirmação
 - [x] `flutter analyze` limpo; suite passa (mesma falha pré-existente da
   Tarefa 35 em `sync_queue_integration_test`)
