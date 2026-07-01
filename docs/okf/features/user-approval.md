# Aprovação de Usuários

## Visão Geral

O BestFin utiliza um sistema de aprovação para novos cadastros. Quando um usuário se cadastra, sua conta fica com status `pending` até ser aprovada por um administrador via CLI.

## Fluxo

```
1. Usuário preenche formulário de cadastro (app Flutter)
2. Backend cria conta com status "pending"
3. App exibe: "Conta criada. Aguarde aprovação do administrador."
4. Administrador aprova via CLI: bestfin-cli approve user@email.com
5. Usuário consegue fazer login normalmente
```

## Status Possíveis

| Status | Descrição | Login permitido |
|--------|-----------|-----------------|
| `pending` | Conta criada, aguardando aprovação | Não |
| `approved` | Conta aprovada pelo administrador | Sim |
| `rejected` | Conta rejeitada pelo administrador | Não |

## CLI de Administração

O CLI está localizado em `backend/cmd/cli/main.go` e é compilado como `bestfin-cli`.

### Comandos

```bash
# Listar usuários pendentes
bestfin-cli pending

# Listar todos os usuários
bestfin-cli list

# Aprovar um usuário por email
bestfin-cli approve user@email.com

# Rejeitar um usuário por email
bestfin-cli reject user@email.com
```

### Variável de Ambiente

- `DATA_DIR`: Caminho para o diretório de dados (default: `./data`)

### Exemplo de Uso

```bash
# Compilar o CLI
cd backend
go build -o bestfin-cli ./cmd/cli/

# Listar pendentes
./bestfin-cli pending

# Aprovar
./bestfin-cli approve joao@example.com

# Verificar
./bestfin-cli list
```

## Porta do Backend

O backend escuta na porta **28083** por padrão. Para alterar, defina a variável de ambiente `LISTEN_ADDR`:

```bash
LISTEN_ADDR=0.0.0.0:28083 bestfin-server
```

## Build com URL Personalizada

O app Flutter suporta passar a URL do backend no momento do build via `--dart-define`:

### Android

```bash
# Build com URL padrão (emulador Android)
flutter build apk

# Build com URL personalizada
flutter build apk --dart-define=BESTFIN_BACKEND_URL=http://192.168.1.100:28083

# Ou usando o script de build
./scripts/build.sh android http://192.168.1.100:28083
```

### Linux

```bash
# Build com URL padrão
flutter build linux

# Build com URL personalizada
flutter build linux --dart-define=BESTFIN_BACKEND_URL=http://meuserver.local:28083

# Ou usando o script de build
./scripts/build.sh linux http://meuserver.local:28083
```

### Variável de Ambiente

Também é possível definir via variável de ambiente:

```bash
BESTFIN_BACKEND_URL=http://meuserver.local:28083 ./scripts/build.sh android
```

## Endpoints Relacionados

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/auth/register` | Cadastro (retorna 202 pendente) |
| POST | `/auth/login` | Login (verifica status) |
| POST | `/auth/recover` | Recuperação (verifica status) |

### Respostas

**Register (202)**:
```json
{
  "status": "pending",
  "message": "Conta criada. Aguardando aprovação do administrador."
}
```

**Login com conta pendente (403)**:
```json
{
  "error": "account_pending_approval"
}
```

**Login com conta rejeitada (403)**:
```json
{
  "error": "account_rejected"
}
```

## Segurança

- O status é armazenado na tabela `users` do SQLite no backend
- A coluna `status` tem valor padrão `pending` para novos cadastros
- Apenas contas com status `approved` podem autenticar
- O CLI acessa diretamente o banco de dados (sem API HTTP)
