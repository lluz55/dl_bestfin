# Tarefa 45 — Otimizações de performance na camada de dados ✅

> **Fase:** 3 — Refinamentos
> **Prioridade:** 🟡 Alta
> **Estimativa:** Pequena
> **Última atualização:** 2026-07-10

## Descrição

Auditoria de performance identificou trabalho redundante no caminho quente dos
streams de transação (Dashboard, lista de Transações e Relatórios, todos
assinantes de `watchAllTransactions`/`watchTransactionsWithFilters`). Três
correções localizadas e de baixo risco, sem mudança de schema nem de arquitetura:

1. **Memoização do mapa enriquecido de categorias.** `_loadEnrichedCategoriesMap`
   era reconstruído (query de categorias + relacionamentos + montagem recursiva
   da árvore pai/filho) a **cada emissão** de cada stream de transação. Agora o
   Future é cacheado e invalidado apenas quando as tabelas `categories` /
   `category_parents` mudam.
2. **Membros de grupo filtrados no banco.** `transactionGroupMembersProvider`
   carregava a tabela inteira via `watchAllTransactions()` e filtrava `groupId`
   em Dart. Passa a filtrar no SQL (índice `transactions_group_idx`) via novo
   parâmetro `groupId` de `watchTransactionsWithFilters`.
3. **Fim do N+1 em `_enrichRules` (recorrências).** Eram 3 queries por regra
   (base tx, categoria, entry). Agora são 3 queries no total, em lote com `IN`.

## Subtarefas

### 1. Memoização de categorias (`transaction_repository.dart`) ✅

- [x] Campo `_enrichedCategoriesFuture` + subscriptions de invalidação em
      `watchAllCategories()` e `watchAllRelationships()`.
- [x] `_loadEnrichedCategoriesMap` retorna o Future cacheado; construção movida
      para `_buildEnrichedCategoriesMap` (dedupa builds concorrentes).
- [x] `dispose()` cancela as subscriptions; ligado via `ref.onDispose` no
      `transactionRepositoryProvider`.

### 2. Filtro de grupo no banco ✅

- [x] Parâmetro `groupId` adicionado à interface e à impl de
      `watchTransactionsWithFilters`.
- [x] `transactionGroupMembersProvider` usa `watchTransactionsWithFilters(groupId:)`.

### 3. Batch em `_enrichRules` (`recurring_repository.dart`) ✅

- [x] Carga em lote de transações-base, categorias e entries via `IN`, indexadas
      por id; primeira entry por transação preserva a semântica do `limit(1)`.

### 4. Testes e Validação ✅

- [x] `flutter analyze` nos arquivos alterados sem novos issues.
- [x] `flutter test` verde em transactions, dashboard e daos (categorias/transações).

## Notas

- **Fora de escopo (registrado, não implementado):** (a) explosão de linhas no
  join com `entries` (~2 linhas por transação) em `watchAllTransactions` — remover
  o join quebraria a reatividade a edições que só tocam `entries`; (b) o full-scan
  do Dashboard que reagrega todas as transações no isolate da UI a cada gravação —
  é refatoração de médio prazo (agregação em SQL com `GROUP BY` ou em isolate).
</content>
</invoke>
