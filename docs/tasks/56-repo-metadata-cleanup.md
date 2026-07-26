---
type: Task
title: "Metadados do pubspec e limpeza de artefatos locais"
description: "Corrigir a description default do pubspec.yaml e limpar artefatos de build/logs locais que sobram na raiz do repositório (já ignorados pelo git)."
tags: [tech-debt, metadata, cleanup, repo-hygiene]
timestamp: 2026-07-26T12:00:00Z
status: in_progress
progress: 2/3
---

## Descrição

`pubspec.yaml` ainda tem os metadados default do template Flutter
(`description: "A new Flutter project."`), o que destoa de um app já distribuído em releases.

Além disso, a raiz do repositório acumula artefatos locais (`bestfin-*.tar.gz`, `flutter_01.log`,
`dist/`) — **estes já estão no `.gitignore` e NÃO estão versionados**, apenas ocupam espaço no
working tree. A limpeza local é opcional e fica a critério do usuário (podem ser binários de
release ainda úteis).

## Checklist

- [x] Atualizar `description` no `pubspec.yaml` com um resumo real do BestFin
- [x] Confirmar via `git ls-files` que nenhum artefato de release/log está versionado (confirmado: nada versionado)
- [ ] (Opcional, requer confirmação do usuário) Remover artefatos locais órfãos da raiz
      (`bestfin-*.tar.gz`, `flutter_01.log`, `dist/`) — **deferido**, aguardando decisão do usuário

## Notas de implementação

- `dart fix` adicionou `characters: any` (dependência transitiva antes implícita) ao `pubspec.yaml`;
  reposicionada com comentário explicativo.
- Artefatos locais na raiz já cobertos pelo `.gitignore` (`bestfin-*.tar.gz`, `*.log`, `/dist/`);
  são apenas cópias locais, não representam risco no repositório.
