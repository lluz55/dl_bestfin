---
type: Architecture Pattern
title: Padrões Drift (SQLite)
description: Como tabelas, DAOs e migrations são estruturados no BestFin.
tags: [drift, sqlite, database, orm]
timestamp: 2026-06-29T00:00:00Z
---

## Estrutura

```
lib/core/database/
├── app_database.dart       # Classe AppDatabase — registra todas as tabelas e DAOs
├── app_database.g.dart     # GERADO — nunca editar manualmente
├── tables/                 # Definições de tabelas (uma por arquivo)
│   ├── transactions.dart
│   ├── entries.dart
│   ├── accounts.dart
│   └── ...
└── daos/                   # DAOs globais (um por domínio)
    ├── transactions_dao.dart
    ├── accounts_dao.dart
    └── ...
```

DAOs específicos de feature ficam em `features/<name>/data/`.

## Regras

- **NUNCA edite `*.g.dart`** — são gerados pelo build_runner.
- Use a API tipada do Drift; **jamais SQL com concatenação manual** de input do usuário (risco de SQL injection).
- Toda mudança de schema (nova coluna, nova tabela) requer um `MigrationStep` em `app_database.dart`.
- Valores monetários são sempre `INTEGER` em **centavos** — nunca `REAL`/`DOUBLE`.

## Exemplo de Tabela

```dart
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withLength(max: 36)();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text()();
  IntColumn get amountInCents => integer()();
  TextColumn get type => text()();           // expense | income | transfer
  TextColumn get categoryId => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
}
```

## Exemplo de DAO

```dart
@DriftAccessor(tables: [Transactions, Entries])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Stream<List<Transaction>> watchAll() => select(transactions).watch();

  Future<int> insertTransaction(TransactionsCompanion tx) =>
      into(transactions).insert(tx);
}
```

## Migrations

```dart
// Em app_database.dart
@override
MigrationStrategy get migration => MigrationStrategy(
  from: (m, details) async {
    if (details.hadDatabase) {
      await m.addColumn(transactions, transactions.sentiment);
    }
  },
);
```

## Valores Monetários

Sempre `amountInCents: INTEGER`. Para exibir: `CurrencyFormatter.format(amountInCents)` em `lib/core/utils/currency_formatter.dart`.
