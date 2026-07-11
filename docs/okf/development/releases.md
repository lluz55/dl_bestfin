---
type: Development Guide
title: Releases e Versão no App
description: Fluxo de release e a regra de expor a versão dentro do app a cada release.
tags: [release, versao, github, binarios, nix]
timestamp: 2026-07-10T00:00:00Z
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

Detalhes completos e comandos em `AGENTS.md` §6. Passos:

1. Bump `pubspec.yaml` (`version` e `build`).
2. Atualizar `kAppVersion` em `app_info.dart` para o mesmo `X.Y.Z`.
3. Commit + tag `vX.Y.Z` + push do commit e da tag.
4. Compilar via `nix develop -c`: `flutter build apk --release` e `flutter build linux --release`.
5. Empacotar o Linux: `tar -czf bestfin-vX.Y.Z-linux-x64.tar.gz -C build/linux/x64/release/bundle .`
6. `gh release create vX.Y.Z ...` anexando o APK e o `.tar.gz`, nomeados com versão+plataforma.

## Erros comuns de agente

* **Esquecer `kAppVersion`:** bumpar só o `pubspec.yaml` deixa a tela Sobre mostrando a versão antiga. Sempre atualize a constante junto.
* **Criar a tag/release sem os binários:** a REGRA DE OURO exige Linux **e** Android anexados na sequência.
* **Rodar `flutter build` fora do Nix:** ver [[environment]] — sempre `nix develop -c`.

## Referências

* `AGENTS.md` §6 — Releases e Publicação de Binários (fluxo completo e nomenclatura dos artefatos).
* [[environment]] — comandos via Nix.
