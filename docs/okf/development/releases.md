---
type: Development Guide
title: Releases e Versão no App
description: Fluxo de release e a regra de expor a versão dentro do app a cada release.
tags: [release, versao, github, binarios, nix, ci-cd]
timestamp: 2026-07-11T00:00:00Z
---

## Regra de Ouro

**Todo release DEVE (1) expor a versão dentro do app e (2) anexar os binários de Linux e Android ao GitHub Release.** Um release sem a versão atualizada visível no app, ou sem os binários, é incompleto.

## Versão dentro do app

A versão exibida no app vem de uma única constante:

* `lib/core/constants/app_info.dart` → `kAppVersion`
* Consumida em **Configurações › Sobre › Versão** (`lib/features/settings/presentation/screens/settings_screen.dart`).

A cada release, `kAppVersion` deve ser atualizada para o mesmo `X.Y.Z` do `pubspec.yaml`. São **três lugares** que andam juntos e não podem divergir:

1. `pubspec.yaml` → `version: X.Y.Z+build`
2. `lib/core/constants/app_info.dart` → `kAppVersion = 'X.Y.Z'`
3. tag Git `vX.Y.Z`

## Fluxo de Release (resumo)

O fluxo é **100% local**, um único comando. Detalhes completos em `AGENTS.md` §6. `./scripts/release.sh X.Y.Z --changelog "..."`:

1. Bump de `pubspec.yaml` + `kAppVersion` em `app_info.dart`, commit, **tag anotada** `vX.Y.Z` e push.
2. Compila Android (`flutter build apk --release`) e Linux (`flutter build linux --release`) via `nix develop -c` — usando o keystore e a chave Nostr decifrados localmente via SOPS (ver [[secrets-sops]]).
3. Empacota o bundle Linux em `bestfin-vX.Y.Z-linux-x64.tar.gz`.
4. `gh release create vX.Y.Z ...` anexando os dois binários, com notas extraídas do `CHANGELOG.md`.
5. Publica a notificação de atualização nos relays Nostr (`scripts/publish_update.dart`).

`.github/workflows/release.yml` existe só como fallback manual (`workflow_dispatch`) para quando a máquina local não tem os secrets do SOPS disponíveis — não roda mais sozinho no push da tag.

## Erros comuns de agente

* **Esquecer `kAppVersion`:** bumpar só o `pubspec.yaml` deixa a tela Sobre mostrando a versão antiga. Sempre atualize a constante junto — `scripts/release.sh` já cuida disso.
* **Criar a tag sem push, ou tag não-anotada:** a mensagem da tag anotada carrega o sinal de release crítico (`--critical`), lido pelo próprio `release.sh`. Use sempre `scripts/release.sh`, não `git tag` manual.
* **Rodar `flutter build` fora do Nix:** ver [[environment]] — sempre `nix develop -c`.
* **Achar que precisa do GitHub Actions:** o fallback (`scripts/release-ci.sh` / `release.yml`) só é necessário sem acesso aos secrets locais do SOPS. O fluxo padrão (`scripts/release.sh`) compila e publica tudo sozinho.

## Referências

* `AGENTS.md` §6 — Releases e Publicação de Binários (fluxo local completo, fallback CI e secrets necessários).
* `docs/okf/development/secrets-sops.md` — como os secrets (keystore, chave Nostr) são decifrados localmente.
* `.github/workflows/release.yml` — o workflow de fallback manual.
* [[environment]] — comandos via Nix.
