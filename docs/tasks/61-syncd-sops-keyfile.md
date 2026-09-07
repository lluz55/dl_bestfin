---
type: Task
id: "61"
title: "Daemon syncd headless com key-file via SOPS"
status: done
priority: medium
tags: [cli, sync, syncd, sops, nostr]
timestamp: 2026-09-06T00:00:00Z
---

# Tarefa 61 — Daemon syncd headless com key-file via SOPS

**Fase:** Sync & Terminal
**Prioridade:** 🟡 Média
**Pré-requisitos:** [57-tui-modo-residente-sync-continuo](57-tui-modo-residente-sync-continuo.md)
**Relacionado:** `docs/okf/features/sync.md` (arquitetura E2E),
`docs/okf/development/secrets-sops.md` (SOPS no devShell)

## Objetivo

`bestfin syncd` — daemon headless de sincronização para systemd/módulo NixOS,
rodando o mesmo `TuiSyncEngine` da TUI, com a identidade fornecida por
`--key-file` / `BESTFIN_SYNC_KEYFILE` **em texto plano ou cifrado com SOPS**,
sem nunca tocar no secure storage do app.

## Checklist

- [x] Daemon roda o `TuiSyncEngine` (live subscription, push debounce, poll 1min)
- [x] Shutdown gracioso em SIGTERM/SIGINT (exit 0), logging de uma linha p/ journald
- [x] `--key-file <path>` e env `BESTFIN_SYNC_KEYFILE`; exit 2 sem chave, exit 1 inválida
- [x] Suporte a arquivo cifrado com SOPS: fallback `sops -d <path>` quando o
      conteúdo não é um payload válido — a chave age vem de `SOPS_AGE_KEY_FILE`
      / `SOPS_AGE_KEY` / `~/.config/sops/age/keys.txt` (mesmo mecanismo do
      devShell e do sops-nix)
- [x] Extração de identidade de documento estruturado (YAML/JSON) — o SOPS não
      cifra strings soltas, então o key-file cifrado típico é
      `identity: BESTFIN:1:<hex>`; extração por regex de payload e por valor
      de chave (mnemônico de 24 palavras)
- [x] Conteúdo descriptografado só em memória; nada logado
- [x] Testes (`test/cli/syncd_keyfile_test.dart`): extração (payload solto,
      YAML, JSON, inválido) e roundtrip real sops -e/-d
- [x] `flutter analyze` sem novos issues e `flutter test test/cli/` passando
