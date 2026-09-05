---
type: Task
id: "60"
title: "Chat/insights do LLM on-device na TUI"
status: done
priority: low
tags: [cli, tui, llm, insights]
timestamp: 2026-09-05T20:30:00Z
---

# Tarefa 60 — Chat/insights do LLM on-device na TUI

**Fase:** Sync & Terminal
**Prioridade:** 🟢 Baixa (opcional — fecha a paridade restante)
**Pré-requisitos:** [56-tui-completa](56-tui-completa.md),
[57-tui-modo-residente-sync-continuo](57-tui-modo-residente-sync-continuo.md)
**Relacionado:** `docs/okf/features/llm.md` — a GUI tem chat com o LLM
on-device; a TUI hoje só usa o LLM como refinador do parser do `add`
(`llm_bridge.dart`).

## Descrição

Traz para a TUI a conversa com o LLM local (llama-server em `:8087`),
seguindo as mesmas regras do protocolo LLM do projeto: **opcional, nunca
bloqueante** — se o servidor não estiver pronto, a tela avisa e não dispara
download nem carregamento de modelo.

## Subtarefas

- [x] Área "Chat" (ou subitem de "Conquistas e insights") com histórico
      simples da sessão, entrada multilinha e streaming token-a-token
      (reuso do endpoint `/v1/chat/completions` já consumido pelo
      `llm_bridge.dart`)
- [x] Comando de insights on-demand ("meus insights deste mês") usando o
      mesmo prompt/estrutura da GUI, alimentado com agregados do banco
      local — fallback determinístico: se LLM indisponível, mostra os
      insights NLG por template (task 27) que a tela de Conquistas já exibe
- [x] Contexto financeiro no prompt: só agregados (totais por categoria do
      período), nunca dados brutos além do necessário — mesma prática da GUI
- [x] Testes: chat com servidor fake (HTTP mockado); fallback sem servidor

## Arquivos (previstos)

- `lib/cli/llm_bridge.dart` — estender para chat streaming
- `lib/cli/tui/screens/chat_screen.dart` — NOVO
- `lib/cli/tui/tui_app.dart` — nova entrada
- `test/cli/` — testes com servidor fake

## Aceitação

- `bestfin tui chat` conversa com o LLM local quando pronto e degrada com
  mensagem clara quando não
- Nenhum dado além dos agregados necessários vai ao prompt
- `nix develop -c flutter analyze` e `flutter test` passam
