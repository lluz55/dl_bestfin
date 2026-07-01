---
type: Domain Model
title: Category (Categoria)
description: Categoria hierárquica de despesa ou receita; organizada em árvore com pai opcional.
tags: [domínio, categoria, árvore, classificação]
timestamp: 2026-06-29T00:00:00Z
---

## Definição

`Category` organiza transações em grupos semânticos (Alimentação, Transporte, Salário…). Suporta hierarquia de dois níveis: categoria pai → subcategorias filhas.

## Campos

| Campo | Tipo | Descrição |
|---|---|---|
| `uuid` | String | Identificador único |
| `name` | String | Nome exibido |
| `icon` | String | Nome do ícone Material |
| `color` | int | Cor ARGB |
| `type` | CategoryType | `expense` \| `income` \| `both` |
| `parentId` | String? | FK para categoria pai (null = raiz) |
| `sortOrder` | int | Posição na lista |
| `isDefault` | bool | Categoria do sistema (não excluível) |

## Estrutura de Árvore

- Categorias raiz: `parentId == null`.
- Subcategorias: `parentId != null`.
- A UI usa `CategoryTree` (`lib/features/categories/presentation/widgets/category_tree.dart`).
- Use case: `lib/features/categories/domain/usecases/get_categories_tree.dart`.

## Categorias Padrão

Definidas em `lib/core/constants/default_categories.dart` — criadas automaticamente no onboarding.

## Integração com LLM

O LLM usa a lista de categorias para auto-categorização de transações. O contexto financeiro é construído em `lib/features/llm/domain/services/financial_context_builder.dart`.

## Arquivos

- `lib/features/categories/domain/models/category.dart`
- `lib/core/database/tables/categories.dart`
- `lib/core/database/tables/category_parents.dart` — tabela de relação pai-filho
- `lib/core/database/daos/categories_dao.dart`
- `lib/features/categories/data/repositories/category_repository.dart`
- `lib/features/categories/presentation/providers/categories_provider.dart`
