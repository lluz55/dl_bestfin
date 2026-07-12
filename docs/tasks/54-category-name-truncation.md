---
type: Task
title: "Priorizar nome da categoria sobre tags de tipo/sistema quando há truncamento"
description: "Em listas de categorias, quando o nome completo não couber, remover tags de tipo e sistema para priorizar o nome da categoria em vez de truncá-lo."
tags: [categories, ui, ux, truncation, badges]
timestamp: 2026-07-12T00:00:00Z
status: completed
progress: 3/3
---

## Descrição

Em telas de categorias, quando o nome da categoria é truncado (não cabe no espaço disponível), as tags de tipo (Receita/Despesa) e "Sistema" competem por espaço com o nome. O comportamento deve ser: remover as tags quando não couber o nome completo, priorizando a exibição do nome.

## Arquivos Modificados

- `lib/core/widgets/name_with_badges.dart` — NOVO: widget compartilhado `NameWithOptionalBadges` que detecta truncamento via `LayoutBuilder` + `TextPainter` e condicionalmente mostra as badges
- `lib/features/categories/presentation/widgets/category_tile.dart` — Substituído `_TypeBadge` e badges inline por `NameWithOptionalBadges` em `_TileRow` e `_SubcategoryTile`
- `lib/features/categories/presentation/widgets/category_detail_panel.dart` — Substituído badges inline por `NameWithOptionalBadges` em `_SubcategoriesSection`; badges do `_Header` são escondidas quando nome excede 2 linhas
- `lib/core/widgets/category_picker.dart` — Substituído title/subtitle por `_TitleWithOptionalSubtitle` que esconde o subtitle quando o `displayName` é truncado

## Checklist

- [x] Criar widget `NameWithOptionalBadges` compartilhado
- [x] Aplicar em `_TileRow` de `category_tile.dart`
- [x] Aplicar em `_SubcategoryTile` de `category_tile.dart`
- [x] Aplicar em `_Header` de `category_detail_panel.dart`
- [x] Aplicar em `_SubcategoriesSection` de `category_detail_panel.dart`
- [x] Aplicar em `_CategoryPickerTile` de `category_picker.dart`
- [x] `flutter analyze` sem erros
- [x] `flutter test` passando (173/173)
