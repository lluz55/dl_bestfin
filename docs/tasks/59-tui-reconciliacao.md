---
type: Task
id: "59"
title: "Reconciliação de contas na TUI"
status: done
priority: medium
tags: [cli, tui, accounts, reconciliation]
timestamp: 2026-09-05T20:30:00Z
---

# Tarefa 59 — Reconciliação de contas na TUI

**Fase:** Sync & Terminal
**Prioridade:** 🟡 Média
**Pré-requisitos:** [56-tui-completa](56-tui-completa.md)
**Relacionado:** paridade da TUI com a
[reconciliação de contas da GUI](30-account-reconciliation.md) (🔄 8/8 no app
gráfico, inexistente no terminal).

## Descrição

O usuário consegue conferir o extrato real do banco contra os lançamentos
registrados no BestFin pela GUI: marcar transações como reconciliadas,
comparar saldo do app × saldo do extrato e fechar checkpoints. Na TUI, a
tabela `reconciliation_checkpoints` só aparece indiretamente (o "limpar dados"
das Configurações a esvazia) — não há fluxo de reconciliação.

Como as demais telas, é trabalho de apresentação sobre o mesmo domínio da
GUI: nenhum schema ou regra nova.

## Subtarefas

- [x] Entrada "Reconciliar" na tela de Contas (por conta): listar
      lançamentos do período com estado (aberto/reconciliado), marcar e
      desmarcar com `Espaço`, navegação padrão do `Term`
- [x] Painel de conferência: saldo do app × saldo informado do extrato
      (campo de digitação) com a diferença destacada — mesma matemática da
      GUI (saldo = lançamentos reconciliados até a data)
- [x] Fechar checkpoint (período + saldo final), listar checkpoints
      anteriores e reabrir o último — reusar use cases da task 30
- [x] Sincronização: garantir que o caminho de escrita usado enfileira em
      `sync_queue` (se a reconciliação da GUI já enfileira, herda grátis;
      se não enfileira, registrar aqui a decisão — não é escopo desta tarefa
      mudar o comportamento da GUI)
- [x] Testes: marcar/desmarcar persiste, checkpoint fecha com saldo
      conferido, reabertura restaura estado

## Arquivos (previstos)

- `lib/cli/tui/screens/accounts_screen.dart` — entrada de reconciliação
- `lib/cli/tui/screens/reconciliation_screen.dart` — NOVO (se ficar grande
  o suficiente para merecer tela própria)
- `test/cli/tui_app_test.dart` — fluxo de reconciliação contra banco de teste

## Aceitação

- Reconciliar uma conta pela TUI produz o mesmo efeito que pela GUI
  (mesmos registros, mesmo checkpoint)
- Saldo informado × saldo do app com diferença explícita antes de fechar
- `nix develop -c flutter analyze` e `flutter test` passam

## Resultado (2026-09-05)

Implementada em `lib/cli/tui/screens/reconciliation_screen.dart`, acionada
pelo atalho `r` na tela de Contas. Todos os checkboxes acima concluídos;
`flutter analyze` e `flutter test` passam.

**Decisão de sincronização (registrada conforme pedido):** a reconciliação
da GUI **não** enfileira em `sync_queue` (updates diretos em `entries` +
`reconciliation_checkpoints` via `ReconciliationDao`), e a TUI segue o mesmo
comportamento — reconciliar no terminal produz exatamente os mesmos
registros locais da GUI, sem sync. Mudar isso exigiria alterar a GUI
primeiro e está fora do escopo.
