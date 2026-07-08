---
type: Task
id: "37"
title: Correções UX — Relatórios, Foco de Campos e Entidade
status: completed
timestamp: 2026-07-07T00:00:00Z
---

# Tarefa 37 — Correções UX (Relatórios, Foco de Campos e Entidade)

**Fase:** 3 — UX Polish
**Prioridade:** 🟡 Alta
**Pré-requisitos:** [13-reports](./13-reports.md), [28-quick-transaction-entry](./28-quick-transaction-entry.md), [06-transactions](./06-transactions.md)

---

## Descrição

Quatro correções/melhorias pontuais pedidas pelo usuário:

1. Hub de Relatórios usava `SliverGridDelegateWithMaxCrossAxisExtent` sem piso
   de colunas — em telas estreitas caía para 1 coluna. Mínimo agora é 2.
2. Ao completar um campo de texto (descrição, entidade) no formulário completo
   e no Lançamento Rápido, o teclado (Android) não avançava o foco para o
   próximo campo — `onFieldSubmitted` era no-op ou não existia.
3. Lançamento Rápido sempre salvava com `DateTime.now()`, sem forma de ajustar
   a data (sem hora) do lançamento.
4. `EntityAutocomplete` ("Pago a / Recebido de") não permitia, na prática,
   adicionar uma entidade nova digitando: `onSubmitted` só fechava o teclado
   sem criar/selecionar nada, e o texto digitado era apagado silenciosamente
   ao perder o foco sem entidade selecionada.

---

## Subtarefas

 - [x] `ReportsHubScreen`: `LayoutBuilder` + `SliverGridDelegateWithFixedCrossAxisCount`
   com `crossAxisCount = max(2, floor(largura/350))`
 - [x] `EntityAutocomplete._commitTypedText()`: ao perder foco ou confirmar no
   teclado, resolve o texto digitado — seleciona entidade existente (match
   case-insensitive) ou cria uma nova com categoria padrão ('person'), sem
   depender de o usuário tocar explicitamente no chip/opção "Criar"
 - [x] `_createNewEntity` aceita `categoryId` opcional para pular o seletor de
   categoria no fluxo de auto-criação por submit/blur (o fluxo explícito via
   chip "Criar ..." continua abrindo o seletor normalmente)
 - [x] Removido o clear silencioso do texto digitado ao perder foco sem seleção
 - [x] `TextField` interno usa `TextInputAction.next`/`onSubmitted` para
   encadear foco quando `onFieldSubmitted` é fornecido pelo chamador
 - [x] `TransactionFormScreen`: descrição → entidade (ou notas, se
   transferência) → notas, usando os `FocusNode`s já existentes
 - [x] `QuickTransactionSheet`: descrição → entidade (ou unfocus, se
   transferência); novos `_descriptionFocusNode`/`_entityFocusNode`
 - [x] `QuickTransactionSheet`: `_date` (padrão hoje) + `_pickDate()`
   (`showDatePicker`, sem hora) + chip discreto ao lado do toggle "Pendente"
   (mostra "Hoje" ou `dd/mm[/aaaa]`); `_save()` usa `_date` em vez de
   `DateTime.now()`
 - [x] `flutter analyze` sem novos erros/warnings/infos nos arquivos tocados;
   suite de testes de transações e relatórios passa
