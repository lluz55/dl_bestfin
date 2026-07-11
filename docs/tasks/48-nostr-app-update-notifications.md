---
type: Task
id: 48
title: "Notificações de Atualização via Nostr (Developer Broadcast)"
status: completed
priority: medium
tags: [sync, nostr, update, notification]
timestamp: 2026-07-11T00:00:00Z
---

## Objetivo

Notificar todos os dispositivos com o app instalado quando uma nova versão é publicada, usando a infraestrutura Nostr já existente — sem backend próprio.

## Modelo

- Desenvolvedor mantém um keypair Nostr fixo (privkey no CI como secret, pubkey embutida no app).
- A cada release, o CI publica um evento `kind:30078 d-tag:app_update` com JSON plain-text (sem cifragem — é anúncio público).
- Cada instância do app abre uma assinatura live para o pubkey do desenvolvedor e exibe banner persistente quando detecta versão mais nova.

## Arquivos Modificados/Criados

- `lib/core/constants/app_info.dart` — adicionado `kDeveloperNostrPubkey`
- `lib/features/sync/domain/models/app_update_info.dart` — novo modelo
- `lib/features/sync/data/services/nostr_sync_service.dart` — `appUpdateEvents` stream + `startUpdateListener()` + `_isNewerVersion()`
- `lib/features/sync/presentation/providers/sync_provider.dart` — `appUpdateProvider`
- `lib/main.dart` — banner `_UpdateBanner` persistente (dismissível, aparece no topo)
- `scripts/publish_update.dart` — CLI para o desenvolvedor publicar nos relays

## Developer Keypair

- **Pubkey** (embutida no app): `df0e05800998ec8159e052491107294b2f85d6594ea9d45ebc9765c98a2d8c70`
- **Privkey**: deve ser armazenada como secret `BESTFIN_DEV_NOSTR_PRIVKEY` no CI (GitHub Actions ou similar)

## Como Publicar uma Atualização

```bash
BESTFIN_DEV_NOSTR_PRIVKEY=<privkey> \
  nix develop -c dart run scripts/publish_update.dart \
    --version 1.1.0 \
    --changelog "Melhoria de performance e correções de bugs" \
    --download-url "https://github.com/user/bestfin/releases/tag/v1.1.0"
```

## Checklist

- [x] Keypair do desenvolvedor gerado (pubkey embutida, privkey documentada para CI)
- [x] Modelo `AppUpdateInfo`
- [x] Stream `appUpdateEvents` no `NostrSyncService`
- [x] Provider `appUpdateProvider`
- [x] Banner persistente em `main.dart`
- [x] Script `scripts/publish_update.dart` para o desenvolvedor
- [x] OKF sync.md atualizado
