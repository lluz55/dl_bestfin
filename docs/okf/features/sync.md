---
type: Feature
title: Sincronização (Household)
description: Sync E2E serverless entre dispositivos via relays Nostr (NIP-78), sem backend próprio.
tags: [sync, nostr, e2e, criptografia, household, serverless]
timestamp: 2026-07-04T00:00:00Z
---

## Responsabilidade

Sincroniza dados financeiros entre dispositivos do mesmo usuário (ou household compartilhado) publicando eventos cifrados em relays [Nostr](https://github.com/nostr-protocol/nips) públicos. Não existe backend próprio — os relays são infraestrutura de terceiros redundante por design e nunca veem dados em texto claro, apenas blobs AES-256-GCM opacos.

> Substituiu o backend Go + AES-256-GCM sobre HTTP descrito nas tarefas 23/24
> (ver `docs/tasks/24-flutter-sync-client-e2e.md`). Este documento descreve a
> arquitetura atual.

## Arquitetura E2E

```
Cliente Flutter (identidade)
  mnemônico BIP39 (24 palavras) ──► masterKey (32 bytes, entropia do mnemônico)
  masterKey ──HKDF-SHA256("bestfin-nostr-v1")──► privkey secp256k1 (Nostr keypair)
  masterKey ──PBKDF2-SHA256(600k iters)──► KEK ──► masterKey cifrado em secure storage

Push
  registro (Drift) → JSON → AES-256-GCM(masterKey) → NostrEvent kind:30078
    tags: [d, entityId] [t, entityType] [deleted, "true"]?
  → publicado em paralelo em todos os relays configurados (defaultRelays)

Pull
  query kind:30078 authors:[nossa pubkey] since:cursor, paginada com `until`
  → filtra eventos de outros pubkeys (defesa contra relay que ignora `authors`)
  → AES-256-GCM.decrypt(masterKey) → JSON → upsert no Drift (last-write-wins por updated_at)
```

A identidade **é** a chave: qualquer dispositivo que importe o mesmo mnemônico deriva o mesmo par de chaves Nostr e a mesma masterKey, e portanto lê/escreve os mesmos eventos. Não há conceito de "conta" nem "servidor de autenticação" — pareamento é só compartilhar o mnemônico (tela ou QR code).

## Sem Backend

Não existe servidor próprio. `backend/` (Go + SQLite) foi removido — a sincronização depende apenas de relays Nostr públicos (`wss://`), sem custo de infraestrutura, sem NixOS module, sem Cloudflare Tunnel.

## Cliente Flutter

| Arquivo | Propósito |
|---|---|
| `data/services/e2e_crypto_service.dart` | Deriva masterKey ↔ mnemônico (BIP39), KEK (PBKDF2), privkey Nostr (HKDF), cifra/decifra payloads (AES-256-GCM) |
| `data/services/nostr_sync_service.dart` | Implementa `SyncTransport` sobre `dart_nostr`: push/pull de eventos kind:30078, live subscription, backoff por relay, presença de dispositivo |
| `data/services/sync_transport.dart` | Interface `SyncTransport` — abstrai o transporte (hoje só há a implementação Nostr) |
| `data/services/sync_service.dart` | Orquestra sync: lê `sync_queue`, serializa, chama `SyncTransport.pushRecords`/`pullRecords`, aplica upserts no Drift |
| `data/repositories/household_repository.dart` | Household/membros — armazenamento local (Drift), sem chamada de rede |
| `presentation/screens/login_screen.dart` | Importa identidade existente a partir do mnemônico |
| `presentation/screens/register_screen.dart` | Gera nova identidade (mnemônico novo) |
| `presentation/screens/mnemonic_display_screen.dart` / `mnemonic_recovery_screen.dart` | Exibe o mnemônico gerado / recupera identidade a partir dele — "recovery" no modelo Nostr é reimportar o mnemônico, pois ele **é** a identidade |
| `presentation/screens/identity_qr_screen.dart` / `qr_scanner_screen.dart` | Pareamento de outro dispositivo via QR code do mnemônico |
| `presentation/screens/household_screen.dart` | Gestão do household |
| `presentation/screens/sync_settings_screen.dart` | Status de conexão + gestão de relays (`relay_status_section.dart` / `relay_manager_section.dart`) |
| `presentation/widgets/relay_manager_section.dart` | UI para adicionar/remover relays e restaurar os padrões (usa `relayListProvider`) |
| `presentation/providers/sync_provider.dart` | `SyncStateNotifier` (auto-sync); `relayListProvider`/`RelayListNotifier` (lista de relays configurável) |


## Pareamento por QR

O QR de pareamento **não** contém o mnemônico em texto. Payload versionado e
restrito ao alfabeto alfanumérico do QR (modo alfanumérico → matriz ~versão 5,
legível de tela para câmera):

```
BESTFIN:1:<64 chars hex MAIÚSCULO da masterKey>
```

`E2ECryptoService.masterKeyToQrPayload` gera; `qrPayloadToMnemonic` decodifica e
também aceita o formato legado (24 palavras BIP39, com validação de checksum),
retornando `null` para conteúdo inválido. Ver [[tasks/80-sync-qr-pairing-compat]].

## Modelo de Dados (Nostr)

- **Kind 30078** (NIP-78, "application-specific data", replaceable por `d`-tag).
- Tags: `['d', entityId]` (chave de replace), `['t', entityType]` (ex.: `transaction`, `account`, `device_presence`), `['deleted', 'true']` opcional para tombstones.
- `content`: payload JSON do registro, cifrado com AES-256-GCM usando a masterKey (nunca a chave privada Nostr).
- `defaultRelays` (`nostr_sync_service.dart`): lista padrão de ~10 relays públicos verificados (sem paywall de escrita). Redundância: a sync segue funcionando enquanto ao menos 1 relay responder.
- **Relays configuráveis pelo usuário:** a lista pode ser personalizada (adicionar/remover) na tela de sync. É persistida por dispositivo em `SharedPreferences` (`nostr_custom_relays`), independente da identidade (sobrevive ao sign-out). `NostrSyncService.updateRelays`/`resetRelaysToDefaults` persistem e reconectam; `normalizeRelayUrl` valida/normaliza (prefixa `wss://`, tira barra final). Remover o último relay não é permitido; lista vazia cai para os padrões.

## Resiliência

- **Backoff por relay**: falha/erro/NOTICE de rate-limit coloca o relay em cooldown exponencial (30s→16min, com jitter); relay em cooldown é excluído da lista ativa até expirar.
- **Log local de eventos não confirmados** (`nostrEventLogDao`): todo evento é persistido localmente *antes* de publicar; `replayUnpublished()` reenvia o que não foi confirmado por nenhum relay.
- **Paginação no pull**: relays limitam resultados por query (~500), então o pull pagina com `until` decrescente até uma página vazia.
- **Live subscription**: assinatura Nostr mantida aberta (não fecha no EOSE) para reagir a mudanças remotas em segundos, com o poll periódico como rede de segurança.

## Notificações de Atualização do App (Developer Broadcast)

Além do sync de dados do usuário, o app assina um segundo canal Nostr controlado exclusivamente pelo desenvolvedor para receber notificações de nova versão.

```
Developer keypair (privkey no CI, pubkey embutida em kDeveloperNostrPubkey)
  → evento kind:30078  d-tag:'app_update'
     content: { version, changelog?, download_url?, published_at, is_critical }
     conteúdo em JSON plain-text — SEM cifração (anúncio público)

Cada instância do app:
  startUpdateListener() → assinatura live authors:[kDeveloperNostrPubkey]
  → _isNewerVersion(info.version, kAppVersion)
  → emite em appUpdateEvents → appUpdateProvider
  → banner _UpdateBanner no main.dart (persistente, dismissível, no topo)
```

| Item | Detalhe |
|---|---|
| Pubkey dev | `df0e05800998ec8159e052491107294b2f85d6594ea9d45ebc9765c98a2d8c70` |
| Privkey dev | Secret `BESTFIN_DEV_NOSTR_PRIVKEY` no CI (nunca no repositório) |
| Script de publicação | `scripts/publish_update.dart` |
| Modelo | `domain/models/app_update_info.dart` |
| Provider | `appUpdateProvider` em `sync_provider.dart` |

O canal de atualização é independente da identidade do usuário — funciona mesmo sem sync ativo, desde que haja pelo menos um relay acessível.

## Dependências

- [Segurança](security.md) — masterKey cifrada em `flutter_secure_storage`
- Todas as features de dados — qualquer entidade pode ser sincronizada

# Citations

[1] [Task 24 — Flutter Sync Client E2E (histórico + nota de migração)](../../tasks/24-flutter-sync-client-e2e.md)
[2] [NIP-78 — Application-specific data](https://github.com/nostr-protocol/nips/blob/master/78.md)
