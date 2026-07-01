# Tarefa 24: Flutter — Sync Client E2E (AES-256-GCM + Backend Próprio)

## Objetivo

Substituir o cliente Supabase por chamadas HTTP ao backend da tarefa 23, adicionando criptografia E2E: o app cifra cada registro com AES-256-GCM antes de enviar e decifra após receber. O servidor nunca vê dados financeiros em texto claro.

## Dependências Novas (pubspec.yaml)

```yaml
dependencies:
  # Criptografia
  pointycastle: ^3.9.1         # AES-256-GCM
  cryptography: ^2.7.0         # Argon2id (ou argon2_flutter se disponível)
  
  # Já existem — verificar versão
  http: ^1.2.0
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0
```

> **Alternativa para Argon2id**: usar `package:argon2` ou implementar via `dart:ffi` + libargon2. Avaliar compatibilidade Android/Linux ao escolher.

## Fluxo de Criptografia E2E

### Derivação de chave (1x por sessão, após login)

```dart
// CryptoService.deriveKey(password: String, kdfSalt: String) → Uint8List(32)
//
// kdfSalt: hex string 32 chars (16 bytes) retornado pelo servidor no login
// Argon2id params: memory=65536 KiB, iterations=3, parallelism=1, keyLen=32
final saltBytes = hexDecode(kdfSalt);  // 16 bytes
final key = await Argon2id().deriveKeyFromPassword(
  password: password,
  nonce: saltBytes,
  memory: 65536,
  numIterations: 3,
  numThreads: 1,
  hashLength: 32,
);
```

Chave armazenada em `flutter_secure_storage` após login, nunca em SharedPreferences ou DB local.

### Encrypt antes do push

```dart
// CryptoService.encrypt(key: Uint8List, plaintext: String) → String (base64)
final nonce = randomBytes(12);
final cipher = AesGcm.with256bits();
final secretBox = await cipher.encrypt(
  utf8.encode(plaintext),
  secretKey: SecretKey(key),
  nonce: nonce,
);
// payload = base64( nonce(12) || ciphertext || mac(16) )
return base64.encode([...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes]);
```

### Decrypt após pull

```dart
// CryptoService.decrypt(key: Uint8List, payload: String) → String
final data = base64.decode(payload);
final nonce = data.sublist(0, 12);
final cipherText = data.sublist(12, data.length - 16);
final mac = data.sublist(data.length - 16);
final cipher = AesGcm.with256bits();
final plainBytes = await cipher.decrypt(
  SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
  secretKey: SecretKey(key),
);
return utf8.decode(plainBytes);
```

## Arquivos a Criar/Modificar

### Novo: `lib/features/sync/data/services/crypto_service.dart`

Responsabilidades:
- `deriveKey(password, kdfSalt)` → `Future<Uint8List>` 
- `encrypt(key, plaintext)` → `Future<String>` (base64)
- `decrypt(key, payload)` → `Future<String>`
- Armazenar/recuperar chave via `flutter_secure_storage`

### Novo: `lib/features/sync/data/services/backend_sync_service.dart`

Substitui `SupabaseService`. Responsabilidades:
- `register(email, password)` → armazena token, kdf_salt, deriva e salva chave
- `login(email, password)` → idem
- `refreshToken()` → renova access token com refresh token
- `push(List<SyncRecord> records)` → cifra payloads, POST /sync/push
- `pull(int since)` → GET /sync/pull, decifra payloads
- URL base configurável (lida de `AppSettings` via key `sync_server_url`)

### Modificar: `lib/features/sync/data/services/sync_service.dart`

- Substituir dependência `SupabaseService` por `BackendSyncService`
- `processSyncQueue()`: para cada item da `sync_queue`, serializar para JSON, chamar `BackendSyncService.push()`
- `pullRemoteChanges()`: chamar `BackendSyncService.pull(since)`, aplicar upserts no Drift (last-write-wins por `updated_at`)
- Lógica de fila offline existente permanece inalterada

### Modificar: `lib/features/sync/presentation/providers/sync_provider.dart`

- Trocar `supabaseServiceProvider` por `backendSyncServiceProvider`
- Manter `SyncState`, `SyncStatus`, e auto-sync de 30s inalterados

### Modificar: `lib/features/settings/` (tela de configurações)

Adicionar campo "URL do servidor de sync" (ex: `http://192.168.1.100:8080`):
- Lê/salva em `AppSettings` com key `sync_server_url`
- Mostrar status de conexão (botão "Testar conexão" que chama `/auth/login` ou similar)
- Campos de login: email e senha do servidor de sync

## Serialização dos Registros Drift → SyncRecord

Para cada entidade sincronizada, converter o objeto Drift para Map<String, dynamic> e serializar como JSON:

```dart
// Exemplo para Transaction
final json = transaction.toJsonMap();  // implementar em cada entidade
final plaintext = jsonEncode(json);
final encryptedPayload = await cryptoService.encrypt(key, plaintext);

final record = SyncRecord(
  entityType: 'transactions',
  entityId: transaction.id,
  payload: encryptedPayload,
  updatedAt: transaction.updatedAt.millisecondsSinceEpoch ~/ 1000,
  isDeleted: false,
);
```

Entidades a sincronizar (prioridade):
1. `transactions` (tabela `transactions`)
2. `accounts` (tabela `accounts`)
3. `categories` (tabela `categories`)
4. `credit_cards` (tabela `credit_cards`)
5. Demais entidades em iterações futuras

## SyncRecord (modelo Dart)

Criar `lib/features/sync/data/models/sync_record.dart`:

```dart
class SyncRecord {
  final String entityType;
  final String entityId;
  final String payload;      // base64 cifrado
  final int updatedAt;       // unix seconds
  final bool isDeleted;

  Map<String, dynamic> toJson() => { ... };
  factory SyncRecord.fromJson(Map<String, dynamic> json) => ...;
}
```

## Acceptance Criteria

- [x] `CryptoService.encrypt` + `decrypt` são inversos (teste unitário)
- [x] `deriveKey` com mesma senha + salt retorna mesma chave (deterministico)
- [x] Login no app salva token em secure storage
- [x] Push de uma transação cifra o payload (verificável: payload no servidor é base64 ilegível)
- [x] Pull decifra e upsert no Drift local (transação aparece no app após pull em outro device)
- [x] Trocar URL do servidor nas configurações redireciona o sync corretamente
- [x] Sync offline: transações criadas sem internet aparecem na fila e são enviadas ao reconectar
- [x] Nenhum dado financeiro em texto claro em logs ou SharedPreferences

## Status Atual

- Implementado para `account`, `transaction` e `category`.
- Transações sincronizam o cabeçalho e as `entries` para preservar a partida dobrada.
- O backend exige payload base64 opaco; payload JSON em texto claro é rejeitado.
- O cadastro envia o `kdf_salt` usado para embrulhar a master key, garantindo que login posterior consiga descriptografá-la.
- O app inicializa a configuração do backend ao abrir e inicia auto-sync periódico.
- Cartões de crédito, metas completas e households remotos ficam para uma próxima expansão de escopo.
