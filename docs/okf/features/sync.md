---
type: Feature
title: Sincronização (Household)
description: Sync E2E entre dispositivos via backend Go próprio com criptografia AES-256-GCM.
tags: [sync, backend, e2e, criptografia, household, go]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Sincroniza dados financeiros entre dispositivos do mesmo usuário (ou household compartilhado) via backend Go próprio. O servidor nunca vê dados em texto claro — tudo é cifrado no cliente.

## Arquitetura E2E

```
Cliente Flutter
  → Argon2id(senha + kdf_salt) → chave AES-256
  → AES-256-GCM(JSON do registro) → base64 payload
  → POST /sync/push com payload opaco

Backend Go
  → Armazena apenas o blob base64 (payload opaco)
  → Nunca acessa conteúdo financeiro

Cliente Flutter (pull)
  → Recebe blobs
  → AES-256-GCM.decrypt → JSON → insere no Drift
```

## Backend (Go)

Localização: `backend/`

| Componente | Arquivo |
|---|---|
| Roteador chi | `cmd/server/main.go` |
| Auth (JWT + refresh) | `internal/auth/handler.go` |
| Sync (push/pull) | `internal/syncsvc/handler.go` |
| Schema SQLite | `users`, `sync_records`, `refresh_tokens` |

Executar: `nix run .#backend`

## Cliente Flutter

| Arquivo | Propósito |
|---|---|
| `data/services/backend_sync_service.dart` | HTTP client para o backend Go |
| `data/services/sync_service.dart` | Orquestra sync: diff, cifra, envia, recebe |
| `data/repositories/household_repository.dart` | Repositório de household |
| `presentation/screens/login_screen.dart` | Login |
| `presentation/screens/register_screen.dart` | Cadastro |
| `presentation/screens/household_screen.dart` | Gestão do household |
| `presentation/screens/sync_settings_screen.dart` | Configurações de sync |

## Fila de Sync

Alterações locais são enfileiradas em `sync_queue` (tabela Drift) e enviadas ao backend na próxima oportunidade de conexão. Implementa sync otimístico.

## Dependências

- [Segurança](security.md) — credenciais em `flutter_secure_storage`
- Todas as features de dados — qualquer entidade pode ser sincronizada

# Citations

[1] [Task 23 — Backend Go](../../tasks/23-backend-sync-server.md)
[2] [Task 24 — Flutter Sync Client E2E](../../tasks/24-flutter-sync-client-e2e.md)
