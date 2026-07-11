---
type: Task
id: "49"
title: Remoção dos FABs Secundários — Ação Principal no AppBar
status: completed
timestamp: 2026-07-11T00:00:00Z
---

# Tarefa 49 — Remoção dos FABs Secundários

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** [34-button-standardization](./34-button-standardization.md)

---

## Descrição

O app tinha 9 telas com FAB próprio (`ExpressiveFAB.extended`) competindo
visualmente com o FAB global de adicionar transação (`GlobalFAB` no
`AppShell`). Decisão: **apenas o FAB principal de transação permanece**; a
ação principal de cada tela migra para um `IconButton` (`Icons.add_rounded`
com tooltip) nas `actions` do `AppPageAppBar` — mesmo padrão que o Hub de
Assinaturas já usava.

---

## Subtarefas

 - [x] `accounts_list_screen.dart` — FAB "Nova Conta" → IconButton no AppBar
 - [x] `portfolio_screen.dart` — FAB "Novo Ativo" → IconButton no AppBar
 - [x] `recurring_list_screen.dart` — FAB "Nova" → IconButton ao lado do
   atalho do Hub de Assinaturas
 - [x] `goals_list_screen.dart` — FAB "Nova Meta" → IconButton no AppBar
 - [x] `categories_screen.dart` — FAB "Nova Categoria" → IconButton ao lado
   do botão de reordenação
 - [x] `credit_cards_list_screen.dart` — FAB "Novo Cartão" → IconButton no
   AppBar
 - [x] `subscriptions_hub_screen.dart` — FAB removido (o AppBar já tinha o
   botão "+" de nova recorrência; era redundante)
 - [x] `budgets_list_screen.dart` — FAB "Novo envelope" → IconButton ao lado
   do botão de rollover
 - [x] `financing_list_screen.dart` — FAB "Novo Contrato" → IconButton no
   AppBar
 - [x] Imports de `expressive_fab.dart` removidos das 9 telas

---

## Critérios de Aceitação

 - [x] `flutter analyze` sem erros/warnings novos
 - [x] `flutter test` — 165 testes passando
 - [x] Nenhum `floatingActionButton:` em `lib/features/**` — o único FAB do
   app é o `GlobalFAB` em `lib/core/shell/app_shell.dart`
 - [x] Empty states mantêm seus botões de ação próprios (inalterados)

---

## Notas e Considerações

> [!NOTE]
> `ExpressiveFAB` (`lib/core/widgets/expressive_fab.dart`) ficou sem uso em
> produção — só o widget e seu teste permanecem. Mantido como componente do
> design system; remover em um follow-up se continuar órfão.
