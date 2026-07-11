---
type: Task
id: "52"
title: "Padronização dos modais bottom sheet em telas pequenas e grandes"
status: completed
priority: medium
tags: [ux, modais, bottom-sheet, design-system]
timestamp: 2026-07-11T12:00:00Z
---

# Tarefa 52 — Padronização dos modais bottom sheet

**Fase:** UX / Design System
**Prioridade:** 🟡 Média
**Estimativa:** Média
**Última atualização:** 2026-07-11

## Descrição

Padronizar todos os modais bottom sheet do app usando como base o padrão do
formulário de adicionar/editar transação:

- **Mobile (compact):** bottom sheet com fundo transparente, cantos
  arredondados de 28 no topo e altura limitada a 65% da tela.
- **Telas grandes:** painel adaptativo flutuante no canto inferior direito
  (`AdaptiveModalPanel`, 480px de largura máx.).

O chrome padrão passa a viver em um único helper de core
(`showAppBottomSheet` em `lib/core/utils/adaptive_modal.dart`), usado pelo
`showAdaptiveModal` (que decide sheet × painel pelo breakpoint) e pelo
`showLimitedTransactionSheet`. Todos os callsites crus de
`showModalBottomSheet` migram para `showAdaptiveModal`.

## Sub-tarefas

- [x] Helper `showAppBottomSheet` com o chrome padrão em `core/utils/adaptive_modal.dart`; `showAdaptiveModal` passa a aplicá-lo no mobile
- [x] `showLimitedTransactionSheet` delega ao helper de core (sem duplicar chrome)
- [x] Overlays de formulário (cartão, financiamento, investimento, meta) usam o helper em vez de chrome inline duplicado
- [x] Filtros de transações (tipo, contas, cartões, categoria) migrados — sem `DraggableScrollableSheet`
- [x] Filtros de relatórios (período, contas, cartões, tipo, categoria) migrados — chrome inline removido
- [x] Sheets de exclusão de transação (parcela, recorrente base, ocorrência) migrados
- [x] Configurações (perfil, antecedência de lembrete, conta padrão) migrados
- [x] Pickers de core (categoria, subcategoria, multi-seleção, ícone/cor, seletor de conta, entidade) migrados com chrome interno removido
- [x] Demais sheets (calendário de período, wizards de parcelamento/recorrência, split, orçamento, ícone de meta) migrados
- [x] `flutter analyze` e `flutter test` limpos nos arquivos da tarefa (erros restantes são pré-existentes em telas fora do escopo — `accounts_list_screen`, `categories_screen`, `credit_cards_list_screen`, `cashflow_screen`, `installments_list_screen`, `category_detail_panel` — trabalho em progresso de outra frente que impede `widget_test.dart` de compilar)

## Referências

- [[transactions]] — padrão base (formulário individual, bulk e grupo)
- `lib/features/transactions/presentation/widgets/transaction_form_modal_overlay.dart`
- `lib/core/widgets/adaptive_modal_panel.dart`
