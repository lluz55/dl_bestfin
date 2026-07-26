---
type: Task
title: "Refatorar 'god files' (sync_service, transaction_repository)"
description: "Quebrar arquivos com responsabilidades demais em sub-serviços/estratégias coesos para facilitar teste e navegação por agentes."
tags: [tech-debt, architecture, refactor, maintainability]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/4
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

- [ ] Mapear responsabilidades de `sync_service.dart` e propor decomposição
- [ ] Extrair sub-serviços de `sync_service.dart` mantendo testes verdes
- [ ] Decompor `transaction_repository.dart` (queries vs. mutações vs. double-entry)
- [ ] `flutter analyze` e `flutter test` verdes após refactor
