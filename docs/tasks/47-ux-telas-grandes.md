---
type: Task
id: "47"
title: UX — Transações, Relatórios e Mais otimizadas para telas grandes
status: completed
timestamp: 2026-07-11T00:00:00Z
---

# Tarefa 47 — Layouts para telas grandes (Transações, Relatórios, Mais)

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** [06-transactions](./06-transactions.md), [13-reports](./13-reports.md), [08-navigation-and-onboarding](./08-navigation-and-onboarding.md)

---

## Descrição

As telas Transações, Relatórios e Mais apenas esticavam o layout mobile em
telas grandes (Linux Desktop / tablets), desperdiçando o espaço horizontal.
Usando a infra existente (`Breakpoints` em `lib/core/theme/breakpoints.dart`),
cada tela ganhou um layout próprio para telas médias (≥600px) e expandidas
(≥840px), sem alterar nada no compact (mobile):

1. **Transações** (`transactions_list_screen.dart`): em telas expandidas o
   resumo do período (Receitas/Despesas/Saldo) sai da rolagem e vira painel
   lateral fixo (340px) **à esquerda**, com a lista logo após (máx. 800px),
   tudo alinhado à esquerda. Em telas médias, coluna única alinhada à
   esquerda (800px).
2. **Relatórios** (`reports_hub_screen.dart`): em telas expandidas o hub vira
   **master-detail** — lista de relatórios à esquerda (300px, tiles com ícone,
   título e descrição) e o relatório selecionado aberto à direita com os
   filtros no topo, sem push de página. Grid adaptativo + push mantidos no
   mobile/tablet.
3. **Mais** (`more_screen.dart`): em telas médias e expandidas vira
   **master-detail** — menu de itens à esquerda (300px, seções de lista antes
   das de cards) e a tela do item selecionado embutida à direita
   (`_MoreMasterDetail`; item padrão: Sugestões). Os itens são modelados como
   `_MoreItem` (rota para push no mobile + `buildScreen` para embutir no
   painel); `KeyedSubtree` descarta o estado ao trocar de item. Se a área útil
   for < 640px, degrada para o menu em coluna única (listas antes dos cards,
   máx. 600px, alinhado à esquerda). No compact o menu original
   (cards → listas, com push) é mantido.

---

## Subtarefas

 - [x] `_PeriodSummaryCard` extraído do sliver inline; renderizado inline no
   compact/médio e como painel lateral no expandido
 - [x] Lista de transações centralizada com `ConstrainedBox(maxWidth: 800)`
   em telas médias e expandidas; seleção múltipla/swipe/empty/error intactos
 - [x] `_ReportsMasterDetail` + `_ReportNavTile` no hub de relatórios;
   `KeyedSubtree` reseta o estado do conteúdo ao trocar de relatório;
   `ReportFiltersWidget` compartilhado no topo do painel direito
 - [x] `MoreScreen` refatorada para dados (`_MoreSection`/`_MoreItem`) com
   `_MenuColumnBody` (mobile/fallback) e `_MoreMasterDetail` + `_MasterNavTile`
   (telas médias/grandes); `_SectionHeader` lê tema do context
 - [x] `nix develop -c flutter analyze` — sem novos issues nos arquivos tocados
 - [x] `nix develop -c flutter test` — 165 testes verdes
