---
type: Feature
title: Recorrências
description: Regras de transações recorrentes com geração automática e hub de assinaturas.
tags: [recorrência, assinaturas, automação, agendado]
timestamp: 2026-06-29T00:00:00Z
---

## Responsabilidade

Permite criar regras de recorrência (mensal, semanal, etc.) que geram transações automaticamente quando o app é aberto.

## Geração Automática

Em `main.dart` (`initState`), o provider `generateRecurringProvider` é lido. Ele verifica todas as regras ativas e cria as transações pendentes desde a última execução.

## Modelos

- `RecurringRule` — `lib/features/recurring/domain/models/recurring_rule.dart`

## Telas

| Arquivo | Propósito |
|---|---|
| `screens/recurring_list_screen.dart` | Lista de regras |
| `screens/recurring_form_screen.dart` | Criação/edição de regra |
| `screens/subscriptions_hub_screen.dart` | Hub de assinaturas com total mensal |

## Frequências Suportadas

`daily`, `weekly`, `biweekly`, `monthly`, `bimonthly`, `quarterly`, `semiannual`, `annual`

## Confirmação Automática (`autoConfirm`)

Cada regra tem um toggle `autoConfirm` (`recurring_wizard_sheet.dart`). Quando
desligado, as ocorrências geradas nascem com `isConfirmed: false` e
`isCompleted: false` (exceto transferências, sempre `false` nesses campos) —
ver `recurring_rules_dao.dart`. Essas transações só aparecem na fila de
"Sugestões" (ver [Transações](transactions.md) — seção Fila de Confirmação) até
o usuário confirmar ou descartar.

## Dependências

- [Transações](transactions.md) — gera `Transaction` para cada ocorrência; fila de confirmação quando `autoConfirm: false`
- [Contas](accounts.md) — conta de débito da regra
- [Categorias](categories.md) — categoria da transação gerada
