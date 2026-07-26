---
type: Feature
title: Categorias
description: Árvore hierárquica de categorias de despesa e receita com ícones e cores personalizáveis.
tags: [categorias, árvore, hierarquia, ícones]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Gerencia a árvore de categorias usada para classificar transações. Suporta dois níveis (pai/filho), reordenação por drag-and-drop e categorias padrão do sistema.

## Telas

| Arquivo | Propósito |
|---|---|
| `presentation/screens/categories_screen.dart` | Lista em árvore com reordenação |
| `presentation/screens/category_form_screen.dart` | Criação/edição com ícone e cor |

## Use Cases

- `create_category.dart`
- `update_category.dart`
- `delete_category.dart`
- `get_categories_tree.dart` — retorna árvore aninhada pai→filhos
- `reorder_categories.dart`
- `set_category_children.dart`

## Categorias Padrão

Criadas no onboarding via `lib/core/constants/default_categories.dart`. Marcadas com `isDefault=true` — não excluíveis pelo usuário.

## Dependências

- [Domain Model: Categoria](../domain/category.md)
- [Transações](transactions.md) — transações referenciam categoria
