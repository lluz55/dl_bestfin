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

Desde a introdução do CI/CD, o fluxo é dividido entre local e GitHub Actions. Detalhes completos e comandos em `AGENTS.md` §6. Passos:

1. `./scripts/release.sh X.Y.Z --changelog "..."` (local): bump de `pubspec.yaml` + `kAppVersion` em `app_info.dart`, commit, **tag anotada** `vX.Y.Z` e push.
2. O push da tag dispara `.github/workflows/release.yml`, que faz o resto **no CI**:
   * compila Android (`flutter build apk --release`) e Linux (`flutter build linux --release`) via `nix develop .#ci -c`;
   * empacota o bundle Linux em `bestfin-vX.Y.Z-linux-x64.tar.gz`;
   * `gh release create vX.Y.Z ...` anexando os dois binários, com notas extraídas do `CHANGELOG.md`;
   * publica a notificação de atualização nos relays Nostr (`scripts/publish_update.dart`).

Nenhum secret sensível (keystore Android, chave privada Nostr) precisa existir na máquina do dev — ficam só como secrets do GitHub Actions.

## Erros comuns de agente

* **Esquecer `kAppVersion`:** bumpar só o `pubspec.yaml` deixa a tela Sobre mostrando a versão antiga. Sempre atualize a constante junto — `scripts/release.sh` já cuida disso.
* **Criar a tag sem push, ou tag não-anotada:** o CI depende do push da tag `vX.Y.Z` para disparar, e a mensagem da tag anotada carrega o sinal de release crítico (`--critical`). Use sempre `scripts/release.sh`, não `git tag` manual.
* **Rodar `flutter build` fora do Nix:** ver [[environment]] — sempre `nix develop -c` (local) ou `nix develop .#ci -c` (CI).
* **Esperar que `release.sh` compile/publique:** desde o CI/CD, o script só prepara e dispara a tag. Build, GitHub Release e Nostr são responsabilidade do workflow — acompanhe em `gh run watch`.

## Referências

* `AGENTS.md` §6 — Releases e Publicação de Binários (fluxo completo, workflow do CI e secrets necessários).
* `.github/workflows/release.yml` — o workflow em si.
* [[environment]] — comandos via Nix.
