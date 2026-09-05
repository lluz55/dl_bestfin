---
type: Task
id: "58"
title: "Paridade de lançamentos na TUI — sugestões, bulk e split"
status: done
priority: medium
tags: [cli, tui, transactions, quick-entry, bulk, split]
timestamp: 2026-09-05T20:30:00Z
---

# Tarefa 58 — Paridade de lançamentos na TUI: sugestões, bulk e split

**Fase:** Sync & Terminal
**Prioridade:** 🟡 Média
**Pré-requisitos:** [56-tui-completa](56-tui-completa.md)
**Relacionado:** traz para a TUI três capacidades de lançamento que existem
só na GUI: o recomendador estatístico do Lançamento Rápido
([28-quick-transaction-entry](28-quick-transaction-entry.md)), a inserção em
lote ([38-bulk-transaction-entry](38-bulk-transaction-entry.md)) e o split de
transações ([31-split-transactions](31-split-transactions.md)).

## Descrição

A tarefa 56 deu à TUI o CRUD completo de transações, mas três fluxos de
lançamento da GUI não têm equivalente no terminal:

1. **Sugestões estatísticas**: no app, o Lançamento Rápido sugere
   categoria/conta/valor conforme o usuário digita a descrição (histórico de
   descrições parecidas). Na TUI, o wizard do `bestfin add` começa sempre em
   branco — o parser NL cobre a frase, mas o formulário manual não sugere
   nada.
2. **Bulk**: a GUI permite lançar dezenas de transações de uma vez (colar
   linhas). Na TUI, só existe inserção um-a-um — o caminho `createTransactionsBulk`
   já é usado internamente pela tela de importação de PDF, mas não é exposto
   como entrada manual.
3. **Split**: a GUI divide uma transação em múltiplas categorias
   (`transaction_splits`). A TUI cria/edita transações sem suporte a splits.

Como tudo na TUI reusa os repositórios, o trabalho é de **apresentação**
(chegar ao use case existente), sem lógica de domínio nova.

## Subtarefas

### Sugestões no wizard e no `add`

- [x] Reaproveitar o recomendador da task 28 (mesma classe/função usada pelo
      Lançamento Rápido da GUI, sem duplicar heurística) para, dado um texto
      parcial de descrição, devolver categoria/conta/valor mais prováveis
- [x] No wizard do `tui_runner.runWizard` e no wizard da tela de Transações:
      campo de descrição com autocomplete (filtrar histórico) e sugestão
      pré-preenchida aceitável com `↵` (sobrescrever digitando)
- [x] No `bestfin add "<frase>"`: quando o parser heurístico deixar
      categoria/conta em baixa confiança, consultar o recomendador antes de
      abrir a confirmação — reduzir idas ao wizard

### Entrada em bulk

- [x] Ação "Lançar em lote" na tela de Transações: colar múltiplas linhas
      (`descrição; valor [; data]` — mesmo formato aceito pela GUI na task 38,
      reusar o parser de linhas existente), revisar em tabela editável
      (`Term.table`) antes de salvar
- [x] Persistir via `createTransactionsBulk` (mesmo caminho da importação de
      PDF) — atomicidade e enfileiramento em `sync_queue` grátis
- [x] Resumo ao final: N criadas, M ignoradas com motivo (valor inválido,
      conta desconhecida…), linha a linha auditável

### Split de transações

- [x] Na criação/edição da tela de Transações: opção "dividir em categorias" —
      N linhas (categoria + valor), validação de soma == total antes de salvar
      (mesma regra da GUI da task 31)
- [x] Na listagem, marcar transações com split (flag `₊` ou similar) e permitir
      ver/editar as partes
- [x] Reusar os use cases/repository methods de split da GUI — sem SQL novo

### Testes

- [x] Recomendador → wizard: dado histórico no banco de teste, sugestão
      aparece e `↵` aceita
- [x] Bulk: linhas válidas + inválidas → somente válidas persistem, contagem
      e `sync_queue` conferidos
- [x] Split: soma divergente bloqueia; edição de partes atualiza as linhas de
      `transaction_splits`

## Arquivos (previstos)

- `lib/cli/tui/tui_runner.dart` — sugestões no wizard
- `lib/cli/tui/screens/transactions_screen.dart` — bulk, split, marcação
- `lib/cli/nl_parser.dart` / `cli_main.dart` — recomendador como segunda
      passada do `add`
- `test/cli/tui_app_test.dart` (ou novo `tui_lancamentos_test.dart`) — cobrir
      os três fluxos

## Aceitação

- Wizard sugere categoria/conta/valor a partir do histórico, aceitos com um
  `↵`, com o mesmo comportamento do Lançamento Rápido da GUI
- Colar 20 linhas revisa antes de salvar e cria tudo num caminho atômico,
  com filas de sync enfileiradas
- Transação com split criada/editada na TUI é indistinguível de uma criada na
  GUI (mesmas tabelas, mesma validação de soma)
- `nix develop -c flutter analyze` e `flutter test` passam
