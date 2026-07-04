# Tarefa 23: Backend de Sincronização (Go + SQLite)

> **REMOVIDO (2026-07-04):** o backend Go descrito abaixo foi excluído do
> repositório (`backend/`) e substituído por sincronização serverless via
> relays Nostr. Este arquivo é mantido como histórico. Arquitetura atual:
> [`docs/okf/features/sync.md`](../okf/features/sync.md).

## Objetivo

Implementar um servidor HTTP leve em Go para sincronização de dados entre dispositivos do mesmo usuário. O servidor armazena apenas blobs criptografados (o app cifra antes de enviar — E2E real). Deve ser iniciado via `nix run .#backend`.

## Stack

- **Linguagem**: Go 1.22
- **Roteador**: `github.com/go-chi/chi/v5`
- **Banco**: SQLite via `modernc.org/sqlite` (CGO-free)
- **Auth**: JWT (HS256, 1h) + refresh token (30d, armazenado em tabela)
- **Criptografia**: No servidor — nenhuma. Payloads são blobs opacos base64. O app (tarefa 24) aplica AES-256-GCM antes de enviar.
- **Transporte**: HTTP puro (rede local). Usar Caddy/nginx como reverse proxy com TLS se exposto externamente.

## Estrutura de Arquivos

```
backend/
├── cmd/server/main.go
├── internal/
│   ├── auth/
│   │   ├── handler.go        # Register, Login, Refresh
│   │   ├── jwt.go            # SignToken, VerifyToken
│   │   └── password.go       # bcrypt wrap
│   ├── db/
│   │   ├── db.go             # Open + migrate
│   │   ├── models.go         # User, RefreshToken, SyncRecord
│   │   └── queries.go        # CRUD functions
│   ├── middleware/
│   │   ├── auth.go           # RequireAuth, UserIDFromContext
│   │   └── logging.go        # slog request logger
│   └── syncsvc/
│       └── handler.go        # Pull, Push
├── nix/
│   └── module.nix            # NixOS service module
├── go.mod
└── go.sum                    # gerado por: nix develop -c go mod tidy
```

## Schema SQLite

```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,           -- UUID v4
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,   -- bcrypt
    kdf_salt TEXT NOT NULL,        -- 32-char hex (16 bytes random) — enviado ao cliente para Argon2id
    created_at INTEGER NOT NULL
);

CREATE TABLE sync_records (
    id TEXT PRIMARY KEY,           -- UUID v4 gerado pelo servidor
    user_id TEXT NOT NULL REFERENCES users(id),
    entity_type TEXT NOT NULL,     -- "transactions", "accounts", etc.
    entity_id TEXT NOT NULL,       -- UUID original do Drift
    payload TEXT NOT NULL,         -- base64( nonce(12) || AES-256-GCM(json) )
    updated_at INTEGER NOT NULL,   -- unix timestamp enviado pelo cliente
    is_deleted INTEGER NOT NULL DEFAULT 0,
    UNIQUE(user_id, entity_type, entity_id)
);

CREATE INDEX idx_sync_records_user_updated ON sync_records(user_id, updated_at);

CREATE TABLE refresh_tokens (
    token TEXT PRIMARY KEY,        -- UUID v4 opaco
    user_id TEXT NOT NULL REFERENCES users(id),
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);
```

## API REST

### Auth

```
POST /auth/register
  Body:    { "email": "...", "password": "..." }
  Returns: { "user_id": "...", "token": "...", "refresh_token": "...", "kdf_salt": "..." }
  Errors:  409 se email já existe

POST /auth/login
  Body:    { "email": "...", "password": "..." }
  Returns: { "user_id": "...", "token": "...", "refresh_token": "...", "kdf_salt": "..." }
  Errors:  401 se credenciais inválidas

POST /auth/refresh
  Body:    { "refresh_token": "..." }
  Returns: { "token": "..." }
  Errors:  401 se token inválido ou expirado
```

### Sync (requer Authorization: Bearer <token>)

```
GET /sync/pull?since=<unix_timestamp>
  Returns: { "records": [...], "server_time": <unix_ts> }
  Nota: since=0 retorna todos os registros do usuário

POST /sync/push
  Body:    { "records": [<SyncRecord>, ...] }
  Returns: { "synced": <n>, "server_time": <unix_ts> }
```

**SyncRecord** (JSON):
```json
{
  "entity_type": "transactions",
  "entity_id": "uuid-do-drift",
  "payload": "<base64(nonce||ciphertext)>",
  "updated_at": 1748476800,
  "is_deleted": false
}
```

Conflito resolvido por last-write-wins: o upsert só atualiza se `excluded.updated_at > sync_records.updated_at`.

## Variáveis de Ambiente

```
LISTEN_ADDR=127.0.0.1:8080  # bind HTTP (padrão: localhost:8080)
DATA_DIR=./data             # diretório do SQLite (padrão: ./data)
JWT_SECRET=...              # obrigatório, mín. 32 chars
```

## Integração Nix

O `flake.nix` do projeto inclui:
- `packages.backend` — `buildGoModule` do diretório `backend/`
- `apps.backend` — `nix run .#backend`
- `nixosModules.backend` — `import ./backend/nix/module.nix`
- `nixosModules.cloudflareTunnel` — `import ./backend/nix/cloudflare-tunnel.nix`, com token e URL pública lidos de arquivos de segredo (`sops-nix`)
- `go` adicionado ao `devShells.default` para desenvolvimento

## Setup após implementar

```bash
# 1. Gerar go.sum
nix develop -c sh -c "cd backend && go mod tidy"

# 2. Criar vendor/ (necessário para nix build)
nix develop -c sh -c "cd backend && go mod vendor"

# 3. Obter vendorHash correto
nix build .#backend 2>&1 | grep "got:"
# → copiar o hash e atualizar vendorHash no flake.nix

# 4. Build final
nix build .#backend

# 5. Testar
nix run .#backend
# ou durante dev:
JWT_SECRET=dev-secret-32-chars-minimum nix develop -c sh -c "cd backend && go run ./cmd/server"
```

## Acceptance Criteria

- [x] `nix run .#backend` inicia servidor em :8080 (com JWT_SECRET definido)
- [x] `POST /auth/register` retorna token + kdf_salt
- [x] `POST /auth/login` retorna mesmo kdf_salt para o mesmo usuário
- [x] `GET /sync/pull?since=0` retorna `{"records":[], "server_time":...}` para usuário novo
- [x] `POST /sync/push` com 1 record retorna `{"synced":1, ...}`
- [x] `GET /sync/pull?since=0` após push retorna o record enviado
- [x] Payload no SQLite é ilegível (blob base64 opaco)
- [x] `nix build .#backend` produz binário estático funcional
- [x] NixOS module disponível via `nixosModules.backend`
- [x] Cloudflare Tunnel module disponível via `nixosModules.cloudflareTunnel`
- [x] Token e URL pública do Cloudflare Tunnel vêm de arquivos de segredo compatíveis com `sops-nix`
