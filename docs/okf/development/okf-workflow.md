---
type: Concept
title: "Workflow OKF para Agentes"
description: "Como agentes de IA (Claude Code, opencode, MiMo Code) navegam o conhecimento do BestFin: protocolo de 6 passos, onde cada ferramenta descobre o protocolo e como manter o tracking de tarefas."
tags: [development, agents, tooling]
related: [environment, conventions]
timestamp: 2026-07-11T00:00:00Z
---

# Workflow OKF para Agentes

## O Que É

O BestFin usa OKF (Open Knowledge Format): o conhecimento do projeto vive em
arquivos de conceito curados em `docs/okf/`, navegados por um protocolo fixo de
6 passos. Este conceito documenta onde cada ferramenta de agente descobre o
protocolo e quais arquivos mantêm o estado do tracking.

## Fontes

* `docs/okf/index.md` — índice de conceitos (Passo 1)
* `docs/tasks/index.md` — índice de tarefas com status/progresso (Passo 3)
* `AGENTS.md` (raiz, Seção 0) — protocolo resumido + regras de código (Passo 4)
* `~/.config/opencode/skills/okf-workflow/SKILL.md` — skill global do opencode (genérica, vale para qualquer projeto com `docs/okf/`)
* `~/.config/opencode/commands/okf.md` — comando global `/okf <tarefa>` do opencode
* `opencode.json` (raiz do repo) — injeta `docs/okf/index.md` em toda sessão do opencode neste projeto
* `~/.config/mimocode/skills/okf-workflow/SKILL.md` — mesma skill, espelhada globalmente para o MiMo Code (fork do opencode)
* `~/.config/mimocode/commands/okf.md` — comando global `/okf <tarefa>` do MiMo Code
* `~/.claude/skills/okf-workflow/` — skill global do Claude Code (fora do repo)
* `docs/okf/log.md` — changelog do bundle OKF

## O Protocolo (resumo)

1. Ler `docs/okf/index.md`.
2. Escolher 1-2 conceitos (máximo 3 por tarefa; dividir se tocar 4+ áreas).
3. Checar `docs/tasks/index.md` (tarefa existente? dependências? anotar o nº).
4. Ler `AGENTS.md` — proibições primeiro.
5. Implementar; validar com `nix develop -c flutter analyze` e `flutter test`.
6. Atualizar tracking: checkboxes + `timestamp` na task; Progresso/Status no
   índice de tarefas; mudanças de conceito registradas no `log.md`.

## Descoberta por ferramenta

| Ferramenta | Mecanismo |
|---|---|
| opencode | `AGENTS.md` (automático) + `instructions` do `opencode.json` do repo + skill global `okf-workflow` + comando global `/okf` |
| MiMo Code | `AGENTS.md` (automático) + skill global `okf-workflow` + comando global `/okf` (mesmo mecanismo do opencode, sem `instructions` versionado por repo) |
| Claude Code | Skill global `okf-workflow` (dispara em projetos com `docs/okf/`) + `AGENTS.md` |
| Outros agentes | `AGENTS.md` Seção 0 (padrão agents.md é lido pela maioria) |

O opencode roda via `nix run nixpkgs#opencode` (sem instalação permanente); o
MiMo Code está instalado em `~/.mimocode/bin/mimo` e roda via
`nix run nixpkgs#steam-run-free -- mimo` (binário genérico, precisa do
`steam-run` para linkar em NixOS). A skill e o comando OKF são **globais**
(`~/.config/opencode/` e `~/.config/mimocode/`) e genéricos, valendo para
qualquer projeto com `docs/okf/`; o que é específico deste repo (instructions
→ `docs/okf/index.md`) fica versionado no `opencode.json` da raiz — o MiMo
Code ainda não tem um equivalente versionado porque seu config de projeto
(`.mimocode/mimocode.jsonc`) vive num diretório local ignorado pelo git.

## Erros comuns de agente

* Abrir `docs/SPEC.md` direto em vez do índice OKF — a spec é referência.
* Codar sem checar `docs/tasks/index.md` e duplicar trabalho já feito.
* Esquecer o Passo 6: task e índice ficam dessincronizados (o índice lista
  Progresso `feitos/total` derivado dos checkboxes — atualize os dois).
* Criar conceito novo e não registrá-lo em `docs/okf/index.md` + `log.md`.
* Rodar comandos fora de `nix develop -c` (ver [[environment]]).

## Referências

* [[environment]] — comandos obrigatórios via Nix
* [[conventions]] — estilo de código
* Docs do opencode: https://opencode.ai/docs/skills/ · /docs/commands/ · /docs/rules/
