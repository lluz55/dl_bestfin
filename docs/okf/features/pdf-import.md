---
type: Feature
title: Importação de Extratos PDF
description: Parsers de extratos bancários em PDF com revisão antes de confirmar as transações.
tags: [pdf, importação, extrato, nubank, bb, parser]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite importar extratos bancários em PDF, extraindo transações automaticamente para revisão e confirmação.

## Parsers Implementados

| Arquivo | Banco | Tipo de Documento |
|---|---|---|
| `data/parsers/nubank_fatura_parser.dart` | Nubank | Fatura de cartão |
| `data/parsers/nubank_comprovante_parser.dart` | Nubank | Comprovante de transferência |
| `data/parsers/bb_comprovante_parser.dart` | Banco do Brasil | Comprovante |

Todos implementam `PdfBankParser` em `data/parsers/pdf_bank_parser.dart`.

## Parser LLM Fallback (Task 25 A3 — Planejado)

Arquivo futuro: `data/parsers/llm_fallback_parser.dart`
- `canHandle()` retorna `true` (último na cadeia).
- Envia os primeiros 2000 chars do texto ao LLM e parseia o JSON retornado.
- Objetivo: suportar qualquer extrato bancário sem parser dedicado.

## Fluxo

1. Usuário seleciona PDF via `FilePicker`.
2. `ImportPdfUseCase` tenta cada parser na ordem; usa o primeiro que `canHandle()`.
3. Transações parseadas aparecem em `PdfReviewScreen` para revisão.
4. Usuário aceita/edita/descarta cada item.
5. Confirmadas → `CreateTransaction` use case.

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/pdf_import_screen.dart` | Seleção do arquivo PDF |
| `screens/pdf_review_screen.dart` | Revisão das transações extraídas |

## Dependências

- [Transações](transactions.md) — transações confirmadas são criadas
- [Categorias](categories.md) — auto-categorização das transações importadas
- [LLM](llm.md) — fallback LLM planejado

# Citations

[1] [Task 25 — A3: Parser PDF com Fallback LLM](../../tasks/25-ai-expansion.md)
