---
type: Architecture Pattern
title: Padrões Riverpod
description: Como providers, Notifiers e FutureProviders são organizados no BestFin.
tags: [riverpod, state, providers, flutter]
timestamp: 2026-06-29T00:00:00Z
---

## Regras de Uso

1. **Use sempre `@riverpod` (Riverpod Generator)** — nunca `StateNotifier` ou `ChangeNotifier` legados.
2. Após criar ou modificar providers com `@riverpod`, execute `build_runner` para gerar o `.g.dart`.
3. Providers ficam em `features/<name>/presentation/providers/`.
4. Sempre verifique `ref.mounted` antes de aplicar resultado de operação assíncrona no Notifier.

## Padrão de Provider Assíncrono (leitura)

```dart
@riverpod
Future<List<Account>> accounts(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.accountsDao.getAllAccounts();
}
```

## Padrão de Notifier (escrita)

```dart
@riverpod
class AccountsNotifier extends _$AccountsNotifier {
  @override
  Future<List<Account>> build() => _fetch();

  Future<void> create(Account account) async {
    await ref.read(accountRepositoryProvider).create(account);
    ref.invalidateSelf();
  }

  Future<List<Account>> _fetch() =>
      ref.read(accountRepositoryProvider).getAll();
}
```

## Invalidação em Cascata

Quando uma transação é criada/editada/excluída, invalidar:
- `transactionsProvider` — lista de transações
- `dashboardProvider` — saldos e totais
- `accountsProvider` — saldo de cada conta afetada
- `gamificationServiceProvider` — streaks e badges

Use `ref.invalidate(xyzProvider)` no Notifier após operação bem-sucedida.

## FutureProvider com Família

```dart
@riverpod
Future<List<Transaction>> transactionsByAccount(
  Ref ref,
  String accountId,
) async { ... }
// Chamado com: ref.watch(transactionsByAccountProvider(accountId))
```

## Providers Globais Compartilhados

| Provider | Localização | Propósito |
|---|---|---|
| `appDatabaseProvider` | `core/database/database_provider.dart` | Instância do banco Drift |
| `themeProvider` | `core/theme/theme_provider.dart` | Tema e modo escuro/claro |
| `valuesHiddenProvider` | `core/providers/privacy_provider.dart` | Modo privacidade |
| `defaultAccountProvider` | `core/providers/default_account_provider.dart` | Conta padrão |
| `isLockedProvider` | `features/security/presentation/providers/security_provider.dart` | Lock screen |
| `llmStateProvider` | `features/llm/presentation/providers/llm_provider.dart` | Estado do LLM |
