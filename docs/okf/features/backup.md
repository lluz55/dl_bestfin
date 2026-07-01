---
type: Feature
title: Backup & Export
description: Export de dados em CSV, JSON e PDF; importação de dados externos; backup do banco SQLite.
tags: [backup, export, csv, json, pdf, importação]
timestamp: 2026-06-29T00:00:00Z
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

`presentation/screens/backup_screen.dart` — centraliza todas as opções.

## Widgets

| Arquivo | Propósito |
|---|---|
| `widgets/export_button.dart` | Botão de export com indicador |
| `widgets/import_progress_widget.dart` | Progresso de importação em lote |

## Segurança na Importação

Qualquer arquivo externo (CSV/JSON) deve ser **validado rigorosamente** antes de inserir no banco — nunca concatenar strings de input em queries SQL.

## Dependências

- [Transações](transactions.md) — principal entidade exportada
- [Contas](accounts.md) — incluídas no export JSON completo
- [Categorias](categories.md) — incluídas no export
