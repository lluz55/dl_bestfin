---
type: Task
id: "42"
title: Tutorial ampliado, atalhos na barra lateral e limpeza do header
status: completed
timestamp: 2026-07-09T00:00:00Z
---

# Tarefa 42 — Tutorial ampliado, atalhos na barra lateral e limpeza do header

> **Fase:** 3 — UX Polish
> **Prioridade:** 🟡 Alta
> **Estimativa:** Média
> **Última atualização:** 2026-07-09

## Descrição

Três melhorias de descoberta e navegação:

1. **Tutorial interativo ampliado** — os coach marks pós-onboarding passam a
   percorrer as funcionalidades mais relevantes (FAB, personalização, aba
   Transações, aba Relatórios, aba Mais) e podem ser reexibidos a qualquer
   momento via Configurações → Ajuda → "Rever tutorial".
2. **Atalhos na barra lateral** — nas telas com barra lateral (tablet/desktop),
   o usuário fixa funcionalidades da página "Mais" como atalhos, exibidos
   abaixo das abas principais após um separador.
3. **Remoção da troca de tema da tela inicial** — o botão de aparência sai do
   header do dashboard (o tema continua acessível em Configurações → Aparência).

## Pré-requisitos

| Tarefa | Descrição | Status |
|--------|-----------|--------|
| [33-onboarding-tutorial](./33-onboarding-tutorial.md) | Coach marks pós-onboarding | ✅ Concluída |
| [08-navigation-and-onboarding](./08-navigation-and-onboarding.md) | Navegação responsiva | ✅ Concluída |

## Subtarefas

### Tutorial

- [x] `TutorialKeys`: adicionar `transactionsTabKey` e `reportsTabKey`
- [x] `ResponsiveNavigation`: trocar `lastDestinationKey` por `destinationKeys`
      (`List<GlobalKey?>?`) e aplicar por índice no `_AnimatedBottomBar`
- [x] `AppShell`: passar `destinationKeys` (null, transações, relatórios, mais)
- [x] `TutorialRunner`: 5 coach marks; relançar quando `tutorialSeenProvider`
      vai de `true → false` (via `ref.listen`), com guarda `_showing`
- [x] Avanço passo a passo por botões (contador "Passo X de N", Próximo/Concluir,
      Pular), com `enableTargetTab/OverlayTab: false` e `hideSkip: true` — sem
      pular tudo por engano; passos numerados após filtrar targets sem contexto
- [x] Passo 1 hands-on: `onCreateTransaction` abre o `QuickTransactionSheet` real
      (`DashboardScreen._runTransactionDemo`) e avança ao fechar
- [x] `TutorialActions.reset(ref)` — limpa a flag e marca provider como não visto
- [x] `SettingsScreen`: seção "Ajuda" com tile "Rever tutorial" → `reset` + `go('/home')`
- [x] `_clearAllData`: resetar `initialTutorialSeen`/`tutorialSeenProvider` e
      invalidar `sidebarShortcutsProvider`

### Atalhos na barra lateral

- [x] `lib/core/shell/nav_shortcut.dart` — catálogo `NavShortcut` (itens roteáveis da página "Mais")
- [x] `lib/core/providers/sidebar_shortcuts_provider.dart` — `AsyncNotifier` persistido em `SharedPreferences`
- [x] `lib/core/shell/sidebar_shortcuts_edit_sheet.dart` — modal para fixar/remover atalhos
- [x] `responsive_navigation.dart` — seções `_SidebarShortcuts` / `_CollapsedSidebarShortcuts`
      inseridas após as abas nos três drawers, precedidas de um `Divider`
- [x] Persistir atalhos na tabela `AppSettings` (Drift), não em `SharedPreferences`,
      para entrarem no backup JSON (`app_settings`); provider observa `databaseProvider`
      e se reconstrói após restauração/limpeza

### Abrir atalhos só na área de conteúdo (barra lateral persistente)

- [x] `lib/core/shell/detail_shell.dart` — em telas largas renderiza a barra
      lateral persistente + página só no conteúdo; em mobile, passa a página direto
- [x] `app_shell.dart` — expõe `destinations` e `tabRoutes` (usados pelo `DetailShell`)
- [x] `app_router.dart` — `ShellRoute` envolvendo as páginas de feature do hub
      "Mais" (rotas e `push('/...')` inalterados); auth do sync, PIN e `/categories/new`
      seguem em tela cheia fora do shell

### Header

- [x] `dashboard_screen.dart` — remover `_TonalIconButton` de aparência, o callback
      `onTheme` e o import `theme_settings_sheet.dart`

## Critérios de Aceitação

- [x] `flutter analyze` sem novos avisos
- [x] Coach marks percorrem FAB → personalizar → Transações → Relatórios → Mais no mobile
- [x] Avanço passo a passo por botão "Próximo" (não exige "Pular" para seguir)
- [x] Passo 1 abre o fluxo real de nova transação como demonstração
- [x] "Rever tutorial" reexibe os coach marks no dashboard
- [x] Atalhos aparecem abaixo de "Mais" após um separador e são configuráveis
- [x] Atalhos entram no backup JSON e voltam após restauração
- [x] Em tablet/desktop, abrir um atalho mantém a barra lateral e abre só no conteúdo
- [x] Header do dashboard não tem mais botão de tema

## Arquivos Principais

```
lib/core/shell/nav_shortcut.dart                         # novo — catálogo
lib/core/shell/sidebar_shortcuts_edit_sheet.dart         # novo — modal
lib/core/providers/sidebar_shortcuts_provider.dart       # novo — persistência
lib/core/shell/responsive_navigation.dart                # seções de atalho + destinationKeys
lib/core/shell/app_shell.dart                            # destinationKeys
lib/features/onboarding/presentation/providers/tutorial_provider.dart   # keys + reset
lib/features/onboarding/presentation/widgets/tutorial_runner.dart       # 5 targets + relançar
lib/features/dashboard/dashboard_screen.dart             # remove tema; passa keys
lib/features/settings/presentation/screens/settings_screen.dart         # "Rever tutorial"
```

## Notas e Considerações

- Os coach marks das abas (Transações/Relatórios/Mais) só têm alvo no layout
  compacto — as `destinationKeys` só são ligadas ao `_AnimatedBottomBar`. Em
  tablet/desktop os alvos com `currentContext == null` são filtrados, então o
  tutorial degrada para FAB + personalizar sem quebrar.
- Atalhos usam `context.push(route)`; o catálogo `NavShortcut` só contém rotas
  reais (funcionalidades da página "Mais"). Relatórios específicos não são
  roteáveis hoje (o hub navega internamente), por isso ficaram fora do catálogo.
- A ordem dos atalhos salvos segue o catálogo (`NavShortcut.values`) para
  consistência visual, independentemente da ordem de seleção.
