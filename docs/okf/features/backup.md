---
type: Feature
title: Backup & Export
description: Export de dados em CSV, JSON e PDF (com relatório mensal); importação de dados externos; backup do banco SQLite.
tags: [backup, export, csv, json, pdf, importação]
timestamp: 2026-07-09T00:00:00Z
---

## Responsabilidade

Permite ao usuário exportar seus dados financeiros em múltiplos formatos e importar dados de fontes externas.

## Use Cases

| Arquivo | Propósito |
|---|---|
| `domain/usecases/export_csv.dart` | Export de transações em CSV |
| `domain/usecases/export_json.dart` | Export completo em JSON |
| `domain/usecases/export_pdf.dart` | Relatório em PDF |
| `domain/usecases/backup_database.dart` | Cópia do arquivo SQLite |
| `domain/usecases/import_data.dart` | Importação de CSV/JSON |

## Tela

`presentation/screens/backup_screen.dart` — centraliza todas as opções. Inclui presets de período (Este mês, Mês anterior, Últimos 3 meses, Este ano) além do seletor de intervalo livre.

## Relatório PDF

`export_pdf.dart` gera resumo geral, despesas por categoria e tabela de transações. Quando o período cobre 2+ meses, inclui a seção "Evolução Mensal" (gráfico de barras receitas x despesas por mês + tabela com média mensal). Período de exatamente um mês-calendário é rotulado com o nome do mês (relatório mensal).

Inclui também gráficos nativos do package `pdf` (`pw.Chart`): pizza de despesas por categoria (top 5 + "Outros", cores das categorias) e barras mensais. A seção "Insights do Período" é gerada em `_buildInsights` a partir dos agregados calculados no momento da exportação: taxa de poupança, categoria dominante, gasto médio diário, maior despesa individual, mês de pico vs. média, variação do último mês e ticket médio — cada insight só entra quando há dados que o sustentem.

## Widgets

| Arquivo | Propósito |
|---|---|
| `widgets/export_button.dart` | Botão de export com indicador |
| `widgets/import_progress_widget.dart` | Progresso de importação em lote |

## Versionamento & Compatibilidade

Fonte única: `domain/backup_version.dart`.

- **JSON**: o envelope carrega `version` (formato do envelope, `kBackupFormatVersion`) e `schema_version` (o `schemaVersion` do Drift dos dados). Na importação (`import_data.dart`), `_validateBackupCompatibility` roda em `previewJson` **e** em `restoreJson` (antes de apagar o banco) e rejeita: formato mais novo que `kBackupFormatVersion`, formato abaixo de `kMinSupportedBackupFormatVersion`, ou `schema_version` maior que o desta build. `schema_version` ausente (backups antigos) → checagem pulada (melhor esforço).
- **SQLite**: o arquivo já carrega o schema em `PRAGMA user_version` (offset 60 do header, big-endian). `restoreBackup` lê o header (100 bytes) e rejeita `user_version > schemaVersion` — não há migração de downgrade no Drift.
- **CSV**: sem versão (dados tabulares puros de transações).
- Incompatibilidade lança `BackupIncompatibleException` (estende `FormatException`, então a UI já a exibe).

## Integridade do Backup SQLite (WAL)

O banco roda em `journal_mode = WAL`. Antes de copiar `bestfin.sqlite` (share no mobile, "Salvar como" no desktop), `_prepareBackupSource` roda `PRAGMA wal_checkpoint(TRUNCATE)` para mesclar o WAL no arquivo principal — sem isso a cópia sai **desatualizada** (transações recentes ficam no `-wal`). O checkpoint também força o `LazyDatabase` a abrir, criando o arquivo se ele ainda não existir no disco (ex.: logo após um clear-all). Ambos os caminhos passam por `_prepareBackupSource` (`shareBackup` / `saveBackupTo`).

## Segurança na Importação

Qualquer arquivo externo (CSV/JSON) deve ser **validado rigorosamente** antes de inserir no banco — nunca concatenar strings de input em queries SQL.

## Preferências de UI no backup

Preferências que devem sobreviver a backup/restauração ficam na tabela `AppSettings`
do Drift (chave/valor), pois o export JSON inclui `app_settings` e o
`import_data.dart` a restaura. Exemplos:

- `onboarding_completed`, `biometrics_enabled` (via `OnboardingActions`)
- `sidebar_shortcuts` — atalhos fixados na barra lateral (`sidebarShortcutsProvider`,
  em `lib/core/providers/sidebar_shortcuts_provider.dart`), gravados como lista de
  ids separada por vírgula.

Providers que leem dessa tabela devem observar o `databaseProvider` para se
reconstruírem após uma restauração/limpeza (ambas invalidam o banco). Atalhos do
dashboard (`dashboard_shortcuts`) e ordem dos cards ainda usam `SharedPreferences`
e **não** entram no backup.

## Dependências

- [Transações](transactions.md) — principal entidade exportada
- [Contas](accounts.md) — incluídas no export JSON completo
- [Categorias](categories.md) — incluídas no export
