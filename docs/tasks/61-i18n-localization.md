---
type: Task
title: "Internacionalização (i18n) real"
description: "Introduzir flutter_localizations + ARB e extrair strings hardcoded pt-BR para destravar outros idiomas."
tags: [feature, i18n, l10n, ux]
timestamp: 2026-07-26T00:00:00Z
status: not_started
progress: 0/4
---

## Descrição

A SPEC diz "i18n-ready", mas na prática as strings estão hardcoded em pt-BR pelo código. Um app
com estrutura de i18n real destrava mercado internacional e testes de UI mais robustos.

## Checklist

- [ ] Configurar `flutter_localizations` + `gen-l10n` (ARB) com pt-BR como base
- [ ] Extrair strings da camada de UI para os arquivos ARB (incremental por feature)
- [ ] Garantir formatação de datas/números por locale (`intl`)
- [ ] Adicionar ao menos um segundo idioma (ex.: en) como prova de conceito
