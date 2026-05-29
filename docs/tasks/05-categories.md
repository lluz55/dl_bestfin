# Tarefa 05 — Categorias e Subcategorias

**Fase:** 1 — Fundação
**Prioridade:** 🔴 Crítica
**Pré-requisitos:** 02-design-system, 03-database-setup

Descrição: Implementar categorias hierárquicas (2 níveis) com ícones Material, cores personalizáveis, categorias padrão e UI interativa.

Subtarefas:
 - [x] Criar `lib/features/categories/domain/models/category.dart`: model com children e parent
 - [x] Criar `lib/features/categories/data/repositories/category_repository.dart`: CRUD via DAO, tree building
 - [x] Criar `lib/features/categories/domain/usecases/`: create_category, update_category, delete_category, get_categories_tree, reorder_categories
 - [x] Criar `lib/features/categories/presentation/providers/categories_provider.dart`: providers com tree structure
 - [x] Criar `lib/features/categories/presentation/screens/categories_screen.dart`: árvore visual com categorias e subcategorias, expansíveis
 - [x] Criar `lib/features/categories/presentation/screens/category_form_screen.dart`: formulário com nome, tipo (income/expense/both), ícone (picker), cor (picker), parent (selector)
 - [x] Criar `lib/features/categories/presentation/widgets/category_tree.dart`: widget de árvore com drag-and-drop para reordenar
 - [x] Criar `lib/features/categories/presentation/widgets/category_tile.dart`: tile com ícone colorido + expand/collapse
 - [x] Criar `lib/core/widgets/category_picker.dart`: grid de categorias para seleção no formulário de transação (ícones em grid, busca, recently used)
 - [x] Criar `lib/core/widgets/category_icon.dart`: widget de ícone de categoria (container colorido + ícone)
 - [x] Proteger categorias `is_system=true` contra deleção
 - [x] Ao deletar categoria com transações: dialog para reclassificar
 - [x] Filtrar categorias por tipo (income/expense) quando relevante

Aceitação:
- Categorias hierárquicas (máx 2 níveis) funcionando
- Categorias padrão pré-carregadas (conforme SPEC)
- Ícone e cor personalizáveis
- Reordenação via drag-and-drop
- Category picker funcional (grid de ícones + busca)
- Categorias do sistema protegidas
- Filtro por tipo (income/expense) funcional

Arquivos:
- `lib/features/categories/domain/models/category.dart`
- `lib/features/categories/data/repositories/category_repository.dart`
- `lib/features/categories/domain/usecases/*.dart`
- `lib/features/categories/presentation/**/*.dart`
- `lib/core/widgets/category_picker.dart`
- `lib/core/widgets/category_icon.dart`
