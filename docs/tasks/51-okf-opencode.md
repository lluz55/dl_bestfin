---
type: Task
id: "51"
title: "OKF para o opencode — protocolo de navegação como skill, comando e regras"
status: completed
priority: medium
tags: [okf, tooling, opencode, agents]
timestamp: 2026-07-11T00:00:00Z
---

# Tarefa 51 — OKF para o opencode

**Fase:** Tooling / Infraestrutura de agentes
**Prioridade:** 🟡 Média
**Estimativa:** Pequena
**Última atualização:** 2026-07-11

## Descrição

Levar o protocolo OKF (Open Knowledge Format) de 6 passos — até então
disponível apenas como skill do Claude Code — para o **opencode**
(opencode.ai, executado via `nix run nixpkgs#opencode`, v1.17+). A skill e o
comando são **globais** (`~/.config/opencode/`), genéricos para qualquer
projeto com `docs/okf/`; apenas o `opencode.json` (instructions do projeto)
fica versionado no repositório.

## Entregas

1. **Skill global** `~/.config/opencode/skills/okf-workflow/SKILL.md` —
   protocolo de 6 passos em versão genérica (qualquer projeto com `docs/okf/`).
   Descoberta automaticamente pela tool `skill` do opencode.
2. **Comando global** `/okf <tarefa>` em `~/.config/opencode/commands/okf.md`
   — injeta o protocolo no prompt em qualquer projeto.
3. **`opencode.json`** na raiz — carrega `docs/okf/index.md` como instrução
   permanente de toda sessão e libera a permissão da tool `skill`.
4. **Seção 0 no `AGENTS.md`** — protocolo OKF obrigatório (o opencode lê
   AGENTS.md automaticamente; funciona como enforcement mesmo se a skill não
   for invocada).
5. **`docs/tasks/index.md`** — índice de tarefas que o Passo 3 do protocolo
   exige e que ainda não existia (gerado a partir do frontmatter e dos
   checkboxes de todas as 47 tasks).
6. **Conceito** `docs/okf/development/okf-workflow.md` registrado no índice
   OKF e no log.

## Subtarefas

- [x] Pesquisar formatos atuais do opencode (skills, commands, rules, config).
- [x] Criar skill global `~/.config/opencode/skills/okf-workflow/SKILL.md` (genérica).
- [x] Criar comando global `~/.config/opencode/commands/okf.md` com `$ARGUMENTS`.
- [x] Criar `opencode.json` com `instructions` e permissão de skill.
- [x] Adicionar Seção 0 (Protocolo OKF) ao `AGENTS.md`.
- [x] Gerar `docs/tasks/index.md` com status/progresso de todas as tarefas.
- [x] Criar conceito `development/okf-workflow.md` e registrar em `docs/okf/index.md`.
- [x] Registrar em `docs/okf/log.md`.
