---
type: Development Guide
title: Geração de Código (build_runner)
description: Quando e como rodar o build_runner para Drift e Riverpod; quais arquivos são gerados.
tags: [build_runner, drift, riverpod, geração, código]
timestamp: 2026-06-29T00:00:00Z
---

## Quando Rodar

Execute `build_runner` sempre que:
- Criar ou modificar uma **tabela Drift** (`lib/core/database/tables/*.dart`)
- Criar ou modificar um **DAO** com `@DriftAccessor`
- Criar ou modificar um **provider** com `@riverpod`
- Modificar a classe `AppDatabase`

```bash
nix develop -c dart run build_runner build --delete-conflicting-outputs
```

## Arquivos Gerados

| Arquivo | Gerado por | Nunca editar |
|---|---|---|
| `app_database.g.dart` | Drift | Sim |
| `*_dao.g.dart` | Drift | Sim |
| `*_provider.g.dart` | Riverpod Generator | Sim |

## Anatomia de um Provider Gerado

Ao anotar um Notifier com `@riverpod`:
```dart
// ANTES (escrito manualmente)
@riverpod
class AccountsNotifier extends _$AccountsNotifier { ... }

// DEPOIS do build_runner gera:
// accounts_notifier.g.dart → contém _$AccountsNotifier e accountsNotifierProvider
```

## Anatomia de um DAO Gerado

```dart
// ANTES
@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin { ... }

// O build_runner gera _$AccountsDaoMixin com métodos tipados de select/insert/update/delete
```

## Problemas Comuns

| Problema | Solução |
|---|---|
| `_$XyzMixin not found` | Rodar build_runner |
| `part 'x.g.dart' not found` | Verificar se `part` está declarado no arquivo fonte |
| Conflito de geração | Usar `--delete-conflicting-outputs` |

# Citations

[1] [Padrões Drift](../architecture/drift-patterns.md)
[2] [Padrões Riverpod](../architecture/riverpod-patterns.md)
[3] [Ambiente Nix](environment.md)
