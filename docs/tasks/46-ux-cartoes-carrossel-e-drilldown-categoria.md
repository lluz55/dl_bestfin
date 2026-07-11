---
type: Task
id: "46"
title: Correções UX — Carrossel de Cartões e Drill-down de Categoria na Home
status: completed
timestamp: 2026-07-11T00:00:00Z
---

# Tarefa 46 — Carrossel de Cartões e Drill-down de Categoria

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** [09-credit-cards](./09-credit-cards.md), [07-dashboard](./07-dashboard.md), [06-transactions](./06-transactions.md)

---

## Descrição

Duas melhorias de UX pedidas pelo usuário:

1. **Tela "Meus Cartões":** os cartões devem ficar "enfileirados". Antes eram
   uma lista vertical (`ListView.separated`) com cada cartão + barra de limite
   empilhados. Agora são um **carrossel horizontal** (`PageView`) com páginas
   adjacentes espiando nas bordas; a barra de limite (`LimitBarWidget`) aparece
   abaixo, referente ao cartão atualmente selecionado, com indicador de páginas
   (dots).
2. **Home — componentes informativos de categoria:** ao tocar numa categoria no
   donut "Distribuição de Gastos" ou no "Ranking de Categorias", o usuário é
   levado à aba **Transações** já filtrada por aquela categoria
   (`transactionFiltersProvider` com `categoryId`).

---

## Subtarefas

 - [x] `CreditCardsListScreen` convertida para `ConsumerStatefulWidget` com
   `PageController(viewportFraction: 0.88)` e `_selectedIndex`; `PageView.builder`
   horizontal, `onPageChanged` atualiza o selecionado (clamp para sobreviver à
   remoção de um cartão)
 - [x] `LimitBarWidget` do cartão selecionado renderizado abaixo do carrossel,
   com card de borda e fade ao trocar de página; indicador de páginas `_PageDots`
   (dot ativo alongado) quando há mais de um cartão
 - [x] Toque no cartão continua abrindo o detalhe (`/credit-cards/:id`)
 - [x] Helper `goToTransactionsForCategory` (novo
   `dashboard/presentation/utils/category_navigation.dart`) — seta o filtro só
   com a categoria e faz `context.go('/transactions')`
 - [x] `SpendingDonut` → `ConsumerStatefulWidget`; itens da legenda com categoria
   viram `InkWell` que navega via helper (itens "Sem Categoria" não navegam)
 - [x] `CategoryBarChartWidget` ganha `onBarTap(index)` opcional (não-tocável por
   padrão, preservando as telas de relatório); `CategoryRankingWidgetWrapper` →
   `ConsumerWidget` e passa `onBarTap` resolvendo `items[index].category?.id`
 - [x] `flutter analyze` sem novos erros/warnings/infos nos arquivos tocados
