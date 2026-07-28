---
type: Task
title: "Refatorar 'god files' (sync_service, transaction_repository)"
description: "Quebrar arquivos com responsabilidades demais em sub-serviços/estratégias coesos para facilitar teste e navegação por agentes."
tags: [tech-debt, architecture, refactor, maintainability]
timestamp: 2026-07-26T14:00:00Z
status: done
progress: 4/4
---

## Descrição

Alguns arquivos concentram responsabilidades demais, dificultando teste unitário e navegação:

| Arquivo | Linhas |
|---|---|
| `lib/features/sync/data/services/sync_service.dart` | 1675 |
| `lib/features/transactions/data/repositories/transaction_repository.dart` | 1413 |
| `lib/features/transactions/presentation/screens/transaction_form_screen.dart` | 1357 |
| `lib/features/backup/domain/usecases/export_pdf.dart` | 1187 |
| `lib/features/sync/data/services/nostr_sync_service.dart` | 1182 |

Refatorar preservando comportamento e cobertura de teste (ver `sync_service_test.dart`,
`transaction_repository_test.dart`). Extrair estratégias/sub-serviços por responsabilidade.

## Checklist

- [x] Mapear responsabilidades de `sync_service.dart` e propor decomposição
- [x] Extrair sub-serviços de `sync_service.dart` mantendo testes verdes
- [x] Decompor `transaction_repository.dart` (queries vs. mutações vs. double-entry)
- [x] `flutter analyze` e `flutter test` verdes após refactor

## Notas de implementação

**`sync_service.dart` (1675 → 879 linhas).** As três responsabilidades eram
push/fila (`enqueue`, `processSyncQueue`, `_ensureBackfill`), pull/merge
(`pullRemoteChanges` + os 12 `_mergeXFromRemote`) e orquestração (`syncNow`). O
maior e mais coeso bloco — a aplicação de registros remotos ao Drift
(last-write-wins por entidade, ~770 linhas) — foi extraído para
`RemoteEntityMerger` (`remote_entity_merger.dart`, 828 linhas). `pullRemoteChanges`
agora delega via `_merger.apply(entityType, row)` (retorna `false` para tipos não
suportados, preservando o `continue` que não contava o registro). `_fkOrNull`
(resolução defensiva de FKs) foi junto; `_isSupportedEntity` ficou no
`SyncService` pois também é usado no caminho de push.

**`transaction_repository.dart` (1413 → ~1330 linhas).** O cache read-side da
árvore enriquecida de categorias (Future cacheado + duas assinaturas de
invalidação + `_build`) foi extraído para `EnrichedCategoryCache`
(`enriched_category_cache.dart`), consumido pelos 4 streams de leitura via
`_categoryCache.load()`. **Decisão deliberada:** o caminho de escrita
(`_insertTransactionRecords` + `_updateGoalProgress`/`_applyGoalAutoAbsorption` +
`_enqueueTransactionSync`) foi mantido coeso — esses helpers são transversais a
create/update/delete e tocam a invariante de partida dobrada (ver AGENTS.md);
fatiá-los traria risco alto ao núcleo financeiro para ganho pequeno. A separação
"queries vs. mutações" foi obtida extraindo o suporte de query (cache), sem mexer
no motor de double-entry.

`transaction_form_screen.dart`, `export_pdf.dart` e `nostr_sync_service.dart`
seguem grandes, mas fora do escopo desta task (foco nos dois arquivos com
cobertura de teste que servem de rede de segurança).

**Verificação:** `flutter analyze` limpo (0 issues) e `flutter test` verde
(173 testes) após o refactor.
