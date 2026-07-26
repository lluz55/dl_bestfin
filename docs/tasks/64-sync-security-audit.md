---
type: Task
title: "Auditoria de segurança do sync Nostr"
description: "Revisão focada no envelope de cifragem E2E (AES-256-GCM), derivação a partir do mnemônico BIP39 e keystore, por ser a superfície mais sensível do app."
tags: [security, sync, nostr, crypto, audit]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/4
---

## Descrição

O sync serverless via Nostr é o ponto mais sensível: dados cifrados com AES-256-GCM na chave
mestra derivada de mnemônico BIP39 de 24 palavras, publicados em relays públicos, com uma chave
de desenvolvedor embutida para notificações de update. Vale uma auditoria dedicada.

Arquivos-chave: `lib/features/sync/data/services/sync_service.dart`,
`nostr_sync_service.dart`, `e2e_crypto_service` (ver `e2e_crypto_service_test.dart`),
`sync_envelope` (ver `sync_envelope_test.dart`), `db_encryption.dart`.

## Checklist

- [ ] Revisar geração de nonce/IV e unicidade por mensagem no envelope AES-256-GCM
- [ ] Revisar derivação de chave a partir do mnemônico e armazenamento no secure storage
- [ ] Verificar validação de assinatura/pubkey nas notificações de update (chave dev embutida)
- [ ] Rodar `/security-review` focado no fluxo de sync e registrar achados
