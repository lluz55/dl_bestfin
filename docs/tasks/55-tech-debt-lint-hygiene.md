---
type: Task
title: "Higiene de dívida técnica — zerar lints e APIs deprecadas"
description: "Eliminar os 322 issues info do flutter analyze (auto-corrigíveis via dart fix), migrar APIs deprecadas (Radio) e adicionar gate --fatal-infos no CI para não regredir."
tags: [tech-debt, lint, analyze, ci, quality]
timestamp: 2026-07-26T12:00:00Z
status: completed
progress: 6/6
---

## Descrição

`flutter analyze` reporta **322 issues, todas nível `info`** (zero errors/warnings). A grande
maioria é auto-corrigível (`prefer_const_constructors`, `always_use_package_imports`,
`unnecessary_underscores`, `prefer_const_declarations`, `use_null_aware_elements`). Há também
uso de APIs deprecadas a partir do Flutter 3.32 que vão quebrar em bumps futuros.

Objetivo: deixar `flutter analyze` limpo e travar o CI com `--fatal-infos` para impedir regressão.

## Itens conhecidos

- `dart fix --apply` resolve a maioria dos lints de const/import/underscore.
- `lib/features/transactions/presentation/widgets/delete_transaction_sheet.dart` — `Radio`
  com `groupValue`/`onChanged` deprecados (após v3.32) → migrar para `RadioGroup`.
- Scripts (`scripts/generate_keypair.dart`, `scripts/publish_update.dart`) usam `print` —
  são scripts de CLI, avaliar `// ignore_for_file: avoid_print` ou logger dedicado.
- `unintended_html_in_doc_comment` em `publish_update.dart` — escapar `<...>` nos docs.

## Checklist

- [x] Rodar `dart fix --dry-run` e revisar o conjunto de mudanças propostas
- [x] Aplicar `dart fix --apply` (285 fixes em 92 arquivos) e revisar o diff
- [x] Migrar `Radio` deprecado em `delete_transaction_sheet.dart` para `RadioGroup`
- [x] Tratar lints remanescentes de scripts (print / html-in-doc)
- [x] `flutter analyze` sem nenhum issue (0) — `flutter test` verde (173/173)
- [x] Adicionar `flutter analyze --fatal-infos` ao workflow de CI (`.github/workflows/ci.yml`)

## Notas de implementação

- `dart fix` introduziu 2 **erros** (`final_not_initialized_constructor`) ao remover params
  usados (`unused_element_parameter`) de `_MoreItem.trailingBuilder` e `_AccountListTile.isInactive`.
  Os campos são lidos internamente, então os params foram **restaurados** com `// ignore:` local.
- Migrada API deprecada `Color.value` → `Color.toARGB32()` (4 sites de tema).
- Migrada API deprecada `Share.shareXFiles` → `SharePlus.instance.share(ShareParams(...))` (3 sites).
- Corrigidos `use_build_context_synchronously`: captura de `ScaffoldMessenger`/`Navigator` antes do
  await e uso de `if (mounted)` (State) em vez de `if (context.mounted)`.
- Novo `.github/workflows/ci.yml`: roda codegen (arquivos `*.g.dart` são gitignored) antes de
  `flutter analyze --fatal-infos` e `flutter test`.
